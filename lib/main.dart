import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/simulation_controller.dart';
import 'ui/app.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SimulationController(),
      child: const CoolDatFusionApp(),
    ),
  );
}
