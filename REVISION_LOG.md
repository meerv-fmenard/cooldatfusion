# Revision Log

A chronological, request-by-request record of how CoolDatFusion was built. Each
entry captures the change requested, what was done, and the key files touched.
For a version-oriented summary see [CHANGELOG.md](CHANGELOG.md); for the modeling
detail see [docs/MODELING.md](docs/MODELING.md).

## R1 — 2026-06-17 — Initial app
**Request:** A macOS Flutter app generating a synthetic farm-to-fork cold-chain
dataset (originally beef, 4–8 °C), overlaying an ideal "cooltag" plan against
actual per-fridge/reefer data, with a shelf-life model + decision tree driving
five product-value tiers.
**Done:** Scaffolded the macOS app; built the 11-stage pipeline, Q10 kinetics,
synthetic generator, a trained per-route shelf-life model, a decision tree, an
interactive landscape chart, inspector, value summary, and CSV/JSON export.
**Files:** `lib/models/*`, `lib/sim/*`, `lib/ui/*`, `lib/io/exporter.dart`,
`macos/Runner/*` (entitlements, window size).

## R2 — 2026-06-17 — Reframe as single-product value-over-time
**Request:** One product; Y axis = five value-tiers, X = time; a flat `$$$` line
when held 4–8 °C that steps down as temperature swings accrue; per-element
temperature lines below.
**Done:** Replaced the landscape hero with the **Graph** view; introduced the
**abuse-day** model so value is flat in-band and steps down only on excursions;
unified the final tier and the value curve on cumulative abuse.
**Files:** `lib/sim/value_trajectory.dart`, `lib/sim/q10.dart` (penalty rate),
`lib/ui/widgets/product_timeline.dart`, generator/decision-tree refactor.

## R3 — 2026-06-17/18 — Product pivot
**Request:** Bags of lettuce/salad instead of beef; mixing facility instead of
slaughterhouse; 3-week total timeline.
**Done:** Renamed SKUs to bagged salads, first node → **salad mixing facility**,
stretched stage durations and randomized the home-storage leg to a ~3-week
envelope.
**Files:** `lib/models/stage.dart`, `lib/sim/generator.dart`.

## R4 — 2026-06-18 — Scrollable timeline
**Request:** Horizontally scroll the main graph; timeline at 6×/day over 30 days.
**Done:** Fixed 30-day axis, minor ticks every 4 h (6/day) with day markers, a
**frozen Y axis**, and a horizontal scrollbar.
**Files:** `lib/ui/widgets/product_timeline.dart`.

## R5 — 2026-06-18 — Rename, zoom, and a Values view
**Request:** Add timeline zoom; rename the app to "produce value cold chain
simulator"; add a button to show numerical values instead of the graphs.
**Done:** Added a **zoom** slider; renamed app (window title + toolbar); added the
**Values** numerical table and a Graph/Values switcher.
**Files:** `lib/ui/app.dart`, `lib/ui/home_page.dart`,
`lib/ui/widgets/chain_values_table.dart`, `lib/state/simulation_controller.dart`.

## R6 — 2026-06-18 — Per-package pricing
**Request:** Value per package, $5–$10 per bag.
**Done:** Each bag carries its own retail value; tiers became multipliers of that
value; portfolio totals, inspector, table, and exports now report real
per-package dollars.
**Files:** `lib/models/value_tier.dart` (multipliers), `lib/models/cold_chain.dart`,
`lib/sim/generator.dart`, `lib/sim/decision_tree.dart` (`PortfolioStats`),
`lib/io/exporter.dart`.

## R7 — 2026-06-18 — Fix package↔SKU desync
**Request:** Why does sliding the deviation rate change a package's SKU? It should
be 1:1 with the package number.
**Done:** Root cause — SKU/destination were drawn from a shared RNG that the
deviation sampler also consumed, desyncing identity. Gave each package its own RNG
seeded by `(seed, index)`; identity drawn before deviations → stable across
deviation-rate and package-count changes. Added a stability test.
**Files:** `lib/sim/generator.dart`, `test/`.

## R8 — 2026-06-18 — Filters
**Request:** Dropdown filters by destination and by SKU near the "Bag of salad"
label.
**Done:** Added SKU + Destination filters; the picker and prev/next cycle only
matching packages; converted the picker to a `Wrap` to prevent toolbar overflow.
**Files:** `lib/state/simulation_controller.dart`, `lib/ui/home_page.dart`.

## R9 — 2026-06-18 — Tree view (intended vs optimized)
**Request:** Make it a triple switcher (Graph, Values, Tree); the Tree shows the
intended routing tree vs a revised tree that maximizes value.
**Done:** Added the **Tree** view and route optimizer: intended route vs a
value-optimized route (sell at shelf, or divert early to closer DC / upcycler /
food bank), with dollars recovered.
**Files:** `lib/sim/route_optimizer.dart`, `lib/ui/widgets/chain_route_tree.dart`,
switcher → `MainView` enum.

## R10 — 2026-06-18 — Distances view
**Request:** A "Distances" view of distance travelled over time, per destination.
**Done:** Added per-destination leg distances (line-haul + last-mile) and the
**Distances** view: cumulative distance over time, one line per destination,
selected destination highlighted.
**Files:** `lib/sim/distances.dart`, `lib/ui/widgets/distances_view.dart`.

## R11 — 2026-06-18 — DS-SLA view
**Request:** Packages shouldn't be locked 1:1 to a destination — recompute the
likely destination that preserves value; add a DS-SLA view.
**Done:** Added **Destination-Specific Shelf-Life Allocation**: remaining life at
the DC vs each destination's distance-scaled requirement → recommended
value-preserving destination, with dollars preserved.
**Files:** `lib/sim/ds_sla.dart`, `lib/ui/widgets/ds_sla_view.dart`.

## R12 — 2026-06-18 — Web app + full screen + ship
**Request:** Create a Vercel site that is a 1:1 high-resolution web app,
equivalent to the macOS app, required to run full screen.
**Done:** Added the web target (same Flutter/CanvasKit codebase), a full-screen
gate (web-only via conditional import), built `build/web`, and deployed to Vercel
with SPA rewrites. Fixed the conditional-import token so the web fullscreen code
actually compiles into the bundle.
**Files:** `lib/platform/*`, `lib/ui/fullscreen_gate.dart`, `web/index.html`,
`build/web/vercel.json`. Live: https://cooldatfusion.vercel.app

## R13 — 2026-06-18 — Public GitHub repo
**Request:** Create a new public repo on GitHub.
**Done:** Initialized git, restored a proper Flutter `.gitignore` (build artifacts
excluded), wrote a real README, committed, and created/pushed the public repo.
**Repo:** https://github.com/meerv-fmenard/cooldatfusion

## R14 — 2026-06-19 — Documentation
**Request:** Add a CHANGELOG, a Revision Log, and a detailed modeling document.
**Done:** Added `CHANGELOG.md`, this `REVISION_LOG.md`, and `docs/MODELING.md`
covering Cooltag acquisition → trained model → real-time reefer fusion →
re-routing & pricing decisions.
