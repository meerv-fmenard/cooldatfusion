import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import '../models/cold_chain.dart';
import '../models/temperature_reading.dart';

/// Serializes the generated datasets (ideal cooltag + actual sensor traces and
/// the computed routing/value outcomes) and saves them via a macOS save dialog.
class Exporter {
  /// Full nested JSON: every chain with its cooltag, actual, and decisions.
  static Future<String?> exportJson(List<ColdChain> chains) async {
    final payload = <String, dynamic>{
      'schema': 'cooldatfusion.coldchain.v1',
      'chainCount': chains.length,
      'chains': [for (final c in chains) c.toJson()],
    };
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    return _save(text, 'cold_chain_dataset.json', 'json');
  }

  /// Long-format CSV: one row per temperature reading (both sources), tagged
  /// with the chain's final routing outcome — easy to pivot downstream.
  static Future<String?> exportReadingsCsv(List<ColdChain> chains) async {
    final b = StringBuffer();
    b.writeln('chain_id,sku,destination,source,stage,hours_elapsed,temp_c,'
        'is_breach,final_tier,bag_value_usd,final_value_usd');
    for (final c in chains) {
      void row(TemperatureReading r) {
        b.writeln('${c.id},${c.sku},${c.destination},${r.source.name},'
            '${r.stage.name},${r.hoursElapsed.toStringAsFixed(3)},'
            '${r.tempC.toStringAsFixed(3)},${r.isBreach},'
            '${c.finalTier.name},${c.baseValueUsd.toStringAsFixed(2)},'
            '${c.valueUsd.toStringAsFixed(2)}');
      }

      for (final r in c.allCooltag) {
        row(r);
      }
      for (final r in c.allActual) {
        row(r);
      }
    }
    return _save(b.toString(), 'cold_chain_readings.csv', 'csv');
  }

  /// Wide CSV: one row per chain with its outcome and key metrics.
  static Future<String?> exportSummaryCsv(List<ColdChain> chains) async {
    final b = StringBuffer();
    b.writeln('chain_id,sku,destination,base_life_days,best_before_days,'
        'min_life_on_shelf_days,abuse_days,life_consumed_days,'
        'peak_temp_c,had_breach,final_tier,bag_value_usd,final_value_usd');
    for (final c in chains) {
      b.writeln('${c.id},${c.sku},${c.destination},'
          '${c.baseShelfLifeDays.toStringAsFixed(1)},'
          '${c.predictedBestBeforeDays.toStringAsFixed(2)},'
          '${c.minLifeOnShelfDays.toStringAsFixed(2)},'
          '${c.totalAbuseDays.toStringAsFixed(2)},'
          '${c.totalLifeConsumedDays.toStringAsFixed(2)},'
          '${c.peakTemp.toStringAsFixed(2)},${c.hadAnyBreach},'
          '${c.finalTier.name},${c.baseValueUsd.toStringAsFixed(2)},'
          '${c.valueUsd.toStringAsFixed(2)}');
    }
    return _save(b.toString(), 'cold_chain_summary.csv', 'csv');
  }

  static Future<String?> _save(
      String contents, String suggestedName, String ext) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: ext.toUpperCase(), extensions: <String>[ext]),
      ],
    );
    if (location == null) return null; // user cancelled
    final data = utf8.encode(contents);
    final file = XFile.fromData(
      data,
      mimeType: ext == 'json' ? 'application/json' : 'text/csv',
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return location.path;
  }
}
