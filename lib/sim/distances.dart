import 'package:flutter/material.dart';

import '../models/stage.dart';

/// The legs on which a bag actually moves (everything else is dwell time).
const Set<Stage> kTransitStages = {
  Stage.reeferTruck1,
  Stage.reeferTruck2,
  Stage.reeferTruck3,
  Stage.customerCar,
};

/// Distance (km) covered on each transit leg, per destination. Destinations
/// have distinctive profiles: Rural-East has long line-haul and last-mile legs,
/// Downtown-Core is close-in, etc.
const Map<String, Map<Stage, double>> kLegDistancesKm = {
  'Metro-North': {
    Stage.reeferTruck1: 180,
    Stage.reeferTruck2: 90,
    Stage.reeferTruck3: 22,
    Stage.customerCar: 14,
  },
  'Suburb-West': {
    Stage.reeferTruck1: 210,
    Stage.reeferTruck2: 130,
    Stage.reeferTruck3: 35,
    Stage.customerCar: 26,
  },
  'Downtown-Core': {
    Stage.reeferTruck1: 160,
    Stage.reeferTruck2: 60,
    Stage.reeferTruck3: 9,
    Stage.customerCar: 6,
  },
  'Rural-East': {
    Stage.reeferTruck1: 240,
    Stage.reeferTruck2: 175,
    Stage.reeferTruck3: 70,
    Stage.customerCar: 48,
  },
};

const Map<String, Color> kDestinationColors = {
  'Metro-North': Color(0xFF4FC3F7),
  'Suburb-West': Color(0xFFFFB74D),
  'Downtown-Core': Color(0xFFBA68C8),
  'Rural-East': Color(0xFF81C784),
};

Color destinationColor(String dest) =>
    kDestinationColors[dest] ?? const Color(0xFFB0BEC5);

/// One point on a cumulative distance-over-time curve.
class DistPoint {
  const DistPoint(this.hours, this.km, this.stage);
  final double hours;
  final double km;
  final Stage stage;
}

/// Cumulative distance vs (planned) time for a destination: flat during dwell,
/// rising during each reefer/car leg.
List<DistPoint> distanceCurve(String dest) {
  final legs = kLegDistancesKm[dest] ?? const {};
  final pts = <DistPoint>[DistPoint(0, 0, kColdChainPipeline.first.stage)];
  var clock = 0.0;
  var km = 0.0;
  for (final def in kColdChainPipeline) {
    if (def.stage == Stage.fork) break;
    final start = clock;
    final end = clock + def.plannedHours;
    if (kTransitStages.contains(def.stage)) {
      // ramp: add a start point at current km, then rise to end km.
      pts.add(DistPoint(start, km, def.stage));
      km += legs[def.stage] ?? 0;
      pts.add(DistPoint(end, km, def.stage));
    } else {
      pts.add(DistPoint(end, km, def.stage));
    }
    clock = end;
  }
  return pts;
}

double totalDistanceKm(String dest) {
  final legs = kLegDistancesKm[dest] ?? const {};
  return legs.values.fold(0.0, (a, b) => a + b);
}

/// Total planned hours of the journey (excluding the fork event).
double plannedTotalHours() => kColdChainPipeline
    .where((d) => d.stage != Stage.fork)
    .fold(0.0, (a, d) => a + d.plannedHours);
