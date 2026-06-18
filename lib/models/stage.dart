import 'package:flutter/material.dart';

/// The kind of custody node in the cold chain. Determines how tightly
/// temperature is controlled and how it can fail.
enum StageKind {
  fridge, // a stationary refrigerated holding point
  reefer, // a refrigerated truck (transit, but controlled)
  uncontrolled, // transit with NO active refrigeration (customer car)
  terminal, // the final consumption event (the "fork")
}

/// One node in the farm-to-fork bagged-salad cold chain.
enum Stage {
  mixingFacility,
  packer,
  reeferTruck1,
  logistics3PL,
  reeferTruck2,
  grocerDC,
  reeferTruck3,
  groceryFridge,
  customerCar,
  homeFridge,
  fork,
}

/// Static metadata describing how each [Stage] behaves.
class StageDef {
  const StageDef({
    required this.stage,
    required this.label,
    required this.shortLabel,
    required this.kind,
    required this.plannedHours,
    this.targetMin = 4.0,
    this.targetMax = 8.0,
  });

  final Stage stage;
  final String label;
  final String shortLabel;
  final StageKind kind;

  /// Planned dwell/transit time at this node, in hours.
  final double plannedHours;

  /// The acceptable temperature band for bagged salads (°C).
  final double targetMin;
  final double targetMax;

  bool get isControlled =>
      kind == StageKind.fridge || kind == StageKind.reefer;
}

/// The canonical, ordered 11-stage bagged-salad cold chain (field → fork),
/// spanning roughly three weeks end-to-end.
const List<StageDef> kColdChainPipeline = <StageDef>[
  StageDef(
    stage: Stage.mixingFacility,
    label: 'Salad mixing facility (inbound greens)',
    shortLabel: 'Mixing',
    kind: StageKind.fridge,
    plannedHours: 12,
  ),
  StageDef(
    stage: Stage.packer,
    label: 'Bagging / packing line',
    shortLabel: 'Bagging',
    kind: StageKind.fridge,
    plannedHours: 16,
  ),
  StageDef(
    stage: Stage.reeferTruck1,
    label: 'Reefer truck → 3PL',
    shortLabel: 'Reefer 1',
    kind: StageKind.reefer,
    plannedHours: 10,
  ),
  StageDef(
    stage: Stage.logistics3PL,
    label: '3PL logistics center',
    shortLabel: '3PL',
    kind: StageKind.fridge,
    plannedHours: 40,
  ),
  StageDef(
    stage: Stage.reeferTruck2,
    label: 'Reefer truck → grocer DC',
    shortLabel: 'Reefer 2',
    kind: StageKind.reefer,
    plannedHours: 8,
  ),
  StageDef(
    stage: Stage.grocerDC,
    label: 'Grocer distribution center',
    shortLabel: 'Grocer DC',
    kind: StageKind.fridge,
    plannedHours: 30,
  ),
  StageDef(
    stage: Stage.reeferTruck3,
    label: 'Reefer truck → store',
    shortLabel: 'Reefer 3',
    kind: StageKind.reefer,
    plannedHours: 6,
  ),
  StageDef(
    stage: Stage.groceryFridge,
    label: 'Grocery retail fridge',
    shortLabel: 'Retail',
    kind: StageKind.fridge,
    plannedHours: 90,
  ),
  StageDef(
    stage: Stage.customerCar,
    label: 'Customer car (no reefer)',
    shortLabel: 'Car',
    kind: StageKind.uncontrolled,
    plannedHours: 1.5,
  ),
  StageDef(
    stage: Stage.homeFridge,
    label: 'Home fridge (until eaten)',
    shortLabel: 'Home',
    kind: StageKind.fridge,
    plannedHours: 168,
  ),
  StageDef(
    stage: Stage.fork,
    label: 'Fork — consumption',
    shortLabel: 'Fork',
    kind: StageKind.terminal,
    plannedHours: 0,
  ),
];

StageDef stageDefOf(Stage s) =>
    kColdChainPipeline.firstWhere((d) => d.stage == s);

extension StageKindColor on StageKind {
  Color get accent {
    switch (this) {
      case StageKind.fridge:
        return const Color(0xFF4FC3F7);
      case StageKind.reefer:
        return const Color(0xFF7E9CFF);
      case StageKind.uncontrolled:
        return const Color(0xFFFFB74D);
      case StageKind.terminal:
        return const Color(0xFFB0BEC5);
    }
  }
}

/// A distinct color per cold-chain element so each one's temperature trace and
/// stage marker reads as a separate line in the timeline.
const List<Color> kStagePalette = <Color>[
  Color(0xFF66BB6A), // mixing
  Color(0xFF26C6DA), // bagging
  Color(0xFF7E9CFF), // reefer 1
  Color(0xFF42A5F5), // 3PL
  Color(0xFF9575CD), // reefer 2
  Color(0xFF4DB6AC), // grocer DC
  Color(0xFF5C6BC0), // reefer 3
  Color(0xFF29B6F6), // retail
  Color(0xFFFFB74D), // car (uncontrolled)
  Color(0xFF26A69A), // home
  Color(0xFFB0BEC5), // fork
];

Color stageColor(Stage s) {
  final i = Stage.values.indexOf(s);
  return kStagePalette[i % kStagePalette.length];
}
