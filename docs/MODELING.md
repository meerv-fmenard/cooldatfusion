# CoolDatFusion — Modeling & Decisioning

How CoolDatFusion turns **Cooltag temperature acquisition** into a **trained,
per-route shelf-life model**, and how that model — **fused with real-time reefer
data** — produces **re-routing** and **pricing** decisions for bagged salad on a
~3-week farm-to-fork journey.

This document describes the model as implemented in `lib/sim/` and how it maps to
a real cold-chain deployment. It is intentionally explicit about formulas,
assumptions, and limitations.

---

## 1. The physical system being modeled

A bag of salad travels an 11-node custody chain, held at a **4–8 °C** target
band:

```
Mixing facility → Bagging → Reefer 1 → 3PL DC → Reefer 2 → Grocer DC
   → Reefer 3 → Retail fridge → Customer car (no reefer) → Home fridge → Fork
```

Each node has a *kind* (fridge / reefer / uncontrolled / terminal), a planned
dwell or transit time, and the same 4–8 °C target. Code: `lib/models/stage.dart`
(`kColdChainPipeline`). The total planned envelope is ~16 days, extended to ~3
weeks by a randomized home-storage leg (4–12 days, "until eaten").

Two data streams describe each leg:

- **Cooltag (plan / ideal):** what the temperature *should* look like if every
  link holds the band — tight noise around a 5.0–6.5 °C setpoint.
- **Actual sensor trace:** the real per-fridge / per-reefer readings, which carry
  injected deviations (setpoint error, compressor drift, door-open spikes, and a
  large ambient excursion on the unrefrigerated customer-car leg).

Code: `lib/sim/generator.dart`.

---

## 2. Spoilage kinetics — the unit of degradation

All value loss is expressed in **abuse-days**: excess spoilage accrued *beyond*
what the product would experience at the warm edge of its band. This is the key
modeling choice — it makes a perfectly in-band bag accrue **zero** degradation,
so its value rides flat, and only temperature *excursions* erode it.

### 2.1 Q10 rate law

Microbial spoilage roughly multiplies by a factor `Q10` for every +10 °C. With a
reference temperature `Tref = 4 °C`:

```
rate(T) = Q10 ^ ((T − Tref) / 10)        [shelf-life days consumed per calendar day]
```

Below freezing (`T < −1.5 °C`) we switch to a freeze-damage penalty
`rate(T) = 1 + 0.15·(Tfreeze − T)`. Default `Q10 = 2.5` (user-tunable).

Code: `Q10Model.rateAt` in `lib/sim/q10.dart`.

### 2.2 Abuse (excess) rate

```
penalty(T) = rate(T) − rate(8 °C)     if T > 8 °C   (too warm)
           = rate(T) − 1              if T < −1.5 °C (freeze damage)
           = 0                        if 4 °C ≤ T ≤ 8 °C (in band)
```

`penalty(T) = 0` across the whole target band, which is what makes "held cold ⇒
no value loss" hold exactly.

### 2.3 Integration

Both quantities are integrated over a leg's readings with the trapezoid rule:

```
abuse-days        = Σ ½·(penalty(Tᵢ)+penalty(Tᵢ₊₁)) · Δhoursᵢ / 24
life-days-consumed = Σ ½·(rate(Tᵢ)+rate(Tᵢ₊₁))      · Δhoursᵢ / 24
```

Code: `Q10Model.abuseOver`, `Q10Model.lifeConsumedOver`.

### 2.4 Abuse → value tier

Cumulative abuse maps to one of five tiers (thresholds in abuse-days):

| Cumulative abuse | Tier | Symbol | Value multiplier |
|---|---|---|---|
| `< 1.0` | Top quality | `$$$` | ×1.00 |
| `< 2.5` | Inferior (markdown) | `$$` | ×0.60 |
| `< 4.5` | Urgent reroute / upcycle | `$` | ×0.25 |
| `< 7.0` | Credit + donation | `-$` | ×−0.50 |
| `≥ 7.0` | Waste (disposal + credit) | `--$` | ×−1.00 |

Code: `tierForAbuse` + thresholds in `lib/sim/value_trajectory.dart`;
multipliers in `lib/models/value_tier.dart`.

Because the tier is a pure function of cumulative abuse, the **value-over-time
curve** (Graph view) and the **realized final tier** are guaranteed consistent:
the curve starts at `$$$` and steps down each time cumulative abuse crosses a
threshold.

---

## 3. Cooltag data acquisition → a trained model

This is the offline / periodic learning loop.

### 3.1 Acquisition

In a real deployment, a **Cooltag** is a temperature logger placed in a *sample*
package. The operating assumption modeled here:

