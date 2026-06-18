import 'package:flutter/material.dart';

import '../../models/cold_chain.dart';
import '../../models/routing_decision.dart';
import '../../models/stage.dart';
import '../../models/value_tier.dart';
import 'decision_tree_view.dart';
import 'temp_scale.dart';

/// Right-hand detail panel for the selected product: outcome header, routing
/// decision tree, the per-transition decision log, and a stage-by-stage table.
class ChainInspector extends StatelessWidget {
  const ChainInspector({super.key, required this.chain});

  final ColdChain? chain;

  @override
  Widget build(BuildContext context) {
    final c = chain;
    if (c == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Generate a batch to inspect a bag of salad — its routing '
            'decisions, the decision tree, and the dollar outcome.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(c),
          const SizedBox(height: 16),
          DecisionTreeView(chain: c),
          const SizedBox(height: 16),
          _sectionLabel('Decision log (each transition)'),
          const SizedBox(height: 8),
          ...c.decisions.map(_decisionTile),
          const SizedBox(height: 16),
          _sectionLabel('Stage-by-stage'),
          const SizedBox(height: 8),
          _stageTable(c),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _header(ColdChain c) {
    final tier = c.finalTier;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tier.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Package #${c.id}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tier.symbol,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('${c.sku}  ·  ${c.destination}  ·  ${tier.label}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _metric('Bag value', '\$${c.baseValueUsd.toStringAsFixed(2)}'),
              _metric('Outcome value', '\$${c.valueUsd.toStringAsFixed(2)}',
                  c.valueUsd < 0 ? const Color(0xFFE74C3C) : null),
              _metric('Abuse-days', c.totalAbuseDays.toStringAsFixed(1),
                  c.totalAbuseDays > 1 ? const Color(0xFFFFA726) : null),
              _metric('Best-before',
                  '${c.predictedBestBeforeDays.toStringAsFixed(1)} d'),
              _metric('Good days at shelf',
                  '${c.minLifeOnShelfDays.toStringAsFixed(1)} d'),
              _metric('Peak temp', '${c.peakTemp.toStringAsFixed(1)}°C',
                  c.peakTemp > 8 ? const Color(0xFFE74C3C) : null),
              _metric('Farm-to-fork',
                  '${(c.totalHours / 24).toStringAsFixed(1)} d'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, [Color? valueColor]) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: valueColor ?? Colors.white)),
        ],
      );

  Widget _sectionLabel(String s) => Text(s.toUpperCase(),
      style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          letterSpacing: 1.0,
          fontWeight: FontWeight.bold));

  Widget _decisionTile(RoutingDecision d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: d.tierAfter.color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(stageDefOf(d.atStage).shortLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 8),
              Text('${(d.hoursElapsed / 24).toStringAsFixed(1)} d',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              Text(d.action.label,
                  style: TextStyle(
                      color: d.tierAfter.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          Text(d.rationale,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _stageTable(ColdChain c) {
    return Column(
      children: [
        for (final s in c.segments)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: tempScaleColor(s.peakActualTemp),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    width: 86,
                    child: Text(stageDefOf(s.stage).shortLabel,
                        style: const TextStyle(fontSize: 12))),
                Expanded(
                  child: Text(
                    s.stage == Stage.fork
                        ? 'consumed'
                        : 'peak ${s.peakActualTemp.toStringAsFixed(1)}°C',
                    style: TextStyle(
                        fontSize: 11,
                        color: s.hadBreach
                            ? const Color(0xFFE74C3C)
                            : Colors.white54),
                  ),
                ),
                Text(
                  s.abuseDays > 0.05
                      ? '+${s.abuseDays.toStringAsFixed(1)} abuse-d'
                      : 'clean',
                  style: TextStyle(
                      fontSize: 11,
                      color: s.abuseDays > 0.05
                          ? const Color(0xFFFFA726)
                          : Colors.white38),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
