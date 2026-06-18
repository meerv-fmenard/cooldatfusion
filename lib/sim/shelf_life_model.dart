import 'dart:math' as math;

import '../models/stage.dart';
import 'generator.dart';

/// The stage that represents "on the retail shelf" — the moment the grocer
/// needs the product to still have enough good life to legitimately sell it.
const Stage kRetailShelfStage = Stage.groceryFridge;

/// Result of a least-squares fit y = a + b·x.
class LinearFit {
  const LinearFit(this.a, this.b, this.r2, this.n);
  final double a;
  final double b;
  final double r2;
  final int n;

  double predict(double x) => a + b * x;
}

/// What the model has learned about one SKU × destination route, expressed in
/// abuse-days (excess spoilage beyond the 4–8 °C band).
class RouteModel {
  RouteModel({
    required this.sku,
    required this.destination,
    required this.baseLifeDays,
    required this.fit,
    required this.meanAbuseToShelf,
    required this.meanTotalAbuse,
    required this.stdTotalAbuse,
    required this.meanCumAbuseByStage,
  });

  final String sku;
  final String destination;
  final double baseLifeDays;

  /// Fit: total end-to-end abuse (y) vs abuse already seen at the shelf (x).
  final LinearFit fit;

  final double meanAbuseToShelf;
  final double meanTotalAbuse;
  final double stdTotalAbuse;

  /// Average cumulative abuse by the time the product leaves each stage.
  final Map<Stage, double> meanCumAbuseByStage;

  /// Best-before (days from packing) baked in with a one-σ safety margin on the
  /// abuse the route typically inflicts.
  double get bestBeforeDays =>
      math.max(0, baseLifeDays - (meanTotalAbuse + stdTotalAbuse));
}

/// A per-route degradation predictor *trained* from monthly cooltag sample
/// packages (one per SKU per destination per simulated month). It fits real
/// least-squares coefficients on abuse-days so its projections track the data,
/// and re-projects the product's end-of-journey abuse at any transition.
class ShelfLifeModel {
  ShelfLifeModel._(this._routes, this.monthsTrained, this.sampleCount);

  final Map<String, RouteModel> _routes;
  final int monthsTrained;
  final int sampleCount;

  static String _key(String sku, String dest) => '$sku|$dest';

  RouteModel? routeFor(String sku, String dest) => _routes[_key(sku, dest)];

  Iterable<RouteModel> get routes => _routes.values;

  /// Project total end-to-end abuse-days given the abuse already accrued up to
  /// (and including) [atStage]. This is the realtime re-assessment the routing
  /// brain runs as the product transitions out of each reefer/fridge.
  double projectEndAbuse({
    required String sku,
    required String dest,
    required Stage atStage,
    required double abuseSoFar,
  }) {
    final r = routeFor(sku, dest);
    if (r == null) return abuseSoFar;

    if (atStage == kRetailShelfStage) {
      // Use the fitted relationship at the shelf checkpoint.
      return math.max(abuseSoFar, r.fit.predict(abuseSoFar));
    }
    final expectedAtStage = r.meanCumAbuseByStage[atStage] ?? 0;
    final expectedRemaining =
        math.max(0.0, r.meanTotalAbuse - expectedAtStage);
    return abuseSoFar + expectedRemaining;
  }

  /// Train the model: generate [months] monthly batches of sample packages
  /// under normal-operations deviation and fit per-route coefficients.
  static ShelfLifeModel train({
    required double q10,
    int months = 12,
    int seed = 1234,
    double trainingDeviation = 0.3,
  }) {
    final xs = <String, List<double>>{}; // abuse at shelf
    final ys = <String, List<double>>{}; // total abuse
    final stageCum = <String, Map<Stage, List<double>>>{};
    final meta = <String, ChainDraft>{};

    var totalSamples = 0;
    for (var m = 0; m < months; m++) {
      for (final sku in kSkuBaseLifeDays.keys) {
        for (final dest in kDestinations) {
          final gen = ColdChainGenerator(GeneratorParams(
            chainCount: 1,
            deviationRate: trainingDeviation,
            seed: seed + m * 1000 + sku.hashCode % 97 + dest.hashCode % 89,
            q10: q10,
          ));
          final draft = _sample(gen, sku, dest);
          final key = _key(sku, dest);
          meta[key] = draft;

          var cum = 0.0;
          var abuseAtShelf = 0.0;
          final perStage = stageCum.putIfAbsent(key, () => {});
          for (final seg in draft.segments) {
            cum += seg.abuseDays;
            perStage.putIfAbsent(seg.stage, () => []).add(cum);
            if (seg.stage == kRetailShelfStage) abuseAtShelf = cum;
          }
          xs.putIfAbsent(key, () => []).add(abuseAtShelf);
          ys.putIfAbsent(key, () => []).add(cum);
          totalSamples++;
        }
      }
    }

    final routes = <String, RouteModel>{};
    for (final key in xs.keys) {
      final x = xs[key]!;
      final y = ys[key]!;
      final fit = _leastSquares(x, y);
      final meanY = _mean(y);
      final perStage = stageCum[key]!;
      final meanCum = <Stage, double>{
        for (final e in perStage.entries) e.key: _mean(e.value),
      };
      final draft = meta[key]!;
      routes[key] = RouteModel(
        sku: draft.sku,
        destination: draft.destination,
        baseLifeDays: draft.baseShelfLifeDays,
        fit: fit,
        meanAbuseToShelf: _mean(x),
        meanTotalAbuse: meanY,
        stdTotalAbuse: _std(y, meanY),
        meanCumAbuseByStage: meanCum,
      );
    }

    return ShelfLifeModel._(routes, months, totalSamples);
  }

  static ChainDraft _sample(ColdChainGenerator gen, String sku, String dest) {
    final base = gen.generate().first;
    return ChainDraft(
      id: base.id,
      sku: sku,
      destination: dest,
      baseShelfLifeDays: kSkuBaseLifeDays[sku]!,
      baseValueUsd: base.baseValueUsd,
      segments: base.segments,
    );
  }

  static double _mean(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  static double _std(List<double> v, double mean) {
    if (v.length < 2) return 0;
    final s = v.fold<double>(0, (acc, e) => acc + (e - mean) * (e - mean));
    return math.sqrt(s / (v.length - 1));
  }

  static LinearFit _leastSquares(List<double> x, List<double> y) {
    final n = x.length;
    if (n < 2) return LinearFit(y.isEmpty ? 0 : y.first, 1, 0, n);
    final mx = _mean(x);
    final my = _mean(y);
    var sxx = 0.0, sxy = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = x[i] - mx;
      final dy = y[i] - my;
      sxx += dx * dx;
      sxy += dx * dy;
      syy += dy * dy;
    }
    if (sxx == 0) return LinearFit(my, 1, 0, n);
    final b = sxy / sxx;
    final a = my - b * mx;
    final r2 = syy == 0 ? 1.0 : (sxy * sxy) / (sxx * syy);
    return LinearFit(a, b, r2, n);
  }
}
