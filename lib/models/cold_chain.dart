import 'routing_decision.dart';
import 'stage.dart';
import 'temperature_reading.dart';
import 'value_tier.dart';

/// One stage's worth of a single package's journey.
class StageSegment {
  StageSegment({
    required this.stage,
    required this.startHours,
    required this.endHours,
    required this.cooltag,
    required this.actual,
    required this.lifeConsumedDays,
    required this.plannedLifeConsumedDays,
    required this.abuseDays,
  });

  final Stage stage;
  final double startHours;
  final double endHours;

  /// Excess spoilage (abuse-days) accrued on this leg beyond the 4–8 °C band.
  final double abuseDays;

  /// Planned/ideal readings for this leg.
  final List<TemperatureReading> cooltag;

  /// Actual sensor readings for this leg's fridge/reefer.
  final List<TemperatureReading> actual;

  /// Shelf-life (days) consumed across this leg per the *actual* trace.
  final double lifeConsumedDays;

  /// Shelf-life (days) consumed if the leg had followed the cooltag plan.
  final double plannedLifeConsumedDays;

  /// Excess life burned vs plan — the cost of this leg's deviation.
  double get excessLifeDays => lifeConsumedDays - plannedLifeConsumedDays;

  double get peakActualTemp =>
      actual.fold<double>(double.negativeInfinity, (m, r) => r.tempC > m ? r.tempC : m);

  bool get hadBreach => actual.any((r) => r.isBreach);
}

/// A single beef package's full farm-to-fork journey, plus everything the
/// model and decision tree computed about it.
class ColdChain {
  ColdChain({
    required this.id,
    required this.sku,
    required this.destination,
    required this.baseShelfLifeDays,
    required this.baseValueUsd,
    required this.segments,
    required this.decisions,
    required this.predictedBestBeforeDays,
    required this.minLifeOnShelfDays,
    required this.finalTier,
  });

  final int id;
  final String sku;
  final String destination;

  /// This bag's full retail value at top quality ($5–$10), set per package.
  final double baseValueUsd;

  /// Dollars actually recovered (or lost) given the realised tier.
  double get valueUsd => finalTier.multiplier * baseValueUsd;

  /// Pristine shelf life of the SKU at slaughter (days), before any abuse.
  final double baseShelfLifeDays;

  final List<StageSegment> segments;
  final List<RoutingDecision> decisions;

  /// Best-before set up front from the trained model.
  final double predictedBestBeforeDays;

  /// Projected minimum sellable life remaining once it reaches the retail shelf.
  final double minLifeOnShelfDays;

  final ValueTier finalTier;

  double get totalAbuseDays =>
      segments.fold(0, (s, seg) => s + seg.abuseDays);

  double get totalLifeConsumedDays =>
      segments.fold(0, (s, seg) => s + seg.lifeConsumedDays);

  double get totalExcessLifeDays =>
      segments.fold(0, (s, seg) => s + seg.excessLifeDays);

  double get remainingLifeDays => baseShelfLifeDays - totalLifeConsumedDays;

  double get totalHours =>
      segments.isEmpty ? 0 : segments.last.endHours;

  double get peakTemp =>
      segments.fold<double>(double.negativeInfinity, (m, s) {
        final p = s.peakActualTemp;
        return p > m ? p : m;
      });

  bool get hadAnyBreach => segments.any((s) => s.hadBreach);

  List<TemperatureReading> get allActual =>
      [for (final s in segments) ...s.actual];

  List<TemperatureReading> get allCooltag =>
      [for (final s in segments) ...s.cooltag];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sku': sku,
        'destination': destination,
        'baseShelfLifeDays': baseShelfLifeDays,
        'baseValueUsd': double.parse(baseValueUsd.toStringAsFixed(2)),
        'valueUsd': double.parse(valueUsd.toStringAsFixed(2)),
        'predictedBestBeforeDays':
            double.parse(predictedBestBeforeDays.toStringAsFixed(2)),
        'minLifeOnShelfDays':
            double.parse(minLifeOnShelfDays.toStringAsFixed(2)),
        'totalAbuseDays': double.parse(totalAbuseDays.toStringAsFixed(2)),
        'totalLifeConsumedDays':
            double.parse(totalLifeConsumedDays.toStringAsFixed(2)),
        'remainingLifeDays':
            double.parse(remainingLifeDays.toStringAsFixed(2)),
        'peakTempC': double.parse(peakTemp.toStringAsFixed(2)),
        'finalTier': finalTier.name,
        'decisions': [for (final d in decisions) d.toJson()],
        'cooltag': [for (final r in allCooltag) r.toJson()],
        'actual': [for (final r in allActual) r.toJson()],
      };
}
