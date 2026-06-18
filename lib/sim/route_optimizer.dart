import '../models/cold_chain.dart';
import '../models/routing_decision.dart';
import '../models/stage.dart';
import '../models/value_tier.dart';
import 'value_trajectory.dart';

/// Cumulative state of the product as it leaves a stage.
class StageView {
  const StageView({
    required this.stage,
    required this.abuseSoFar,
    required this.runningTier,
  });
  final Stage stage;
  final double abuseSoFar;
  final ValueTier runningTier;
}

/// A node in a routing tree.
class RouteStep {
  const RouteStep({
    required this.stage,
    required this.abuseSoFar,
    required this.tier,
    this.isDivert = false,
    this.channel,
    this.skipped = false,
    this.sell = false,
  });
  final Stage stage;
  final double abuseSoFar;
  final ValueTier tier;
  final bool isDivert; // the action node (sell or divert) on the optimized path
  final String? channel; // label for the action endpoint
  final bool skipped; // a planned node the optimized route no longer visits
  final bool sell; // true = sell-at-shelf, false = physical divert
}

/// Compares the intended (as-planned) route against a value-optimized route
/// that may divert the product early to a closer DC / upcycler / food bank to
/// capture more value before further temperature abuse destroys it.
class RouteAnalysis {
  RouteAnalysis({
    required this.stages,
    required this.intended,
    required this.optimized,
    required this.intendedTier,
    required this.optimizedTier,
    required this.intendedValueUsd,
    required this.optimizedValueUsd,
    required this.divertStage,
    required this.optimizedAction,
    required this.optimizedChannel,
  });

  final List<StageView> stages;
  final List<RouteStep> intended;
  final List<RouteStep> optimized;
  final ValueTier intendedTier;
  final ValueTier optimizedTier;
  final double intendedValueUsd;
  final double optimizedValueUsd;
  final Stage? divertStage; // null = no divert (sell as planned)
  final RoutingAction optimizedAction;
  final String optimizedChannel;

  double get recoveredUsd => optimizedValueUsd - intendedValueUsd;
}

/// The earliest point a packaged salad can be redirected to an alternative
/// channel (it must be bagged and palletized first).
const Stage _earliestDivert = Stage.logistics3PL;

/// Salvage channels cap the value you can recover when you pull product out of
/// its planned lane — you trade full retail price for a faster, surer sale.
ValueTier _salvageChannel(double abuseAtDivert) {
  if (abuseAtDivert < kAbuseInferior) return ValueTier.inferior; // closer DC markdown
  if (abuseAtDivert < kAbuseReroute) return ValueTier.urgentReroute; // upcycle
  if (abuseAtDivert < kAbuseCredit) return ValueTier.creditDonation; // donate
  return ValueTier.waste;
}

String _divertChannel(ValueTier t) {
  switch (t) {
    case ValueTier.inferior:
      return 'closer DC (markdown)';
    case ValueTier.urgentReroute:
      return 'upcycling facility';
    case ValueTier.creditDonation:
      return 'food-bank donation';
    default:
      return 'disposal';
  }
}

String _sellChannel(ValueTier t) {
  switch (t) {
    case ValueTier.topQuality:
      return 'retail shelf (full price)';
    case ValueTier.inferior:
      return 'retail shelf (markdown)';
    case ValueTier.urgentReroute:
      return 'retail shelf (clearance)';
    default:
      return 'retail shelf';
  }
}

RoutingAction _actionFor(ValueTier t) {
  switch (t) {
    case ValueTier.topQuality:
      return RoutingAction.continueAsPlanned;
    case ValueTier.inferior:
      return RoutingAction.rerouteCloserDC;
    case ValueTier.urgentReroute:
      return RoutingAction.divertUpcycle;
    case ValueTier.creditDonation:
      return RoutingAction.donateCredit;
    case ValueTier.waste:
      return RoutingAction.waste;
  }
}

RouteAnalysis analyzeRoute(ColdChain c, {double q10 = 2.5}) {
  // Per-stage cumulative abuse.
  final stages = <StageView>[];
  var cum = 0.0;
  double abuseAtShelf = 0.0;
  final abuseByStage = <Stage, double>{};
  for (final seg in c.segments) {
    cum += seg.abuseDays;
    abuseByStage[seg.stage] = cum;
    stages.add(StageView(
      stage: seg.stage,
      abuseSoFar: cum,
      runningTier: tierForAbuse(cum),
    ));
    if (seg.stage == kRetailShelfStageForOpt) abuseAtShelf = cum;
  }

  // Intended route: follow the plan; the realised outcome is the chain's tier
  // (which carries the consumer-side abuse too).
  final intendedTier = c.finalTier;
  final intended = [
    for (final s in stages)
      RouteStep(stage: s.stage, abuseSoFar: s.abuseSoFar, tier: s.runningTier),
  ];

  // Option A: continue and sell at the retail shelf — captures the quality at
  // the point of sale, before any consumer mishandling.
  final sellTier = tierForAbuse(abuseAtShelf);

  // Option B: divert early to the best salvage channel.
  Stage? bestDivert;
  var bestDivertTier = ValueTier.waste;
  final order = kColdChainPipeline.map((d) => d.stage).toList();
  final shelfIdx = order.indexOf(kRetailShelfStageForOpt);
  for (var i = order.indexOf(_earliestDivert); i < shelfIdx; i++) {
    final st = order[i];
    final ab = abuseByStage[st];
    if (ab == null) continue;
    final ch = _salvageChannel(ab);
    if (ch.multiplier > bestDivertTier.multiplier) {
      bestDivertTier = ch;
      bestDivert = st;
    }
  }

  // Pick the higher-value strategy.
  final divertWins =
      bestDivert != null && bestDivertTier.multiplier > sellTier.multiplier;
  final optimizedTier = divertWins ? bestDivertTier : sellTier;
  final divertStage = divertWins ? bestDivert : null;
  final channel =
      divertWins ? _divertChannel(bestDivertTier) : _sellChannel(sellTier);
  final action =
      divertWins ? _actionFor(bestDivertTier) : RoutingAction.continueAsPlanned;

  // Build the optimized route node list.
  final optimized = <RouteStep>[];
  final cutIdx = divertWins
      ? order.indexOf(divertStage!)
      : shelfIdx; // sell at shelf
  for (var i = 0; i < stages.length; i++) {
    final s = stages[i];
    final idx = order.indexOf(s.stage);
    if (idx < cutIdx) {
      optimized.add(RouteStep(
          stage: s.stage, abuseSoFar: s.abuseSoFar, tier: s.runningTier));
    } else if (idx == cutIdx) {
      optimized.add(RouteStep(
        stage: s.stage,
        abuseSoFar: s.abuseSoFar,
        tier: optimizedTier,
        isDivert: true,
        sell: !divertWins,
        channel: channel,
      ));
    } else {
      optimized.add(RouteStep(
          stage: s.stage,
          abuseSoFar: s.abuseSoFar,
          tier: s.runningTier,
          skipped: true));
    }
  }

  return RouteAnalysis(
    stages: stages,
    intended: intended,
    optimized: optimized,
    intendedTier: intendedTier,
    optimizedTier: optimizedTier,
    intendedValueUsd: intendedTier.multiplier * c.baseValueUsd,
    optimizedValueUsd: optimizedTier.multiplier * c.baseValueUsd,
    divertStage: divertStage,
    optimizedAction: action,
    optimizedChannel: channel,
  );
}

/// Local alias to avoid importing the model file's shelf constant transitively.
const Stage kRetailShelfStageForOpt = Stage.groceryFridge;
