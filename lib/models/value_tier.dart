import 'package:flutter/material.dart';

/// The five product-value outcomes a package can land in (the Y axis).
enum ValueTier {
  /// $$$ — full margin, no meaningful deviation.
  topQuality,

  /// $$ — minor cold-chain deviation, sold at markdown.
  inferior,

  /// $ — major deviation; urgent re-route to a closer DC or upcycling facility.
  urgentReroute,

  /// -$ — life exhausted before retail; customer credits + food-bank donation.
  creditDonation,

  /// --$ — unsafe; disposal cost PLUS customer credits (double negative).
  waste,
}

extension ValueTierInfo on ValueTier {
  String get symbol {
    switch (this) {
      case ValueTier.topQuality:
        return r'$$$';
      case ValueTier.inferior:
        return r'$$';
      case ValueTier.urgentReroute:
        return r'$';
      case ValueTier.creditDonation:
        return r'-$';
      case ValueTier.waste:
        return r'--$';
    }
  }

  String get label {
    switch (this) {
      case ValueTier.topQuality:
        return 'Top quality';
      case ValueTier.inferior:
        return 'Inferior (markdown)';
      case ValueTier.urgentReroute:
        return 'Urgent reroute / upcycle';
      case ValueTier.creditDonation:
        return 'Credit + donation';
      case ValueTier.waste:
        return 'Waste disposal';
    }
  }

  /// Fraction of a bag's top value recovered (or lost) in this tier. Applied to
  /// the package's own value ($5–$10), so dollars are computed per package.
  /// Negative tiers cost money; waste roughly doubles the credit hit (disposal
  /// cost on top of the customer credit).
  double get multiplier {
    switch (this) {
      case ValueTier.topQuality:
        return 1.0; // full price
      case ValueTier.inferior:
        return 0.6; // markdown
      case ValueTier.urgentReroute:
        return 0.25; // salvage / upcycle recovery
      case ValueTier.creditDonation:
        return -0.5; // customer credit + donation cost
      case ValueTier.waste:
        return -1.0; // disposal cost + customer credit
    }
  }

  Color get color {
    switch (this) {
      case ValueTier.topQuality:
        return const Color(0xFF2ECC71);
      case ValueTier.inferior:
        return const Color(0xFFA3D94B);
      case ValueTier.urgentReroute:
        return const Color(0xFFF1C40F);
      case ValueTier.creditDonation:
        return const Color(0xFFE67E22);
      case ValueTier.waste:
        return const Color(0xFFE74C3C);
    }
  }
}

/// Tiers ordered from best (top of chart) to worst (bottom).
const List<ValueTier> kTierOrder = <ValueTier>[
  ValueTier.topQuality,
  ValueTier.inferior,
  ValueTier.urgentReroute,
  ValueTier.creditDonation,
  ValueTier.waste,
];
