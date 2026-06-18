import '../models/cold_chain.dart';
import '../models/stage.dart';
import '../models/value_tier.dart';
import 'q10.dart';

/// Abuse-day thresholds (excess spoilage beyond the 4–8 °C band) that drop a
/// bag of salad from one value tier to the next. A product held perfectly
/// in-band accrues zero abuse and never leaves $$$.
const double kAbuseInferior = 1.0; // ≥ → markdown ($$)
const double kAbuseReroute = 2.5; // ≥ → urgent reroute / upcycle ($)
const double kAbuseCredit = 4.5; // ≥ → credit + donation (-$)
const double kAbuseWaste = 7.0; // ≥ → waste (--$)

ValueTier tierForAbuse(double abuseDays) {
  if (abuseDays >= kAbuseWaste) return ValueTier.waste;
  if (abuseDays >= kAbuseCredit) return ValueTier.creditDonation;
  if (abuseDays >= kAbuseReroute) return ValueTier.urgentReroute;
  if (abuseDays >= kAbuseInferior) return ValueTier.inferior;
  return ValueTier.topQuality;
}

/// One point on a product's value-over-time curve.
class ValuePoint {
  const ValuePoint({
    required this.hours,
    required this.abuseDays,
    required this.tier,
    required this.stage,
  });

  final double hours;
  final double abuseDays; // cumulative
  final ValueTier tier;
  final Stage stage;
}

/// Builds the cumulative value curve for a single product: starts at $$$ and
/// steps down through the tiers as temperature excursions accumulate over the
/// ~3-week journey. The Y position is the tier; the X position is time.
List<ValuePoint> buildValueTrajectory(ColdChain c, {double q10 = 2.5}) {
  final q = Q10Model(q10: q10);
  final out = <ValuePoint>[];
  var cum = 0.0;

  // Start of journey: pristine, full value.
  final firstStage = c.segments.isEmpty ? Stage.fork : c.segments.first.stage;
  out.add(ValuePoint(
      hours: 0, abuseDays: 0, tier: ValueTier.topQuality, stage: firstStage));

  for (final seg in c.segments) {
    final readings = seg.actual;
    for (var i = 0; i < readings.length; i++) {
      if (i == 0 && out.length == 1) {
        // already seeded the origin point
        continue;
      }
      final prev = i == 0 ? null : readings[i - 1];
      final r = readings[i];
      if (prev != null) {
        final dtHours = r.hoursElapsed - prev.hoursElapsed;
        if (dtHours > 0) {
          final avg =
              0.5 * (q.penaltyRateAt(prev.tempC) + q.penaltyRateAt(r.tempC));
          cum += avg * (dtHours / 24.0);
        }
      }
      out.add(ValuePoint(
        hours: r.hoursElapsed,
        abuseDays: cum,
        tier: tierForAbuse(cum),
        stage: seg.stage,
      ));
    }
  }
  return out;
}

/// The instants where the value curve crosses from one tier into a worse one.
class TierDrop {
  const TierDrop({
    required this.hours,
    required this.from,
    required this.to,
    required this.stage,
  });
  final double hours;
  final ValueTier from;
  final ValueTier to;
  final Stage stage;
}

List<TierDrop> tierDrops(List<ValuePoint> traj) {
  final drops = <TierDrop>[];
  for (var i = 1; i < traj.length; i++) {
    if (traj[i].tier != traj[i - 1].tier) {
      drops.add(TierDrop(
        hours: traj[i].hours,
        from: traj[i - 1].tier,
        to: traj[i].tier,
        stage: traj[i].stage,
      ));
    }
  }
  return drops;
}
