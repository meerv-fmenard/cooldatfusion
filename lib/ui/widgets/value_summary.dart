import 'package:flutter/material.dart';

import '../../models/value_tier.dart';
import '../../sim/decision_tree.dart';

/// Bottom strip: per-tier counts + dollars and the net portfolio value.
class ValueSummary extends StatelessWidget {
  const ValueSummary({super.key, required this.stats});

  final PortfolioStats stats;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in kTierOrder)
            Expanded(child: _tierCard(context, t)),
          const SizedBox(width: 10),
          _netCard(context),
        ],
      ),
    );
  }

  Widget _tierCard(BuildContext context, ValueTier t) {
    final count = stats.countOf(t);
    final pct = stats.total == 0 ? 0.0 : count / stats.total;
    final dollars = stats.tierValueOf(t);
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: t.color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(t.symbol,
                style: TextStyle(
                    color: t.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const Spacer(),
            Text('$count',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          const SizedBox(height: 2),
          Text(t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(t.color),
            ),
          ),
          const SizedBox(height: 6),
          Text('\$${dollars.toStringAsFixed(0)}',
              style: TextStyle(
                  color: dollars < 0 ? const Color(0xFFE74C3C) : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _netCard(BuildContext context) {
    final net = stats.netValue;
    final recovery = stats.valueRecoveryPct;
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1B2230), Color(0xFF11161F)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('NET PORTFOLIO VALUE',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('\$${net.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: net < 0
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFF2ECC71))),
          const SizedBox(height: 2),
          Text('${recovery.toStringAsFixed(0)}% of ideal  ·  ${stats.total} packages',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
