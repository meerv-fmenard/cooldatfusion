import 'package:flutter/material.dart';

import '../../models/cold_chain.dart';
import '../../models/stage.dart';
import '../../models/value_tier.dart';
import '../../sim/route_optimizer.dart';

/// The "Tree" view: the intended (as-planned) routing path beside a
/// value-optimized path that diverts the bag early — to a closer DC, an
/// upcycler, or a food bank — to capture more value before abuse destroys it.
class ChainRouteTree extends StatelessWidget {
  const ChainRouteTree({super.key, required this.chain, this.q10 = 2.5});

  final ColdChain chain;
  final double q10;

  @override
  Widget build(BuildContext context) {
    final a = analyzeRoute(chain, q10: q10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _comparison(a),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _column(
                  title: 'Intended route — as planned',
                  steps: a.intended,
                  accent: Colors.white38,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _column(
                  title: 'Value-optimized route',
                  steps: a.optimized,
                  accent: a.optimizedTier.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _comparison(RouteAnalysis a) {
    final recovered = a.recoveredUsd;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1B2230), Color(0xFF11161F)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _outcome('Intended outcome', a.intendedTier, a.intendedValueUsd),
          const Icon(Icons.arrow_right_alt, color: Colors.white38),
          _outcome('Optimized outcome', a.optimizedTier, a.optimizedValueUsd),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recovered > 0.005
                      ? '+\$${recovered.toStringAsFixed(2)} recovered'
                      : 'already optimal',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: recovered > 0.005
                          ? const Color(0xFF2ECC71)
                          : Colors.white54),
                ),
                const SizedBox(height: 2),
                Text(
                  a.divertStage == null
                      ? 'Best move: sell at ${a.optimizedChannel}'
                      : 'Divert at ${stageDefOf(a.divertStage!).shortLabel} → ${a.optimizedChannel}',
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outcome(String label, ValueTier tier, double value) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: tier.color, borderRadius: BorderRadius.circular(5)),
              child: Text(tier.symbol,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            const SizedBox(width: 6),
            Text('\$${value.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: value < 0 ? const Color(0xFFE74C3C) : Colors.white)),
          ]),
        ],
      ),
    );
  }

  Widget _column({
    required String title,
    required List<RouteStep> steps,
    required Color accent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    color: accent == Colors.white38 ? Colors.white54 : accent,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    _node(steps[i]),
                    if (i < steps.length - 1) _connector(steps[i + 1]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connector(RouteStep next) {
    final color = next.isDivert
        ? next.tier.color
        : next.skipped
            ? Colors.white12
            : Colors.white24;
    return SizedBox(
      height: 16,
      child: Center(
        child: Icon(
          next.isDivert ? Icons.subdirectory_arrow_right : Icons.arrow_downward,
          size: 14,
          color: color,
        ),
      ),
    );
  }

  Widget _node(RouteStep step) {
    final stageCol = stageColor(step.stage);
    final dim = step.skipped;
    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: step.isDivert
              ? step.tier.color.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: step.isDivert ? step.tier.color : Colors.white12,
            width: step.isDivert ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: stageCol, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stageDefOf(step.stage).label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          step.isDivert ? FontWeight.w700 : FontWeight.w500,
                      decoration:
                          dim ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${step.abuseSoFar.toStringAsFixed(1)} d',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: step.tier.color,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(step.tier.symbol,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (step.isDivert && step.channel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 17),
                child: Text(
                    '${step.sell ? "✓ SELL HERE" : "↳ DIVERT"} → ${step.channel}',
                    style: TextStyle(
                        color: step.tier.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