> Once per month, one sample package per **SKU × destination** route is shipped
> end-to-end with a Cooltag, producing a full temperature time-series for every
> leg of that route.

Code analog: `ShelfLifeModel.train` generates `months = 12` monthly batches over
`4 SKUs × 4 destinations = 16` routes ⇒ **192 sample journeys**, each at a
"normal operations" deviation level.

### 3.2 Feature extraction per sample

For each sample journey, integrate the Cooltag trace into abuse-days and record:

- `abuseAtShelf` (x): cumulative abuse on arrival at the **retail fridge** (the
  shelf checkpoint, `kRetailShelfStage = groceryFridge`).
- `totalAbuse` (y): cumulative abuse end-to-end (to the fork).
- `cumAbuseByStage`: cumulative abuse as the product *leaves* each stage.

### 3.3 Fitting

Per route, fit an ordinary least-squares line

```
totalAbuse  ≈  a + b · abuseAtShelf
```

and retain `meanAbuseToShelf`, `meanTotalAbuse`, `stdTotalAbuse`, and the
per-stage mean cumulative-abuse profile `meanCumAbuseByStage`. (`r²` is computed
and available for diagnostics.)

Code: `ShelfLifeModel._leastSquares`, `RouteModel`.

### 3.4 Outputs of training

- **Best-before date**, per route, with a one-σ safety margin on route abuse:

  ```
  bestBeforeDays = baseShelfLife − (meanTotalAbuse + stdTotalAbuse)
  ```

- **Forward-projection profile** `meanCumAbuseByStage` and `meanTotalAbuse`,
  used at run time to estimate remaining abuse from any mid-journey point.

The trained model is therefore a compact, per-route artifact: a slope/intercept,
a per-stage expected-abuse curve, and a couple of moments. This is what a real
system would refresh monthly from new Cooltag uploads.

---

## 4. Real-time fusion with reefer data → re-routing

This is the online loop, run as each real package transitions between custody
nodes.

### 4.1 Fusion

As the package moves, its **actual reefer/fridge sensor stream** is integrated
into `abuseSoFar` exactly as in §2.3. At each stage boundary we **fuse** the
measured `abuseSoFar` with the **trained model's expected remaining abuse**:

```
projectedEndAbuse(stage) =
    (stage == shelf)  →  fit.predict(abuseSoFar)              # learned mapping at the checkpoint
    otherwise         →  abuseSoFar + max(0, meanTotalAbuse − meanCumAbuseByStage[stage])
```

So the projection is **measured-so-far + model-expected-rest**: real data for the
legs already traversed, the trained prior for the legs ahead. Code:
`ShelfLifeModel.projectEndAbuse`.

### 4.2 Routing decision per transition

`projectedEndAbuse` is mapped through `tierForAbuse` to a provisional tier, and a
routing action is emitted at every pre-shelf node (where intervention is still
possible):

| Provisional tier | Action |
|---|---|
| `$$$` | continue as planned |
| `$$` | flag for markdown at shelf |
| `$` | reroute to a closer DC, or divert to upcycling (if deep) |
| `-$` | pull from sale → customer credit + food-bank donation |
| `--$` | condemn → disposal |

Each decision records the stage, hours elapsed, `abuseSoFar`, `projectedEndAbuse`,
the action, and a human-readable rationale. Code: `DecisionTree.evaluate` and the
**Decision log** in the inspector.

### 4.3 Value-optimized re-routing (Tree view)

The decision log routes greedily; the **route optimizer** computes the
*value-maximizing* plan and contrasts it with the as-planned route:

- **Intended route:** follow the plan to the planned store; realized outcome is
  the end-to-end tier (which absorbs consumer-side abuse).
- **Optimized route:** choose the higher-value of
  1. **Sell at the retail shelf** — capture quality *at the point of sale*,
     before consumer mishandling: value tier = `tierForAbuse(abuseAtShelf)`.
  2. **Divert early** (from the 3PL onward) to a salvage channel whose value is
     **capped** by the channel: closer-DC markdown (`$$`), upcycling (`$`), or
     food-bank donation (`-$`), gated by the abuse already accrued at the divert
     point.

  The optimizer returns the branch with the highest recovered value and the
  dollars preserved versus the intended route. Code: `lib/sim/route_optimizer.dart`.

This captures a real cold-chain lever: a bag that will be ruined by the consumer
leg is worth more **sold at the shelf** or **diverted to a closer market** than
shipped to a distant store where it arrives unsellable.

---

## 5. Pricing decisions

Pricing is deterministic given the tier and the bag's own value. Each bag carries
a **per-package retail value** drawn in `$5–$10` (stable per package number,
independent of the deviation rate — see §7):

```
realizedValueUsd = tier.multiplier × baseValueUsd
```

