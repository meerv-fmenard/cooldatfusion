import 'package:flutter/material.dart';

import 'fullscreen_gate.dart';
import 'home_page.dart';

class CoolDatFusionApp extends StatelessWidget {
  const CoolDatFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'CoolDatFusion — Produce Value Cold Chain Simulator',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E1116),
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFF4FC3F7),
          secondary: const Color(0xFF7E9CFF),
          surface: const Color(0xFF161B22),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF161B22),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        sliderTheme: base.sliderTheme.copyWith(
          trackHeight: 3,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        textTheme: base.textTheme.apply(fontFamily: 'SF Pro Text'),
      ),
      home: const FullscreenGate(child: HomePage()),
    );
  }
}
