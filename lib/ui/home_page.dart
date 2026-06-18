import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../io/exporter.dart';
import '../models/value_tier.dart';
import '../state/simulation_controller.dart';
import 'widgets/chain_inspector.dart';
import 'widgets/chain_route_tree.dart';
import 'widgets/chain_values_table.dart';
import 'widgets/distances_view.dart';
import 'widgets/ds_sla_view.dart';
import 'widgets/legend.dart';
import 'widgets/product_timeline.dart';
import 'widgets/value_summary.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = context.watch<SimulationController>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(sim: sim),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: hero landscape + legend.
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProductPicker(sim: sim),
                          const SizedBox(height: 6),
                          Expanded(
                            child: sim.selected == null
                                ? const Center(
                                    child: Text('No product generated',
                                        style:
                                            TextStyle(color: Colors.white38)))
                                : switch (sim.view) {
                                    MainView.table => ChainValuesTable(
                                        chain: sim.selected!,
                                        q10: sim.params.q10,
                                      ),
                                    MainView.tree => ChainRouteTree(
                                        chain: sim.selected!,
                                        q10: sim.params.q10,
                                      ),
                                    MainView.distances => DistancesView(
                                        chain: sim.selected!,
                                      ),
                                    MainView.dsSla => DsSlaView(
                                        chain: sim.selected!,
                                      ),
                                    MainView.graph => ProductTimeline(
                                        chain: sim.selected!,
                                        q10: sim.params.q10,
                                        pixelsPerDay: sim.pixelsPerDay,
                                      ),
                                  },
                          ),
                          const SizedBox(height: 6),
                          const Legend(),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Colors.white12),
                  // Right: inspector.
                  SizedBox(
                    width: 420,
                    child: ChainInspector(chain: sim.selected),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: ValueSummary(stats: sim.stats),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.sim});
  final SimulationController sim;

  @override
  Widget build(BuildContext context) {
    final c = sim.selected;
    final ids = [...sim.filteredChains.map((e) => e.id)]..sort();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        const Text('Bag of salad',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        _filterDropdown(
          label: 'SKU',
          value: sim.skuFilter,
          options: ['All', ...sim.skus],
          onChanged: (v) => sim.setSkuFilter(v ?? 'All'),
        ),
        _filterDropdown(
          label: 'Dest',
          value: sim.destFilter,
          options: ['All', ...sim.destinations],
          onChanged: (v) => sim.setDestFilter(v ?? 'All'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous package',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left),
              onPressed: ids.isEmpty ? null : () => sim.step(-1),
            ),
            DropdownButton<int>(
              value: ids.contains(c?.id) ? c?.id : null,
              underline: const SizedBox.shrink(),
              dropdownColor: const Color(0xFF1B2230),
              hint: const Text('—'),
              items: [
                for (final id in ids)
                  DropdownMenuItem(value: id, child: Text('Package #$id')),
              ],
              onChanged: (v) => sim.select(v),
            ),
            IconButton(
              tooltip: 'Next package',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right),
              onPressed: ids.isEmpty ? null : () => sim.step(1),
            ),
          ],
        ),
        if (c != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.finalTier.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.finalTier.color),
            ),
            child: Text(
                '\$${c.baseValueUsd.toStringAsFixed(2)} bag  ·  ${c.finalTier.symbol}',
                style: TextStyle(
                    fontSize: 12,
                    color: c.finalTier.color,
                    fontWeight: FontWeight.w600)),
          )
        else
          Text('${ids.length} packages match',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        if (sim.view == MainView.graph) _zoom(sim),
        _viewToggle(sim),
      ],
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    String show(String s) => s.startsWith('SALAD-') ? s.substring(6) : s;
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          DropdownButton<String>(
            value: value,
            isDense: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF1B2230),
            style: const TextStyle(fontSize: 12, color: Colors.white),
            items: [
              for (final o in options)
                DropdownMenuItem(value: o, child: Text(show(o))),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _zoom(SimulationController sim) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.zoom_out_map, size: 15, color: Colors.white38),
        SizedBox(
          width: 104,
          child: Slider(
            value: sim.pixelsPerDay,
            min: SimulationController.minPixelsPerDay,
            max: SimulationController.maxPixelsPerDay,
            onChanged: sim.setZoom,
          ),
        ),
      ],
    );
  }

  Widget _viewToggle(SimulationController sim) {
    return SegmentedButton<MainView>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
            value: MainView.graph,
            icon: Icon(Icons.show_chart, size: 16),
            label: Text('Graph')),
        ButtonSegment(
            value: MainView.table,
            icon: Icon(Icons.table_rows, size: 16),
            label: Text('Values')),
        ButtonSegment(
            value: MainView.tree,
            icon: Icon(Icons.account_tree, size: 16),
            label: Text('Tree')),
        ButtonSegment(
            value: MainView.distances,
            icon: Icon(Icons.route, size: 16),
            label: Text('Distances')),
        ButtonSegment(
            value: MainView.dsSla,
            icon: Icon(Icons.hub, size: 16),
            label: Text('DS-SLA')),
      ],
      selected: {sim.view},
      onSelectionChanged: (s) => sim.setView(s.first),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.sim});
  final SimulationController sim;

  @override
  Widget build(BuildContext context) {
    final p = sim.params;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF11161F),
      child: Row(
        children: [
          const Icon(Icons.ac_unit, color: Color(0xFF4FC3F7), size: 22),
          const SizedBox(width: 8),
          const Text('CoolDatFusion',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          const Text('produce value cold-chain simulator',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 24),
          _slider(
            label: 'Packages',
            value: p.chainCount.toDouble(),
            min: 8,
            max: 160,
            divisions: 152,
            display: '${p.chainCount}',
            onChanged: (v) => sim.setChainCount(v.round()),
          ),
          _slider(
            label: 'Deviation rate',
            value: p.deviationRate,
            min: 0,
            max: 1,
            divisions: 100,
            display: '${(p.deviationRate * 100).round()}%',
            onChanged: sim.setDeviationRate,
          ),
          _slider(
            label: 'Q10',
            value: p.q10,
            min: 1.5,
            max: 4,
            divisions: 25,
            display: p.q10.toStringAsFixed(1),
            onChanged: sim.setQ10,
          ),
          const Spacer(),
          if (sim.model != null)
            Tooltip(
              message:
                  'Shelf-life model trained on ${sim.model!.sampleCount} monthly '
                  'cooltag samples across ${sim.model!.routes.length} SKU×destination routes',
              child: Row(
                children: [
                  const Icon(Icons.model_training,
                      size: 16, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text('${sim.model!.routes.length} routes trained',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'New random seed',
            icon: const Icon(Icons.casino_outlined),
            onPressed: sim.reseed,
          ),
          FilledButton.icon(
            onPressed: sim.regenerate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Regenerate'),
          ),
          const SizedBox(width: 8),
          _ExportMenu(sim: sim),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(width: 6),
            Text(display,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(
            width: 150,
            height: 24,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportMenu extends StatelessWidget {
  const _ExportMenu({required this.sim});
  final SimulationController sim;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Export datasets',
      icon: const Icon(Icons.download),
      onSelected: (v) async {
        String? path;
        switch (v) {
          case 'json':
            path = await Exporter.exportJson(sim.chains);
            break;
          case 'readings':
            path = await Exporter.exportReadingsCsv(sim.chains);
            break;
          case 'summary':
            path = await Exporter.exportSummaryCsv(sim.chains);
            break;
        }
        if (context.mounted && path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to $path')),
          );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
            value: 'json', child: Text('Export full JSON (cooltag + actual)')),
        PopupMenuItem(
            value: 'readings', child: Text('Export readings CSV (long)')),
        PopupMenuItem(
            value: 'summary', child: Text('Export per-chain summary CSV')),
      ],
    );
  }
}