- `$$$` → full price, `$$` → 60%, `$` → 25% (salvage), `-$` → −50% (credit +
  donation cost), `--$` → −100% (disposal cost + customer credit, the "double
  negative").

Portfolio economics aggregate per tier and as a net total, with a **value
recovery %** = net ÷ (every bag at full price). Code: `PortfolioStats` in
`lib/sim/decision_tree.dart`; the bottom summary strip and the per-tier cards.

---

## 6. Destination-Specific Shelf-Life Allocation (DS-SLA)

Re-routing in §4 decides *whether/where to pull out*; DS-SLA decides *which
destination best fits the remaining life* at the allocation DC.

- **Allocation point:** the grocer DC (`kAllocationStage`).
- **Remaining life at DC:** `baseShelfLife − lifeConsumedThroughDC`.
- **Per-destination requirement** (days of remaining life needed), scaled by haul
  distance:

  ```
  requirementDays(dest) = 3.0 + totalDistanceKm(dest) / 120
  ```

- **Margin & tier:** `margin = remainingLife − requirement`, mapped through
  day-based bands (`+2 → $$$`, `+0.5 → $$`, `−1.5 → $`, `−4 → -$`, else `--$`).
- **Recommendation:** the highest-value destination; ties broken toward the
  *farthest viable* market (serve the broadest demand without sacrificing value),
  with the dollars preserved vs the intended destination.

So a fresh bag can serve a distant market at full value; a degraded bag is
re-allocated to a nearer market so it still sells. Code: `lib/sim/ds_sla.dart`.

Per-destination travel is modeled explicitly (line-haul + last-mile km per leg)
and visualized as cumulative distance over time. Code: `lib/sim/distances.dart`.

---

## 7. Package identity & reproducibility

Each package has its **own RNG stream** seeded only by `(runSeed, packageIndex)`:

```
rng = Random(seed·1000003 + i·7919 + 17)
```

Identity (SKU, destination, base value, fragility) is drawn first, before any
deviation sampling. Consequence: a package's SKU/destination/value are **stable**
when the deviation rate or package count changes — only the temperature
deviations layered on top move. This is what makes package #N a fixed, comparable
unit across slider settings.

---

## 8. From simulator to deployment

The same structure maps onto a production system:

| Simulator | Real deployment |
|---|---|
| Monthly generated Cooltag samples | Monthly Cooltag logger uploads per SKU×destination |
| `abuseOver` / `lifeConsumedOver` | Stream integration of reefer/fridge telemetry |
| `ShelfLifeModel.train` (per-route LSQ) | Periodic retrain from accumulated Cooltag history |
| `projectEndAbuse` fusion | Online estimate = measured-so-far + learned-prior-rest |
| `DecisionTree` / `route_optimizer` | TMS/OMS re-routing actions at each scan event |
| `tier.multiplier × baseValue` | Dynamic markdown / salvage pricing engine |
| `ds_sla` allocation | DC order-allocation / store-assignment |

---

## 9. Assumptions & limitations

- **Q10 is a simplification.** Real produce respiration/microbial growth is
  multi-factor (gas, humidity, cultivar). Q10 with a band-relative penalty is a
  transparent first-order proxy.
- **One Cooltag sample per route per month** is a small training set; the LSQ fit
  is illustrative. Production would use many loggers and richer features.
- **Distances do not yet feed abuse.** Leg *durations* drive abuse exposure;
  destination *distance* drives DS-SLA requirements and the Distances view but
  not (yet) extra transit-time abuse. Coupling distance → transit time → abuse is
  a natural next step.
- **Consumer-leg abuse is unobservable to the supply chain.** DS-SLA and routing
  optimize at the DC/shelf; they cannot foresee a hot-car or warm-home event —
  which is exactly why "sell at shelf" often dominates in the Tree view.
- **Deviation injection is synthetic.** It is tuned to exercise all five tiers as
  the deviation slider sweeps, not calibrated to a specific carrier's failure
  statistics.

---

## 10. Code map

| Concern | File |
|---|---|
| Stages / pipeline | `lib/models/stage.dart` |
| Readings, tiers, chain | `lib/models/*.dart` |
| Q10 kinetics & abuse | `lib/sim/q10.dart` |
| Synthetic generator | `lib/sim/generator.dart` |
| Trained shelf-life model | `lib/sim/shelf_life_model.dart` |
| Value-over-time curve | `lib/sim/value_trajectory.dart` |
| Routing decision tree | `lib/sim/decision_tree.dart` |
| Value-optimized re-routing | `lib/sim/route_optimizer.dart` |
| Distances | `lib/sim/distances.dart` |
| DS-SLA allocation | `lib/sim/ds_sla.dart` |
| Views | `lib/ui/widgets/*.dart` |
