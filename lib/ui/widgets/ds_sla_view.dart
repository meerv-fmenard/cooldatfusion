import 'package:flutter/material.dart';

import '../../models/cold_chain.dart';
import '../../models/value_tier.dart';
import '../../sim/distances.dart';
import '../../sim/ds_sla.dart';

/// Destination-Specific Shelf-Life Allocation view: for the selected package,
/// evaluate every destination's shelf-life requirement against the package's
/// remaining life at the DC, and recommend the value-preserving destination.
class DsSlaView extends StatelessWidget {
  const DsSlaView({super.key, required this.chain});

  final ColdChain chain;

  @override
  Widget build(BuildContext context) {
    final r = allocate(chain);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(r),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Each destination needs a minimum remaining shelf life (longer haul '
            '→ more life needed). The package is allocated to the destination '
            'that preserves the most value.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [for (final o in r.options) _row(o, r)],
          ),
        ),
      ],
    );
  }

  Widget _header(DsSlaResult r) {
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
          _stat('Remaining life at DC',
              '${r.remainingLifeAtAlloc.toStringAsFixed(1)} d'),
          _allocChip('Intended', r.intended),
          const Icon(Icons.arrow_right_alt, color: Colors.white38),
          _allocChip('Recommended', r.recommended),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.preservedUsd > 0.005
                      ? '+\$${r.preservedUsd.toStringAsFixed(2)} preserved'
                      : 'intended is optimal',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: r.preservedUsd > 0.005
                          ? const Color(0xFF2ECC71)
                          : Colors.white54),
                ),
                Text(
                  r.changesDestination
                      ? 'Reallocate ${r.intended.destination} → ${r.recommended.destination}'
                      : 'Keep ${r.intended.destination}',
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

  Widget _stat(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _allocChip(String label, DestAllocation a) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: destinationColor(a.destination),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 5),
              Text(a.destination,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              _tierChip(a.tier),
            ]),
          ],
        ),
      );

  Widget _tierChip(ValueTier t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: t.color, borderRadius: BorderRadius.circular(4)),
        child: Text(t.symbol,
            style: const TextStyle(
                color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _row(DestAllocation o, DsSlaResult r) {
    final color = destinationColor(o.destination);
    final viable = o.marginDays >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: o.isRecommended
            ? const Color(0xFF2ECC71).withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: o.isRecommended
              ? const Color(0xFF2ECC71)
              : Colors.white12,
          width: o.isRecommended ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Text(o.destination,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${o.distanceKm.toStringAsFixed(0)} km',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              if (o.isIntended) _tag('INTENDED', Colors.white54),
              if (o.isRecommended) _tag('RECOMMENDED', const Color(0xFF2ECC71)),
              const Spacer(),
              _tierChip(o.tier),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: Text('\$${o.valueUsd.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: o.valueUsd < 0
                            ? const Color(0xFFE74C3C)
                            : Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _marginBar(o),
          const SizedBox(height: 4),
          Text(
            'needs ${o.requirementDays.toStringAsFixed(1)} d  ·  '
            'has ${o.remainingLifeDays.toStringAsFixed(1)} d  ·  '
            'margin ${o.marginDays >= 0 ? '+' : ''}${o.marginDays.toStringAsFixed(1)} d'
            '${viable ? '' : '  ·  arrives short'}',
            style: TextStyle(
                color: viable ? Colors.white54 : const Color(0xFFE67E22),
                fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _tag(String s, Color c) => Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withValues(alpha: 0.6)),
        ),
        child: Text(s,
            style: TextStyle(
                color: c, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  /// A bar showing the destination's requirement vs the package's remaining
  /// life: green portion = life available up to the requirement, the marker is
  /// the requirement line; overflow beyond requirement is the safety margin.
  Widget _marginBar(DestAllocation o) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      // Scale: show up to max(remaining, requirement) + a little headroom.
      final scaleMax = (o.remainingLifeDays > o.requirementDays
              ? o.remainingLifeDays
              : o.requirementDays) *
          1.1;
      final lifeW = scaleMax <= 0 ? 0.0 : (o.remainingLifeDays / scaleMax) * w;
      final reqX = scaleMax <= 0 ? 0.0 : (o.requirementDays / scaleMax) * w;
      final ok = o.remainingLifeDays >= o.requirementDays;
      return SizedBox(
        height: 12,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              width: lifeW.clamp(0, w).toDouble(),
              decoration: BoxDecoration(
                color: (ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C))
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // requirement marker
            Positioned(
              left: reqX.clamp(0, w).toDouble(),
              top: -1,
              bottom: -1,
              child: Container(width: 2, color: Colors.white70),
            ),
          ],
        ),
      );
    });
  }
}
