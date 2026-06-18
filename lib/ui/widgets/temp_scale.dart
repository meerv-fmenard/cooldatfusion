import 'dart:ui';

/// Maps a beef temperature (°C) to a color: blue when sub-cold (<4),
/// green inside the 4–8 °C target band, amber as it drifts warm, red on a
/// significant breach (>~12 °C). Shared by the landscape chart and the legend.
Color tempScaleColor(double tempC) {
  const cold = Color(0xFF1565C0);
  const good = Color(0xFF2ECC71);
  const warn = Color(0xFFF1C40F);
  const hot = Color(0xFFE74C3C);

  if (tempC < 4) {
    // 4 → green, -2 → blue
    final t = ((4 - tempC) / 6).clamp(0.0, 1.0);
    return Color.lerp(good, cold, t)!;
  }
  if (tempC <= 8) {
    return good;
  }
  if (tempC <= 12) {
    final t = ((tempC - 8) / 4).clamp(0.0, 1.0);
    return Color.lerp(good, warn, t)!;
  }
  final t = ((tempC - 12) / 12).clamp(0.0, 1.0);
  return Color.lerp(warn, hot, t)!;
}
