import 'stage.dart';
import 'value_tier.dart';

/// The action the routing brain takes at a stage transition.
enum RoutingAction {
  continueAsPlanned,
  downgrade, // sell, but at markdown ($$)
  rerouteCloserDC, // major deviation: ship to a nearer DC to claw back life
  divertUpcycle, // send to an upcycling facility (pet food, rendering, etc.)
  donateCredit, // pull from sale, credit customer, donate to food bank
  waste, // condemn: disposal cost + customer credit
}

extension RoutingActionInfo on RoutingAction {
  String get label {
    switch (this) {
      case RoutingAction.continueAsPlanned:
        return 'Continue as planned';
      case RoutingAction.downgrade:
        return 'Downgrade to markdown';
      case RoutingAction.rerouteCloserDC:
        return 'Reroute to closer DC';
      case RoutingAction.divertUpcycle:
        return 'Divert to upcycling';
      case RoutingAction.donateCredit:
        return 'Donate + credit customer';
      case RoutingAction.waste:
        return 'Condemn as waste';
    }
  }
}

/// A decision made when leaving one stage and entering the next, recorded so
/// the inspector can replay exactly why a package ended where it did.
class RoutingDecision {
  const RoutingDecision({
    required this.atStage,
    required this.hoursElapsed,
    required this.projectedRemainingLifeDays,
    required this.requiredLifeDays,
    required this.action,
    required this.rationale,
    required this.tierAfter,
  });

  final Stage atStage;
  final double hoursElapsed;

  /// What the shelf-life model projects the package has left, at this point.
  final double projectedRemainingLifeDays;

  /// How much life the package still *needs* to reach a sellable shelf.
  final double requiredLifeDays;

  final RoutingAction action;
  final String rationale;

  /// The value tier the package is provisionally assigned after this decision.
  final ValueTier tierAfter;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'atStage': atStage.name,
        'hoursElapsed': double.parse(hoursElapsed.toStringAsFixed(2)),
        'projectedRemainingLifeDays':
            double.parse(projectedRemainingLifeDays.toStringAsFixed(2)),
        'requiredLifeDays': double.parse(requiredLifeDays.toStringAsFixed(2)),
        'action': action.name,
        'rationale': rationale,
        'tierAfter': tierAfter.name,
      };
}
