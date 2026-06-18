import '../models/cold_chain.dart';
import '../models/stage.dart';
import '../models/value_tier.dart';
import 'distances.dart';
import 'generator.dart';

/// The point in the chain where the destination is (re)allocated: the grocer
/// distribution center decides which store a bag is shipped to.
const Stage kAllocationStage = Stage.grocerDC;

/// Days of shelf life a destination requires from the allocation point onward:
/// a fixed retail + consumer buffer plus transit time that scales with the
/// destination's distance. Closer destinations need less life.
double destinationRequirementDays(String dest) =>
    3.0 + totalDistanceKm(dest) / 120.0;

/// Map a remaining-life margin (days beyond requirement) to a value tier.
ValueTier tierForMargin(double marginDays) {
  if (marginDays >= 2.0) return ValueTier.topQuality;
  if (marginDays >= 0.5) return ValueTier.inferior;
  if (marginDays >= -1.5) return ValueTier.urgentReroute;
  if (marginDays >= -4.0) return ValueTier.creditDonation;
  return ValueTier.waste;
}

/// One candidate destination's allocation for a package.
class DestAllocation {
  DestAllocation({
    required this.destination,
    required this.distanceKm,
    required this.requirementDays,
    required this.remainingLifeDays,
    required this.marginDays,
    required this.tier,
    required this.valueUsd,
    required this.isIntended,
    required this.isRecommended,
  });

  final String destination;
  final double distanceKm;
  final double requirementDays;
  final double remainingLifeDays;
  final double marginDays;
  final ValueTier tier;
  final double valueUsd;
  final bool isIntended;
  final bool isRecommended;

  DestAllocation copyWith({bool? isRecommended}) => DestAllocation(
        destination: destination,
        distanceKm: distanceKm,
        requirementDays: requirementDays,
        remainingLifeDays: remainingLifeDays,
        marginDays: marginDays,
        tier: tier,
        valueUsd: valueUsd,
        isIntended: isIntended,
        isRecommended: isRecommended ?? this.isRecommended,
      );
}

/// Destination-Specific Shelf-Life Allocation for one package: evaluate it
/// against every destination at the DC and recommend the value-preserving one.
class DsSlaResult {
  DsSlaResult({
    required this.remainingLifeAtAlloc,
    required this.options,
    required this.intended,
    required this.recommended,
  });

  /// Remaining shelf life (days) when the package reaches the allocation DC.
  final double remainingLifeAtAlloc;

  /// One row per destination, ordered nearest → farthest.
  final List<DestAllocation> options;
  final DestAllocation intended;
  final DestAllocation recommended;

  double get preservedUsd => recommended.valueUsd - intended.valueUsd;
  bool get changesDestination => recommended.destination != intended.destination;
}

DsSlaResult allocate(ColdChain c) {
  // Shelf life consumed up to (and including) the allocation DC.
  var consumed = 0.0;
  for (final seg in c.segments) {
    consumed += seg.lifeConsumedDays;
    if (seg.stage == kAllocationStage) break;
  }
  final remaining = c.baseShelfLifeDays - consumed;

  var options = [
    for (final dest in kDestinations)
      () {
        final req = destinationRequirementDays(dest);
        final margin = remaining - req;
        final tier = tierForMargin(margin);
        return DestAllocation(
          destination: dest,
          distanceKm: totalDistanceKm(dest),
          requirementDays: req,
          remainingLifeDays: remaining,
          marginDays: margin,
          tier: tier,
          valueUsd: tier.multiplier * c.baseValueUsd,
          isIntended: dest == c.destination,
          isRecommended: false,
        );
      }()
  ];

  // Recommend the highest-value destination; among ties serve the farthest
  // viable market (highest requirement) to cover the broadest demand.
  DestAllocation best = options.first;
  for (final o in options) {
    if (o.valueUsd > best.valueUsd ||
        (o.valueUsd == best.valueUsd &&
            o.requirementDays > best.requirementDays)) {
      best = o;
    }
  }

  options = [
    for (final o in options)
      o.copyWith(isRecommended: o.destination == best.destination)
  ]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  final intended = options.firstWhere((o) => o.isIntended);
  final recommended = options.firstWhere((o) => o.isRecommended);

  return DsSlaResult(
    remainingLifeAtAlloc: remaining,
    options: options,
    intended: intended,
    recommended: recommended,
  );
}
