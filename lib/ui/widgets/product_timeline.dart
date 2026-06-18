import 'package:flutter/material.dart';

import '../../models/cold_chain.dart';
import '../../models/stage.dart';
import '../../models/value_tier.dart';
import '../../sim/value_trajectory.dart';

/// The timeline spans a fixed 30-day window, tick-marked 6 times a day.
const int kAxisDays = 30;
const double kTicksPerDay = 6; // a tick every 4 hours

/// The hero, single-product view.
///
/// Top panel: the product's VALUE over TIME — Y is the five value tiers, X is
/// time across a fixed 30-day window (scroll horizontally). A bag of salad held
/// perfectly at 4–8 °C rides flat along $$$; as excursions accrue, it steps
/// down through the tiers.
///
/// Bottom panel: the TEMPERATURE time-series on the same X axis, each cold-chain
/// element drawn as its own colored line beneath the 4–8 °C band.
///
/// The left axis (tier + °C labels) is frozen while the plot scrolls.
class ProductTimeline extends StatefulWidget {
  const ProductTimeline({
    super.key,
    required this.chain,
    this.q10 = 2.5,
    this.pixelsPerDay = 120,
  });

  final ColdChain chain;
  final double q10;
  final double pixelsPerDay;

  @override
  State<ProductTimeline> createState() => _ProductTimelineState();
}

class _ProductTimelineState extends State<ProductTimeline> {
  final ScrollController _h = ScrollController();

