# CoolDatFusion — Produce Value Cold Chain Simulator

A Flutter app (macOS desktop **and** web, from one codebase) that generates a
synthetic **farm-to-fork cold chain** dataset for **bagged salads** and shows how
temperature integrity drives product value over a ~3-week journey.

**Live web app:** https://cooldatfusion.vercel.app (designed to run full screen)

## What it does

For each bag of salad it simulates the 11-stage journey — salad **mixing
facility** → bagging → reefer truck → 3PL → reefer → grocer DC → reefer → retail
fridge → customer car (uncontrolled) → home fridge → fork — overlaying the ideal
"cooltag" plan against the actual per-fridge/per-reefer sensor trace, then routes
each package to one of five value tiers (`$$$ → --$`).

Degradation is driven by **abuse-days** (excess spoilage beyond the 4–8 °C band,
a Q10 kinetics integral), so a perfectly-held bag rides flat at `$$$` and only
steps down as temperature excursions accumulate. A per-route shelf-life model
(least-squares fit on monthly cooltag samples) feeds a decision tree that sets
best-before dates and re-routes in real time. Each bag has its own retail value
($5–$10), stable per package number and independent of the deviation rate.

## Views (per package)

- **Graph** — value-over-time step line (Y = 5 tiers, X = time) above a
  temperature time-series with each cold-chain element as its own line;
  horizontally scrollable & zoomable, ticked 6×/day over 30 days.
- **Values** — the full numerical table behind the graphs.
- **Tree** — intended routing vs a value-optimized route that diverts early
  (closer DC / upcycler / food bank) to preserve value.
- **Distances** — cumulative distance travelled over time, one line per
  destination.
- **DS-SLA** — Destination-Specific Shelf-Life Allocation: evaluates the bag
  against every destination and recommends the value-preserving one.

Interactive controls: package count, deviation rate, Q10, SKU/destination
filters, regenerate, and CSV/JSON export of both datasets.

## Run

```bash
flutter pub get

flutter run -d macos      # macOS desktop
flutter run -d chrome     # web

flutter build macos --release
flutter build web --release   # output in build/web/
flutter test
```

The web build is deployed as static files to Vercel (`build/web` + a
`vercel.json` with SPA rewrites). The web build requires full screen via the
browser Fullscreen API; the desktop build runs in its own window.

## Layout

- `lib/models/` — domain (stages, readings, value tiers, cold chain)
- `lib/sim/` — Q10 kinetics, generator, shelf-life model, decision tree, route
  optimizer, distances, DS-SLA
- `lib/ui/` — app shell, home page, and the five views
- `lib/platform/` — cross-platform fullscreen (web Fullscreen API + native stub)
