import 'package:flutter/material.dart';

import '../../models/value_tier.dart';
import 'temp_scale.dart';

/// Color legend for the temperature scale and the five value tiers.
class Legend extends StatelessWidget {
  const Legend({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white60,
        );
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Temp', style: muted),
          const SizedBox(width: 8),
          Container(
            width: 120,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(colors: [
                Color(0xFF1565C0), // cold (sub-4)
                Color(0xFF2ECC71), // in-band 4–8
                Color(0xFFF1C40F),
                Color(0xFFE74C3C), // hot breach
              ], stops: [
                0.0,
                0.35,
                0.6,
                1.0,
              ]),
            ),
          ),
          const SizedBox(width: 6),
          Text('4–8°C target', style: muted),
        ]),
        ...kTierOrder.map((t) => _swatch(t.color, '${t.symbol}  ${t.label}', muted)),
      ],
    );
  }

  Widget _swatch(Color c, String label, TextStyle? style) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: style),
        ],
      );
}

/// Shared temperature→color mapping so the chart and legend agree.
class TempColor {
  static Color of(double tempC) => tempScaleColor(tempC);
}
