# Changelog

All notable changes to CoolDatFusion are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).
Version numbers below reconstruct the build's evolution; tag them in git as you
see fit.

## [Unreleased]

### Added
- `CHANGELOG.md`, `REVISION_LOG.md`, and `docs/MODELING.md` (modeling &
  decisioning reference).

## [1.0.0] — 2026-06-18 — Web parity, full-screen, shipped

### Added
- **Web build (1:1 with macOS)** from the same Flutter/CanvasKit codebase;
  high-DPI / high-resolution rendering.
- **Full-screen gate** (`lib/ui/fullscreen_gate.dart`, `lib/platform/*`): the web
  build is required to run full screen via the browser Fullscreen API; a
  conditional-import stub makes it a no-op on macOS.
- Vercel deployment of `build/web` with SPA rewrites → https://cooldatfusion.vercel.app
- Public GitHub repository.

### Fixed
- Conditional-import token switched from `dart.library.js_interop` to
  `dart.library.html` so the web fullscreen implementation actually compiles into
  the web bundle (the gate was previously bypassed).

## [0.9.0] — 2026-06-18 — DS-SLA view

### Added
- **DS-SLA (Destination-Specific Shelf-Life Allocation)** view and model
  (`lib/sim/ds_sla.dart`): evaluates each package against *all* destinations using
  remaining shelf life at the DC vs a distance-scaled requirement, and recommends
  the value-preserving destination (with dollars preserved).

### Changed
- The package is no longer conceptually locked 1:1 to its intended destination;
  DS-SLA recomputes the optimal destination.

## [0.8.0] — 2026-06-18 — Distances view

### Added
- **Distances** view (`lib/ui/widgets/distances_view.dart`,
  `lib/sim/distances.dart`): cumulative distance over time, one line per
  destination, with per-destination line-haul + last-mile leg distances and the
  selected package's destination highlighted.

## [0.7.0] — 2026-06-18 — Routing tree (intended vs optimized)

### Added
- **Tree** view (`lib/ui/widgets/chain_route_tree.dart`,
  `lib/sim/route_optimizer.dart`): intended route vs a value-optimized route that
  sells at the shelf or diverts early (closer DC / upcycler / food bank) to
  preserve value; shows dollars recovered.
- Switcher extended to Graph / Values / Tree.

## [0.6.0] — 2026-06-18 — Filters

### Added
- **SKU** and **Destination** dropdown filters by the package picker; the picker
  and prev/next now cycle only matching packages. Picker converted to a `Wrap` to
  avoid toolbar overflow.

## [0.5.0] — 2026-06-18 — Per-package value & deterministic identity

### Added
- **Per-package retail value** ($5–$10 a bag); tiers recover a fraction of each
  bag's own value (`$$$`×1.0, `$$`×0.6, `$`×0.25, `-$`×−0.5, `--$`×−1.0).
  Portfolio totals, inspector, table, and CSV/JSON now report real per-package
  dollars.

### Fixed
- **Package identity desync:** SKU/destination were drawn from a shared RNG that
  deviation sampling also consumed, so changing the deviation rate reassigned
  SKUs. Each package now has its own RNG seeded by `(seed, index)`, so identity is
  stable across deviation-rate and package-count changes.

## [0.4.0] — 2026-06-18 — Scroll, zoom, values table, rename

### Added
- **Horizontal scrolling** timeline on a fixed 30-day axis ticked 6×/day, with a
  frozen Y axis.
- **Zoom** slider for the timeline (px/day).
- **Values** view: the full numerical table behind the graphs.
- Graph / Values switcher.

### Changed
- Renamed "beef cold chain simulator" → **"produce value cold-chain simulator"**.
- "Chains" slider relabeled **"Packages"** (each cold chain = one package).

## [0.3.0] — 2026-06-18 — Pivot to bagged salad

### Changed
- Product changed from beef to **bagged salads** (Spring Mix, Romaine, Caesar
  Kit, Baby Spinach).
- First node changed from slaughterhouse to a **salad mixing facility**.
- Journey stretched to a **~3-week** farm-to-fork envelope (randomized
  home-storage leg).

## [0.2.0] — 2026-06-17 — Single-product value-over-time

### Added
- **Graph** hero view: value over time (Y = five value tiers, X = time) above a
  temperature time-series with each cold-chain element as its own line.
- **Abuse-day** value model (`lib/sim/value_trajectory.dart`): value is flat at
  `$$$` while in-band and steps down only as temperature excursions accrue.

### Changed
- Tier outcome and routing unified on cumulative abuse-days so the curve and the
  final tier are always consistent.

## [0.1.0] — 2026-06-17 — Initial macOS simulator

### Added
- macOS Flutter app scaffolding.
- 11-stage cold-chain pipeline, Q10 spoilage kinetics, synthetic generator
  (cooltag plan + actual sensor trace), trained per-route shelf-life model, and a
  decision tree mapping outcomes to five value tiers.
- Interactive controls (count, deviation rate, Q10, regenerate, seed) and
  CSV/JSON export; per-chain inspector.
