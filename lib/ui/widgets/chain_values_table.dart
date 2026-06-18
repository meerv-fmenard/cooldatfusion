import 'package:flutter/material.dart';

import '../../models/cold_chain.dart';
import '../../models/stage.dart';
import '../../models/temperature_reading.dart';
import '../../models/value_tier.dart';
import '../../sim/q10.dart';
import '../../sim/value_trajectory.dart';

/// The numerical counterpart to the graphs: every sampled reading of the
/// selected product laid out as a table — cooltag plan vs actual sensor, the
/// cumulative abuse, and the value tier at each point in time.
class ChainValuesTable extends StatelessWidget {
  const ChainValuesTable({super.key, required this.chain, this.q10 = 2.5});

  final ColdChain chain;
  final double q10;

  // Column widths.
  static const double _wTime = 70;
  static const double _wTemp = 78;
  static const double _wBand = 70;
  static const double _wAbuse = 92;
  static const double _wTier = 56;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summary(),
        const SizedBox(height: 8),
        _headerRow(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: _bodyRows()),
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    final t = chain.finalTier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.color.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Package #${chain.id}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${chain.sku} · ${chain.destination}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          _kv('Bag value', '\$${chain.baseValueUsd.toStringAsFixed(2)}'),
          _kv('Final',
              '${t.symbol}  (\$${chain.valueUsd.toStringAsFixed(2)})', t.color),
          _kv('Abuse', '${chain.totalAbuseDays.toStringAsFixed(2)} d'),
          _kv('Peak', '${chain.peakTemp.toStringAsFixed(1)} °C'),
          _kv('Farm-to-fork', '${(chain.totalHours / 24).toStringAsFixed(1)} d'),
          _kv('Best-before',
              '${chain.predictedBestBeforeDays.toStringAsFixed(1)} d'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, [Color? color]) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12),
          children: [
            TextSpan(
                text: '$k ',
                style: const TextStyle(color: Colors.white38)),
            TextSpan(
                text: v,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _headerRow() {
    TextStyle s = const TextStyle(
        color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(width: _wTime, child: Text('Time (d)', style: s)),
          SizedBox(width: _wTemp, child: Text('Cooltag °C', style: s)),
          SizedBox(width: _wTemp, child: Text('Actual °C', style: s)),
          SizedBox(width: _wBand, child: Text('vs band', style: s)),
          SizedBox(width: _wAbuse, child: Text('Cum abuse', style: s)),
          SizedBox(width: _wTier, child: Text('Value', style: s)),
        ],
      ),
    );
  }

  List<Widget> _bodyRows() {
    final q = Q10Model(q10: q10);
    final rows = <Widget>[];
    var cum = 0.0;
    TemperatureReading? prev;

    for (final seg in chain.segments) {
      rows.add(_stageHeader(seg));
      for (var i = 0; i < seg.actual.length; i++) {
        final a = seg.actual[i];
        if (prev != null) {
          final dt = a.hoursElapsed - prev.hoursElapsed;
          if (dt > 0) {
            cum += 0.5 *
                (q.penaltyRateAt(prev.tempC) + q.penaltyRateAt(a.tempC)) *
                (dt / 24.0);
          }
        }
        prev = a;
        final ct = i < seg.cooltag.length ? seg.cooltag[i].tempC : null;
        rows.add(_dataRow(a.hoursElapsed, ct, a.tempC, cum));
      }
    }
    return rows;
  }

  Widget _stageHeader(StageSegment seg) {
    final color = stageColor(seg.stage);
    final def = stageDefOf(seg.stage);
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Text(def.label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 12)),
          const Spacer(),
          if (seg.stage != Stage.fork) ...[
            Text('peak ${seg.peakActualTemp.toStringAsFixed(1)}°C',
                style: TextStyle(
                    fontSize: 11,
                    color: seg.hadBreach
                        ? const Color(0xFFE74C3C)
                        : Colors.white54)),
            const SizedBox(width: 12),
            Text(
                seg.abuseDays > 0.05
                    ? '+${seg.abuseDays.toStringAsFixed(2)} abuse-d'
                    : 'clean',
                style: TextStyle(
                    fontSize: 11,
                    color: seg.abuseDays > 0.05
                        ? const Color(0xFFFFA726)
                        : Colors.white38)),
          ],
        ],
      ),
    );
  }

  Widget _dataRow(double hours, double? cooltag, double actual, double cum) {
    final outOfBand = actual > 8 || actual < 4;
    final over = actual > 8
        ? '+${(actual - 8).toStringAsFixed(1)}'
        : actual < 4
            ? (actual - 4).toStringAsFixed(1)
            : 'ok';
    final tier = tierForAbuse(cum);
    const num = TextStyle(fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: _wTime,
              child: Text((hours / 24).toStringAsFixed(2),
                  style: num.copyWith(color: Colors.white60))),
          SizedBox(
              width: _wTemp,
              child: Text(cooltag == null ? '—' : cooltag.toStringAsFixed(1),
                  style: num.copyWith(color: const Color(0xFF4FC3F7)))),
          SizedBox(
              width: _wTemp,
              child: Text(actual.toStringAsFixed(1),
                  style: num.copyWith(
                      color: outOfBand
                          ? const Color(0xFFE74C3C)
                          : const Color(0xFF8BD17C),
                      fontWeight:
                          outOfBand ? FontWeight.bold : FontWeight.normal))),
          SizedBox(
              width: _wBand,
              child: Text(over,
                  style: num.copyWith(
                      color: outOfBand
                          ? const Color(0xFFFFA726)
                          : Colors.white24))),
          SizedBox(
              width: _wAbuse,
              child: Text(cum.toStringAsFixed(3),
                  style: num.copyWith(
                      color: cum > 1
                          ? const Color(0xFFFFA726)
                          : Colors.white54))),
          SizedBox(
            width: _wTier,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tier.symbol,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
