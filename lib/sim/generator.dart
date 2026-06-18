import 'dart:math' as math;

import '../models/stage.dart';
import '../models/temperature_reading.dart';
import 'q10.dart';

/// Tunable inputs for one generation run.
class GeneratorParams {
  const GeneratorParams({
    this.chainCount = 48,
    this.deviationRate = 0.35,
    this.seed = 7,
    this.q10 = 2.5,
  });

  final int chainCount;

  /// 0 = a flawless cold chain everywhere; 1 = frequent, severe excursions.
  final double deviationRate;
  final int seed;
  final double q10;

  GeneratorParams copyWith({
    int? chainCount,
    double? deviationRate,
    int? seed,
    double? q10,
  }) =>
      GeneratorParams(
        chainCount: chainCount ?? this.chainCount,
        deviationRate: deviationRate ?? this.deviationRate,
        seed: seed ?? this.seed,
        q10: q10 ?? this.q10,
      );
}

/// A package's raw journey before the model/decision-tree pass.
class StageDraft {
  StageDraft({
    required this.stage,
    required this.startHours,
    required this.endHours,
    required this.cooltag,
    required this.actual,
    required this.lifeConsumedDays,
    required this.plannedLifeConsumedDays,
    required this.abuseDays,
  });

  final Stage stage;
  final double startHours;
  final double endHours;
  final List<TemperatureReading> cooltag;
  final List<TemperatureReading> actual;
  final double lifeConsumedDays;
  final double plannedLifeConsumedDays;
  final double abuseDays;
}

class ChainDraft {
  ChainDraft({
    required this.id,
    required this.sku,
    required this.destination,
    required this.baseShelfLifeDays,
    required this.baseValueUsd,
    required this.segments,
  });

  final int id;
  final String sku;
  final String destination;
  final double baseShelfLifeDays;
  final double baseValueUsd;
  final List<StageDraft> segments;
}

/// Bagged-salad SKUs with their pristine shelf life (days) when packed.
const Map<String, double> kSkuBaseLifeDays = <String, double>{
  'SALAD-SPRING-MIX': 15,
  'SALAD-ROMAINE': 18,
  'SALAD-CAESAR-KIT': 14,
  'SALAD-BABY-SPINACH': 13,
};

const List<String> kDestinations = <String>[
  'Metro-North',
  'Suburb-West',
  'Downtown-Core',
  'Rural-East',
];

/// Builds synthetic cold-chain journeys: an ideal "cooltag" plan plus a
/// realistic per-fridge/per-reefer "actual" sensor trace with injected
/// deviations whose frequency and severity scale with [deviationRate].
class ColdChainGenerator {
  ColdChainGenerator(this.params) {
    _q10 = Q10Model(q10: params.q10);
  }

  final GeneratorParams params;
  late final Q10Model _q10;

