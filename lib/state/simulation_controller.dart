import 'package:flutter/foundation.dart';

import '../models/cold_chain.dart';
import '../sim/decision_tree.dart';
import '../sim/generator.dart';
import '../sim/shelf_life_model.dart';
import '../sim/value_trajectory.dart';

/// Which view the main pane shows.
enum MainView { graph, table, tree, distances, dsSla }

/// Holds the simulation parameters and the latest generated batch, and re-runs
/// the whole pipeline (generate → train model → route) on demand.
class SimulationController extends ChangeNotifier {
  SimulationController() {
    regenerate();
  }

  GeneratorParams _params = const GeneratorParams();
  GeneratorParams get params => _params;

  List<ColdChain> _chains = const [];
  List<ColdChain> get chains => _chains;

  ShelfLifeModel? _model;
  ShelfLifeModel? get model => _model;

  PortfolioStats _stats = PortfolioStats(const []);
  PortfolioStats get stats => _stats;

  int? _selectedId;
  int? get selectedId => _selectedId;

  /// Filters for the package picker. 'All' = no filter.
  String _skuFilter = 'All';
  String _destFilter = 'All';
  String get skuFilter => _skuFilter;
  String get destFilter => _destFilter;

  List<String> get skus => kSkuBaseLifeDays.keys.toList();
  List<String> get destinations => kDestinations;

  /// Packages matching the current SKU + destination filters.
  List<ColdChain> get filteredChains => _chains
      .where((c) =>
          (_skuFilter == 'All' || c.sku == _skuFilter) &&
          (_destFilter == 'All' || c.destination == _destFilter))
      .toList();

  void setSkuFilter(String v) {
    _skuFilter = v;
    _ensureSelectionInFilter();
    notifyListeners();
  }

  void setDestFilter(String v) {
    _destFilter = v;
    _ensureSelectionInFilter();
    notifyListeners();
  }

  void _ensureSelectionInFilter() {
    final f = filteredChains;
    if (f.isEmpty) {
      _selectedId = null;
      return;
    }
    if (!f.any((c) => c.id == _selectedId)) {
      _selectedId = _pickIllustrative(f);
    }
  }

  /// Timeline horizontal density (pixels per day). Higher = zoomed in.
  double _pixelsPerDay = 120;
  double get pixelsPerDay => _pixelsPerDay;
  static const double minPixelsPerDay = 24; // whole 30 days fits
  static const double maxPixelsPerDay = 600; // hour-level detail

  void setZoom(double v) {
    _pixelsPerDay = v.clamp(minPixelsPerDay, maxPixelsPerDay);
    notifyListeners();
  }

  void zoomBy(double factor) =>
      setZoom((_pixelsPerDay * factor).roundToDouble());

  /// Which view the main pane shows (graph / numerical values / routing tree).
  MainView _view = MainView.graph;
  MainView get view => _view;
  void setView(MainView v) {
    _view = v;
    notifyListeners();
  }

  ColdChain? get selected {
    if (_selectedId == null) return null;
    for (final c in _chains) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  bool _busy = false;
  bool get busy => _busy;

  void select(int? id) {
    _selectedId = id;
    notifyListeners();
  }

  void step(int delta) {
    final f = filteredChains;
    if (f.isEmpty) return;
    final ids = [...f.map((c) => c.id)]..sort();
    final cur = _selectedId == null ? 0 : ids.indexOf(_selectedId!);
    final raw = (cur + delta) % ids.length;
    _selectedId = ids[raw < 0 ? raw + ids.length : raw];
    notifyListeners();
  }

  void setChainCount(int n) => _update(_params.copyWith(chainCount: n));
  void setDeviationRate(double r) => _update(_params.copyWith(deviationRate: r));
  void setQ10(double q) => _update(_params.copyWith(q10: q));
  void setSeed(int s) => _update(_params.copyWith(seed: s));

  void _update(GeneratorParams p) {
    _params = p;
    regenerate();
  }

  void reseed() => _update(_params.copyWith(seed: _params.seed + 1));

  int? _pickIllustrative(List<ColdChain> chains) {
    if (chains.isEmpty) return null;
    int? bestId;
    var bestDrops = -1;
    var bestAbuse = -1.0;
    for (final c in chains) {
      final drops = tierDrops(buildValueTrajectory(c, q10: _params.q10)).length;
      if (drops > bestDrops ||
          (drops == bestDrops && c.totalAbuseDays > bestAbuse)) {
        bestDrops = drops;
        bestAbuse = c.totalAbuseDays;
        bestId = c.id;
      }
    }
    return bestId;
  }

  void regenerate() {
    _busy = true;
    notifyListeners();

    // Train the per-route shelf-life model first (monthly cooltag samples).
    final model = ShelfLifeModel.train(q10: _params.q10);
    final gen = ColdChainGenerator(_params);
    final drafts = gen.generate();
    final tree = DecisionTree(model);
    final chains = tree.evaluateAll(drafts);

    _model = model;
    _chains = chains;
    _stats = PortfolioStats(chains);

    // Keep a product selected for the single-product view: respect the active
    // filters, and default to the most illustrative matching package.
    _ensureSelectionInFilter();

    _busy = false;
    notifyListeners();
  }
}
