import 'package:flutter/material.dart';

import '../../models/cold_chain.dart';
import '../../models/stage.dart';
import '../../sim/distances.dart';
import '../../sim/generator.dart';

/// The "Distances" view: cumulative distance travelled over time, one line per
/// destination, so the per-destination peculiarities stand out (long rural
/// line-haul + last-mile vs close-in downtown). The selected package's
/// destination is highlighted.
class DistancesView extends StatelessWidget {
  const DistancesView({super.key, required this.chain});

  final ColdChain chain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _DistancePainter(selectedDest: chain.destination),
          ),
        ),
        const SizedBox(height: 8),
        _legend(),
      ],
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final d in kDestinations)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                    color: destinationColor(d),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Text(
                '$d  ·  ${totalDistanceKm(d).toStringAsFixed(0)} km'
                '${d == chain.destination ? '  ◀ selected' : ''}',
                style: TextStyle(
                    fontSize: 11,
                    color: d == chain.destination
                        ? Colors.white
                        : Colors.white60,
                    fontWeight: d == chain.destination
                        ? FontWeight.w700
                        : FontWeight.normal),
              ),
            ],
          ),
      ],
    );
  }
}

class _DistancePainter extends CustomPainter {
  _DistancePainter({required this.selectedDest});
  final String selectedDest;

  static const double _gutter = 50;
  static const double _bottomAxis = 34;
  static const double _topPad = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = _gutter;
    final plotRight = size.width - 70; // room for end labels
    final plotTop = _topPad;
    final plotBottom = size.height - _bottomAxis;

    final maxHours = plannedTotalHours();
    var maxKm = 0.0;
    for (final d in kDestinations) {
      final t = totalDistanceKm(d);
      if (t > maxKm) maxKm = t;
    }
    maxKm = (maxKm * 1.08).ceilToDouble();

    double xOf(double h) =>
        plotLeft + (h / maxHours) * (plotRight - plotLeft);
    double yOf(double km) =>
        plotBottom - (km / maxKm) * (plotBottom - plotTop);

    // Title.
    _text(canvas, 'CUMULATIVE DISTANCE TRAVELLED (km) — PER DESTINATION',
        Offset(plotLeft, 4),
        color: Colors.white38, size: 11, bold: true);

    // Y gridlines + km labels.
    for (var i = 0; i <= 4; i++) {
      final km = maxKm * i / 4;
      final y = yOf(km);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y),
          Paint()..color = Colors.white.withValues(alpha: 0.05));
      _text(canvas, km.toStringAsFixed(0), Offset(6, y - 6),
          color: Colors.white38, size: 9);
    }

    // Stage dividers + labels for the transit legs (where distance accrues).
    var clock = 0.0;
    for (final def in kColdChainPipeline) {
      if (def.stage == Stage.fork) break;
      final x = xOf(clock);
      final transit = kTransitStages.contains(def.stage);
      canvas.drawLine(
          Offset(x, plotTop),
          Offset(x, plotBottom),
          Paint()
            ..color = Colors.white.withValues(alpha: transit ? 0.12 : 0.05)
            ..strokeWidth = transit ? 1 : 0.6);
      clock += def.plannedHours;
    }
    // shade transit legs lightly
    clock = 0.0;
    for (final def in kColdChainPipeline) {
      if (def.stage == Stage.fork) break;
      if (kTransitStages.contains(def.stage)) {
        final x0 = xOf(clock);
        final x1 = xOf(clock + def.plannedHours);
        canvas.drawRect(Rect.fromLTRB(x0, plotTop, x1, plotBottom),
            Paint()..color = Colors.white.withValues(alpha: 0.03));
        _text(canvas, stageDefOf(def.stage).shortLabel,
            Offset(x0 + 2, plotBottom + 14),
            color: Colors.white38, size: 8);
      }
      clock += def.plannedHours;
    }

    // Day ticks.
    for (var day = 0; day * 24 <= maxHours; day += 2) {
      final x = xOf(day * 24.0);
      _text(canvas, '${day}d', Offset(x, plotBottom + 2),
          color: Colors.white38, size: 9);
    }

    // One line per destination.
    for (final dest in kDestinations) {
      final selected = dest == selectedDest;
      final curve = distanceCurve(dest);
      final color = destinationColor(dest);
      final path = Path()
        ..moveTo(xOf(curve.first.hours), yOf(curve.first.km));
      for (final p in curve.skip(1)) {
        path.lineTo(xOf(p.hours), yOf(p.km));
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3.0 : 1.4
            ..strokeJoin = StrokeJoin.round
            ..color = selected ? color : color.withValues(alpha: 0.55));
      // End label.
      final last = curve.last;
      _text(canvas, '${last.km.toStringAsFixed(0)} km',
          Offset(xOf(last.hours) + 4, yOf(last.km) - 6),
          color: selected ? color : color.withValues(alpha: 0.7),
          size: selected ? 11 : 9,
          bold: selected);
    }

    // Axes.
    canvas.drawLine(Offset(plotLeft, plotTop), Offset(plotLeft, plotBottom),
        Paint()..color = Colors.white24);
    canvas.drawLine(Offset(plotLeft, plotBottom), Offset(plotRight, plotBottom),
        Paint()..color = Colors.white24);
  }

  void _text(Canvas canvas, String s, Offset at,
      {required Color color, double size = 12, bool bold = false}) {
    TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _DistancePainter old) =>
      old.selectedDest != selectedDest;
}
