import 'package:flutter_test/flutter_test.dart';

import 'package:cooldatfusion/models/value_tier.dart';
import 'package:cooldatfusion/sim/decision_tree.dart';
import 'package:cooldatfusion/sim/generator.dart';
import 'package:cooldatfusion/sim/shelf_life_model.dart';

void main() {
  PortfolioStats statsFor(ShelfLifeModel model, double dev) {
    final drafts = ColdChainGenerator(
      GeneratorParams(chainCount: 200, deviationRate: dev, seed: 7),
    ).generate();
    return PortfolioStats(DecisionTree(model).evaluateAll(drafts));
  }

  test('deviation rate sweeps the full tier spectrum', () {
    final model = ShelfLifeModel.train(q10: 2.5);

    // A near-perfect cold chain exercises the upper tiers and recovers value.
    final clean = statsFor(model, 0.05);
    expect(clean.countOf(ValueTier.topQuality), greaterThan(0));
    expect(clean.netValue, greaterThan(0));

    // A moderate chain spreads across all of the middle tiers.
    final mid = statsFor(model, 0.35);
    expect(mid.countOf(ValueTier.inferior), greaterThan(0));
    expect(mid.countOf(ValueTier.urgentReroute), greaterThan(0));
    expect(mid.countOf(ValueTier.creditDonation), greaterThan(0));

    // A badly abused chain produces waste and destroys net value.
    final messy = statsFor(model, 0.9);
    expect(messy.countOf(ValueTier.waste), greaterThan(0));
    expect(messy.netValue, lessThan(clean.netValue));
  });
}