  @override
  void dispose() {
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chain = widget.chain;
    final traj = buildValueTrajectory(chain, q10: widget.q10);
    final drops = tierDrops(traj);
    final maxTemp = _maxTemp(chain);
    final pxPerDay = widget.pixelsPerDay;
    final plotWidth = kAxisDays * pxPerDay;

    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: CustomPaint(
              size: Size(52, h),
              painter: _AxisPainter(maxTemp: maxTemp),
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _h,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _h,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: plotWidth,
                  height: h,
                  child: CustomPaint(
                    painter: _PlotPainter(
                      chain: chain,
                      traj: traj,
                      drops: drops,
                      maxTemp: maxTemp,
                      pixelsPerDay: pxPerDay,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

double _maxTemp(ColdChain c) {
  final peak = c.peakTemp;
  return peak.isFinite ? (peak + 2).clamp(12.0, 40.0) : 12.0;
}

const double _stageStrip = 32;
const double _bottomAxis = 28;
const double _minTemp = -4.0;

/// Shared vertical layout so the frozen axis and the scrolling plot agree.
class _VLayout {
  _VLayout(double height, this.maxTemp) {
    final usable = height - _stageStrip - _bottomAxis;
    valueH = usable * 0.46;
    tempTop = valueH + _stageStrip;
    tempH = usable - valueH;
  }
  final double maxTemp;
  late final double valueH;
  late final double tempTop;
  late final double tempH;

  double bandH() => valueH / kTierOrder.length;

  double yOfTier(ValueTier t) {
    final idx = kTierOrder.indexOf(t);
    return idx * bandH() + bandH() / 2;
  }

  double yOfTemp(double tC) =>
      (tempTop + tempH) - ((tC - _minTemp) / (maxTemp - _minTemp)) * tempH;
}

/// Frozen left axis: tier symbols/values and temperature labels.
class _AxisPainter extends CustomPainter {
  _AxisPainter({required this.maxTemp});
  final double maxTemp;

  @override
  void paint(Canvas canvas, Size size) {
    final l = _VLayout(size.height, maxTemp);
    final bandH = l.bandH();

    for (var i = 0; i < kTierOrder.length; i++) {
      final tier = kTierOrder[i];
      final cy = i * bandH + bandH / 2;
      canvas.drawRect(Rect.fromLTWH(size.width - 4, i * bandH, 4, bandH),
          Paint()..color = tier.color.withValues(alpha: 0.7));
      _text(canvas, tier.symbol, Offset(6, cy - 15),
          color: tier.color, size: 13, bold: true);
      final pct = (tier.multiplier * 100).round();
      _text(canvas, pct >= 0 ? '$pct%' : '−${pct.abs()}%', Offset(6, cy + 2),
          color: Colors.white38, size: 9);
    }

    for (final t in [0.0, 8.0, 16.0, 24.0, 32.0]) {
      if (t > maxTemp) continue;
      final y = l.yOfTemp(t);
      _text(canvas, '${t.toStringAsFixed(0)}°', Offset(6, y - 6),
          color: Colors.white38, size: 9);
    }
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
  bool shouldRepaint(covariant _AxisPainter old) => old.maxTemp != maxTemp;
}

/// The scrolling plot: value step-line + per-element temperature lines, on a
/// fixed 30-day axis ticked 6 times a day.
class _PlotPainter extends CustomPainter {
  _PlotPainter({
    required this.chain,
    required this.traj,
    required this.drops,
    required this.maxTemp,
    required this.pixelsPerDay,
  });

  final ColdChain chain;
  final List<ValuePoint> traj;
  final List<TierDrop> drops;
  final double maxTemp;
  final double pixelsPerDay;

  double _xOf(double hours) => (hours / 24.0) * pixelsPerDay;

  @override
  void paint(Canvas canvas, Size size) {
    final l = _VLayout(size.height, maxTemp);
    _paintTimeGrid(canvas, size, l);
    _paintValuePanel(canvas, size, l);
    _paintStageStrip(canvas, size, l);
    _paintTempPanel(canvas, size, l);
  }

  // 6 ticks/day minor gridlines + day markers, spanning both panels.
  void _paintTimeGrid(Canvas canvas, Size size, _VLayout l) {
    final gridTop = 0.0;
    final gridBottom = size.height - _bottomAxis;
    final minorEveryH = 24 / kTicksPerDay; // 4 h
    final totalH = kAxisDays * 24;

    final tickSpacing = pixelsPerDay / kTicksPerDay;
    final showMinorTicks = tickSpacing >= 5;
    final showHourLabels = tickSpacing >= 16;
    final showDayLabels = pixelsPerDay >= 26;

    for (var hour = 0.0; hour <= totalH; hour += minorEveryH) {
      final x = _xOf(hour);
      final isDay = (hour % 24) == 0;
      if (isDay || showMinorTicks) {
        canvas.drawLine(
          Offset(x, gridTop),
          Offset(x, gridBottom),
          Paint()
            ..color = Colors.white.withValues(alpha: isDay ? 0.12 : 0.04)
            ..strokeWidth = isDay ? 1 : 0.6,
        );
      }
      // hour-of-day label under every minor tick (0,4,8,12,16,20)
      if (showHourLabels) {
        final hod = (hour % 24).toInt();
        _text(canvas, hod.toString().padLeft(2, '0'),
            Offset(x + 2, gridBottom + 2),
            color: Colors.white24, size: 8);
      }
      if (isDay && showDayLabels) {
        _text(canvas, 'Day ${(hour / 24).toInt()}',
            Offset(x + 2, gridBottom + 13),
            color: Colors.white54, size: 9, bold: true);
      }
    }
  }

  void _paintValuePanel(Canvas canvas, Size size, _VLayout l) {
    final bandH = l.bandH();
    for (var i = 0; i < kTierOrder.length; i++) {
      final tier = kTierOrder[i];
      canvas.drawRect(
        Rect.fromLTWH(0, i * bandH, size.width, bandH),
        Paint()..color = tier.color.withValues(alpha: i.isEven ? 0.06 : 0.03),
      );
      canvas.drawLine(Offset(0, i * bandH), Offset(size.width, i * bandH),
          Paint()..color = Colors.white.withValues(alpha: 0.05));
    }

    if (traj.isEmpty) return;

    final path = Path();
    var started = false;
    var prevY = l.yOfTier(traj.first.tier);
    for (final p in traj) {
      final x = _xOf(p.hours);
      final y = l.yOfTier(p.tier);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else if (y != prevY) {
        path.lineTo(x, prevY);
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      prevY = y;
    }

    final lineColor = chain.finalTier.color;
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = lineColor.withValues(alpha: 0.18)
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = lineColor
          ..strokeJoin = StrokeJoin.round);

    for (final d in drops) {
      final x = _xOf(d.hours);
      final y = l.yOfTier(d.to);
      canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = d.to.color);
      canvas.drawCircle(
          Offset(x, y),
          3.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white);
    }
    canvas.drawCircle(Offset(_xOf(0), l.yOfTier(ValueTier.topQuality)), 3.0,
        Paint()..color = Colors.white);

    _text(canvas, 'PRODUCT VALUE OVER TIME', const Offset(6, 4),
        color: Colors.white38, size: 10, bold: true);
  }

  void _paintStageStrip(Canvas canvas, Size size, _VLayout l) {
    final stripTop = l.valueH;
    for (final seg in chain.segments) {
      final x = _xOf(seg.startHours);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height - _bottomAxis),
          Paint()..color = Colors.white.withValues(alpha: 0.10)..strokeWidth = 1);
    }
    for (final seg in chain.segments) {
      if (seg.stage == Stage.fork) continue;
      final mid = (_xOf(seg.startHours) + _xOf(seg.endHours)) / 2;
      final def = stageDefOf(seg.stage);
      final color = stageColor(seg.stage);
      final tp = _layout(def.shortLabel, color: color, size: 9.5, bold: true);
      canvas.drawRect(Rect.fromLTWH(mid - tp.width / 2 - 7, stripTop + 10, 5, 5),
          Paint()..color = color);
      tp.paint(canvas, Offset(mid - tp.width / 2, stripTop + 7));
    }
    // Fork marker.
    if (chain.segments.isNotEmpty) {
      final x = _xOf(chain.totalHours);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height - _bottomAxis),
          Paint()
            ..color = const Color(0xFFB0BEC5).withValues(alpha: 0.6)
            ..strokeWidth = 1.2);
      _text(canvas, '🍴 fork', Offset(x + 3, l.valueH + 7),
          color: Colors.white60, size: 9, bold: true);
    }
  }

  void _paintTempPanel(Canvas canvas, Size size, _VLayout l) {
    final top = l.tempTop;
    final area = Rect.fromLTWH(0, top, size.width, l.tempH);

    canvas.drawRect(
      Rect.fromLTRB(0, l.yOfTemp(8), size.width, l.yOfTemp(4)),
      Paint()..color = const Color(0x332ECC71),
    );
    for (final tline in [4.0, 8.0]) {
      canvas.drawLine(Offset(0, l.yOfTemp(tline)),
          Offset(size.width, l.yOfTemp(tline)),
          Paint()
            ..color = const Color(0xFF2ECC71).withValues(alpha: 0.5)
            ..strokeWidth = 1);
    }
    for (final t in [0.0, 8.0, 16.0, 24.0, 32.0]) {
      if (t > maxTemp) continue;
      final y = l.yOfTemp(t);
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          Paint()..color = Colors.white.withValues(alpha: 0.04));
    }

    for (final seg in chain.segments) {
      if (seg.actual.length < 2) continue;
      final color = stageColor(seg.stage);
      final path = Path()
        ..moveTo(_xOf(seg.actual.first.hoursElapsed),
            l.yOfTemp(seg.actual.first.tempC));
      for (final r in seg.actual.skip(1)) {
        path.lineTo(_xOf(r.hoursElapsed), l.yOfTemp(r.tempC));
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = seg.hadBreach ? 2.2 : 1.6
            ..strokeJoin = StrokeJoin.round
            ..color = color);
    }

    final plan = chain.allCooltag;
    if (plan.length > 1) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.25);
      for (var i = 1; i < plan.length; i++) {
        canvas.drawLine(
            Offset(_xOf(plan[i - 1].hoursElapsed), l.yOfTemp(plan[i - 1].tempC)),
            Offset(_xOf(plan[i].hoursElapsed), l.yOfTemp(plan[i].tempC)), p);
      }
    }

    canvas.drawRect(
        area,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white12);
    _text(canvas, 'TEMPERATURE BY COLD-CHAIN ELEMENT (°C)',
        Offset(6, top + 3),
        color: Colors.white38, size: 10, bold: true);
  }

  TextPainter _layout(String s,
      {required Color color, double size = 12, bool bold = false}) {
    return TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _text(Canvas canvas, String s, Offset at,
      {required Color color, double size = 12, bool bold = false}) {
    _layout(s, color: color, size: size, bold: bold).paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) =>
      old.chain != chain ||
      old.traj != traj ||
      old.maxTemp != maxTemp ||
      old.pixelsPerDay != pixelsPerDay;
}