  static double _gauss(math.Random rng) {
    // Box–Muller.
    final u1 = 1.0 - rng.nextDouble();
    final u2 = 1.0 - rng.nextDouble();
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  List<ChainDraft> generate() {
    final skus = kSkuBaseLifeDays.keys.toList();
    return List<ChainDraft>.generate(params.chainCount, (i) {
      // Each package gets its OWN RNG stream seeded only by the run seed and the
      // package index. This keeps a package's identity (SKU, destination) — and
      // its 1:1 mapping to its number — stable when the deviation rate or chain
      // count changes; only the temperature deviations on top of it vary.
      final rng = math.Random(params.seed * 1000003 + i * 7919 + 17);
      final sku = skus[rng.nextInt(skus.length)];
      final destination = kDestinations[rng.nextInt(kDestinations.length)];
      // Per-bag retail value: salad runs $5–$10 a bag.
      final baseValue = 5.0 + rng.nextDouble() * 5.0;
      // Per-chain fragility: some packages just get a rough ride end-to-end.
      final fragility = math.max(0.0, _gauss(rng) * 0.4 + 0.5);
      return _buildChain(i, sku, destination, kSkuBaseLifeDays[sku]!, baseValue,
          fragility, rng);
    });
  }

  ChainDraft _buildChain(
    int id,
    String sku,
    String destination,
    double baseLife,
    double baseValue,
    double fragility,
    math.Random rng,
  ) {
    final segments = <StageDraft>[];
    var clock = 0.0;
    for (final def in kColdChainPipeline) {
      if (def.kind == StageKind.terminal) {
        // The fork is an instantaneous event; record a single point.
        final t = clock;
        final lastTemp = segments.isEmpty
            ? 6.0
            : (segments.last.actual.isEmpty ? 6.0 : segments.last.actual.last.tempC);
        segments.add(StageDraft(
          stage: def.stage,
          startHours: t,
          endHours: t,
          cooltag: [
            TemperatureReading(
                hoursElapsed: t,
                tempC: 6,
                stage: def.stage,
                source: ReadingSource.cooltag),
          ],
          actual: [
            TemperatureReading(
                hoursElapsed: t,
                tempC: lastTemp,
                stage: def.stage,
                source: ReadingSource.actualSensor),
          ],
          lifeConsumedDays: 0,
          plannedLifeConsumedDays: 0,
          abuseDays: 0,
        ));
        break;
      }

      // The consumer eats the beef at some point during the home-storage week,
      // not necessarily after the full 7 days — randomise when the fork happens.
      final hoursOverride = def.stage == Stage.homeFridge
          ? 96 + rng.nextDouble() * 192 // 4–12 days at home (≈3-week envelope)
          : def.plannedHours;
      final seg = _buildSegment(def, clock, fragility, hoursOverride, rng);
      segments.add(seg);
      clock = seg.endHours;
    }
    return ChainDraft(
      id: id,
      sku: sku,
      destination: destination,
      baseShelfLifeDays: baseLife,
      baseValueUsd: baseValue,
      segments: segments,
    );
  }

  StageDraft _buildSegment(StageDef def, double startHours, double fragility,
      double hours, math.Random rng) {
    final end = startHours + hours;

    // Sample cadence: enough points to show shape, capped for big legs.
    final samples = math.max(3, math.min(20, (hours / 2).ceil() + 1));
    final step = hours / (samples - 1);

    // ---- Cooltag (planned/ideal): tight, comfortably inside 4–8 °C. ----
    final setpoint = 5.0 + rng.nextDouble() * 1.5; // 5.0–6.5
    final cooltag = <TemperatureReading>[];
    for (var i = 0; i < samples; i++) {
      final t = startHours + step * i;
      final temp = (setpoint + _gauss(rng) * 0.25).clamp(4.0, 8.0);
      cooltag.add(TemperatureReading(
        hoursElapsed: t,
        tempC: temp,
        stage: def.stage,
        source: ReadingSource.cooltag,
      ));
    }

    // ---- Actual: start from plan, then inject leg-specific deviations. ----
    final actual =
        _actualTrace(def, startHours, step, samples, setpoint, fragility, rng);

    return StageDraft(
      stage: def.stage,
      startHours: startHours,
      endHours: end,
      cooltag: cooltag,
      actual: actual,
      lifeConsumedDays: _q10.lifeConsumedOver(actual),
      plannedLifeConsumedDays: _q10.lifeConsumedOver(cooltag),
      abuseDays: _q10.abuseOver(actual),
    );
  }

  List<TemperatureReading> _actualTrace(
    StageDef def,
    double startHours,
    double step,
    int samples,
    double setpoint,
    double fragility,
    math.Random rng,
  ) {
    final dev = params.deviationRate;
    final out = <TemperatureReading>[];

    // Whole-leg setpoint error (mis-set reefer / warm fridge zone).
    final setpointError =
        (rng.nextDouble() < dev * 0.6) ? _gauss(rng).abs() * 4.0 * dev : 0.0;

    // Compressor drift: a slow ramp over the leg.
    final driftPerHour =
        (rng.nextDouble() < dev * 0.5) ? _gauss(rng).abs() * 0.25 * dev : 0.0;

    // Transient door-open / loading spikes.
    final spikeAt = <int, double>{};
    final spikeChances = (samples * dev * 0.4).round();
    for (var k = 0; k < spikeChances; k++) {
      if (rng.nextDouble() < dev) {
        final idx = rng.nextInt(samples);
        spikeAt[idx] =
            (spikeAt[idx] ?? 0) + (2 + rng.nextDouble() * 6) * (0.5 + dev);
      }
    }

    for (var i = 0; i < samples; i++) {
      final t = startHours + step * i;
      double temp;

      if (def.kind == StageKind.uncontrolled) {
        // Customer car: no refrigeration. Temperature climbs toward a warm
        // cabin ambient. This leg is the classic silent killer of shelf life.
        final ambient = 17.0 + rng.nextDouble() * 14.0; // 17–31 °C cabin
        final frac = samples == 1 ? 1.0 : i / (samples - 1);
        temp = setpoint + (ambient - setpoint) * frac * (0.6 + 0.4 * fragility);
      } else {
        temp = setpoint + setpointError + driftPerHour * (step * i);
        temp += _gauss(rng) * 0.35;
        if (spikeAt.containsKey(i)) temp += spikeAt[i]! * fragility;
      }

      temp = temp.clamp(-4.0, 38.0);
      out.add(TemperatureReading(
        hoursElapsed: t,
        tempC: temp,
        stage: def.stage,
        source: ReadingSource.actualSensor,
      ));
    }
    return out;
  }
}
