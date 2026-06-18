import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cooldatfusion/sim/decision_tree.dart';
import 'package:cooldatfusion/sim/generator.dart';
import 'package:cooldatfusion/sim/shelf_life_model.dart';
import 'package:cooldatfusion/ui/widgets/chain_route_tree.dart';
import 'package:cooldatfusion/ui/widgets/chain_values_table.dart';
import 'package:cooldatfusion/ui/widgets/distances_view.dart';
import 'package:cooldatfusion/ui/widgets/ds_sla_view.dart';
import 'package:cooldatfusion/ui/widgets/product_timeline.dart';

void main() {
  testWidgets('graph and values views build without error', (tester) async {
    final model = ShelfLifeModel.train(q10: 2.5);
    final draft = ColdChainGenerator(
      const GeneratorParams(chainCount: 1, deviationRate: 0.6, seed: 3),
    ).generate().first;
    final chain = DecisionTree(model).evaluate(draft);

    Widget host(Widget child) => MaterialApp(
          home: Scaffold(body: SizedBox(width: 1000, height: 600, child: child)),
        );

    await tester.pumpWidget(host(ProductTimeline(chain: chain)));
    expect(find.byType(ProductTimeline), findsOneWidget);

    await tester.pumpWidget(host(ChainValuesTable(chain: chain)));
    expect(find.byType(ChainValuesTable), findsOneWidget);

    await tester.pumpWidget(host(ChainRouteTree(chain: chain)));
    expect(find.byType(ChainRouteTree), findsOneWidget);

    await tester.pumpWidget(host(DistancesView(chain: chain)));
    expect(find.byType(DistancesView), findsOneWidget);

    await tester.pumpWidget(host(DsSlaView(chain: chain)));
    expect(find.byType(DsSlaView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('higher deviation rate destroys more portfolio value', () {
    PortfolioStats run(double dev) {
      final model = ShelfLifeModel.train(q10: 2.5);
      final drafts = ColdChainGenerator(
        GeneratorParams(chainCount: 60, deviationRate: dev, seed: 42),
      ).generate();
      final chains = DecisionTree(model).evaluateAll(drafts);
      return PortfolioStats(chains);
    }

    final clean = run(0.05);
    final messy = run(0.9);

    expect(clean.total, 60);
    expect(messy.total, 60);
    // A clean cold chain should recover more value than a badly abused one.
    expect(clean.netValue, greaterThan(messy.netValue));
  });
}
