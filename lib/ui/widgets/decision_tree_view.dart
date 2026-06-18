import 'package:flutter/material.dart';

import '../../models/cold_chain.dart';
import '../../models/value_tier.dart';
import '../../sim/value_trajectory.dart';

/// Visualizes the abuse-day decision tree and highlights the branch the
/// selected product followed, based on its accumulated temperature abuse.
class DecisionTreeView extends StatelessWidget {
  const DecisionTreeView({super.key, required this.chain});

  final ColdChain? chain;

  @override
  Widget build(BuildContext context) {
    final abuse = chain?.totalAbuseDays;
    final activeTier = chain?.finalTier;

    final branches = <_Branch>[
      _Branch(
        test: 'abuse < ${kAbuseInferior.toStringAsFixed(1)} d',
        outcome: ValueTier.topQuality,
        active: activeTier == ValueTier.topQuality,
      ),
      _Branch(
        test: 'abuse < ${kAbuseReroute.toStringAsFixed(1)} d',
        outcome: ValueTier.inferior,
        active: activeTier == ValueTier.inferior,
      ),
      _Branch(
        test: 'abuse < ${kAbuseCredit.toStringAsFixed(1)} d',
        outcome: ValueTier.urgentReroute,
        active: activeTier == ValueTier.urgentReroute,
      ),
      _Branch(
        test: 'abuse < ${kAbuseWaste.toStringAsFixed(1)} d',
        outcome: ValueTier.creditDonation,
        active: activeTier == ValueTier.creditDonation,
      ),
      _Branch(
        test: 'abuse ≥ ${kAbuseWaste.toStringAsFixed(1)} d',
        outcome: ValueTier.waste,
        active: activeTier == ValueTier.waste,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_tree_outlined,
                size: 16, color: Colors.white54),
            const SizedBox(width: 6),
            const Text('Routing decision tree',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (abuse != null)
              Text('${abuse.toStringAsFixed(1)} abuse-days',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ...branches.map(_branchRow),
      ],
    );
  }

  Widget _branchRow(_Branch b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: b.active
            ? b.outcome.color.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: b.active ? b.outcome.color : Colors.white12,
          width: b.active ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            b.active ? Icons.arrow_right_alt : Icons.subdirectory_arrow_right,
            size: 16,
            color: b.active ? b.outcome.color : Colors.white30,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(b.test,
                style: TextStyle(
                    fontSize: 12,
                    color: b.active ? Colors.white : Colors.white54,
                    fontWeight:
                        b.active ? FontWeight.w600 : FontWeight.normal)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: b.outcome.color.withValues(alpha: b.active ? 1 : 0.25),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              b.outcome.symbol,
              style: TextStyle(
                  color: b.active ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Branch {
  _Branch({required this.test, required this.outcome, required this.active});
  final String test;
  final ValueTier outcome;
  final bool active;
}
