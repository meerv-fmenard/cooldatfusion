import 'dart:math' as math;

import '../models/cold_chain.dart';
import '../models/routing_decision.dart';
import '../models/stage.dart';
import '../models/value_tier.dart';
import 'generator.dart';
import 'shelf_life_model.dart';
import 'value_trajectory.dart';

/// The routing brain. As each product transitions out of a stage it asks the
/// trained model to project the *total* abuse-days it will have accrued by the
/// fork, then routes/relabels accordingly. The product's realised final tier is
/// the tier its actual end-to-end abuse lands in (same scale as the value
/// curve), so the timeline and the routing stay consistent.
class DecisionTree {
  DecisionTree(this.model);

  final ShelfLifeModel model;

  ColdChain evaluate(ChainDraft draft) {
    final decisions = <RoutingDecision>[];
    final segments = <StageSegment>[];

    final shelfIdx =
        kColdChainPipeline.indexWhere((d) => d.stage == kRetailShelfStage);

    var cumAbuse = 0.0;
    var abuseThroughShelf = 0.0;

    for (final seg in draft.segments) {
      cumAbuse += seg.abuseDays;

      final stageIdx =
          kColdChainPipeline.indexWhere((d) => d.stage == seg.stage);
      final isPreOrAtShelf = stageIdx <= shelfIdx;

      final projEndAbuse = model.projectEndAbuse(
        sku: draft.sku,
        dest: draft.destination,
        atStage: seg.stage,
        abuseSoFar: cumAbuse,
      );

      if (seg.stage == kRetailShelfStage) {
        abuseThroughShelf = cumAbuse;
      }

      // Record a routing decision at each supply-chain node up to the shelf,
      // where re-routing can still recover value.
      if (isPreOrAtShelf && seg.stage != Stage.fork) {
        final tier = tierForAbuse(projEndAbuse);
        decisions.add(RoutingDecision(
          atStage: seg.stage,
          hoursElapsed: seg.endHours,
          projectedRemainingLifeDays: math.max(0, draft.baseShelfLifeDays - projEndAbuse),
          requiredLifeDays: draft.baseShelfLifeDays,
          action: _actionFor(tier, projEndAbuse),
          rationale: _rationale(seg.stage, cumAbuse, projEndAbuse, tier),
          tierAfter: tier,
        ));
      }

      segments.add(StageSegment(
        stage: seg.stage,
        startHours: seg.startHours,
        endHours: seg.endHours,
        cooltag: seg.cooltag,
        actual: seg.actual,
        lifeConsumedDays: seg.lifeConsumedDays,
        plannedLifeConsumedDays: seg.plannedLifeConsumedDays,
        abuseDays: seg.abuseDays,
      ));
    }

    // Realised outcome: the tier the product's actual total abuse lands in.
    final finalTier = tierForAbuse(cumAbuse);

    final route = model.routeFor(draft.sku, draft.destination);
    final bestBefore = route?.bestBeforeDays ?? draft.baseShelfLifeDays;
    // "Min life on shelf" reported as good days left when it hits retail.
    final minLifeOnShelf =
        math.max(0.0, draft.baseShelfLifeDays - abuseThroughShelf - 0);

    return ColdChain(
      id: draft.id,
      sku: draft.sku,
      destination: draft.destination,
      baseShelfLifeDays: draft.baseShelfLifeDays,
      baseValueUsd: draft.baseValueUsd,
      segments: segments,
      decisions: decisions,
      predictedBestBeforeDays: bestBefore,
      minLifeOnShelfDays: minLifeOnShelf,
      finalTier: finalTier,
    );
  }

  List<ColdChain> evaluateAll(List<ChainDraft> drafts) =>
      [for (final d in drafts) evaluate(d)];

  RoutingAction _actionFor(ValueTier tier, double projAbuse) {
    switch (tier) {
      case ValueTier.topQuality:
        return RoutingAction.continueAsPlanned;
      case ValueTier.inferior:
        return RoutingAction.downgrade;
      case ValueTier.urgentReroute:
        return projAbuse >= (kAbuseReroute + kAbuseCredit) / 2
            ? RoutingAction.divertUpcycle
            : RoutingAction.rerouteCloserDC;
      case ValueTier.creditDonation:
        return RoutingAction.donateCredit;
      case ValueTier.waste:
        return RoutingAction.waste;
    }
  }

  String _rationale(Stage stage, double soFar, double proj, ValueTier tier) {
    final s = soFar.toStringAsFixed(1);
    final p = proj.toStringAsFixed(1);
    final at = stageDefOf(stage).shortLabel;
    switch (tier) {
      case ValueTier.topQuality:
        return 'At $at: $s d abuse so far, projecting $p d by fork — within tolerance, hold course.';
      case ValueTier.inferior:
        return 'At $at: $s d abuse so far, projecting $p d — flag for markdown at shelf.';
      case ValueTier.urgentReroute:
        return 'At $at: $s d abuse so far, projecting $p d — reroute to a closer DC / upcycler to beat the clock.';
      case ValueTier.creditDonation:
        return 'At $at: $s d abuse so far, projecting $p d — pull from sale, credit customer, donate.';
      case ValueTier.waste:
        return 'At $at: $s d abuse so far, projecting $p d — unsafe, condemn for disposal.';
    }
  }
}

/// Aggregate portfolio economics across a batch of evaluated chains, in real
/// per-package dollars ($5–$10 a bag).
class PortfolioStats {
  PortfolioStats(List<ColdChain> chains) {
    for (final c in chains) {
      counts[c.finalTier] = (counts[c.finalTier] ?? 0) + 1;
      tierValue[c.finalTier] = (tierValue[c.finalTier] ?? 0) + c.valueUsd;
      netValue += c.valueUsd;
      idealValue += c.baseValueUsd; // every bag sold at full price
    }
    total = chains.length;
    valueRecoveryPct = idealValue == 0 ? 0 : (netValue / idealValue) * 100;
  }

  final Map<ValueTier, int> counts = {};
  final Map<ValueTier, double> tierValue = {};
  double netValue = 0;
  double idealValue = 0;
  int total = 0;
  double valueRecoveryPct = 0;

  int countOf(ValueTier t) => counts[t] ?? 0;
  double tierValueOf(ValueTier t) => tierValue[t] ?? 0;
}
