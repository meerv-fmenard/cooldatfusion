import 'dart:math' as math;

import '../models/temperature_reading.dart';

/// Spoilage kinetics for chilled beef, modelled with the classic Q10 rule:
/// microbial growth rate roughly multiplies by [q10] for every 10 °C rise.
///
/// We express spoilage as "shelf-life days consumed". At the reference
/// temperature the product consumes 1 day of life per calendar day. Warmer
/// product consumes life faster; product held just-cold consumes it slower.
class Q10Model {
  Q10Model({
    this.q10 = 2.5,
    this.referenceTempC = 4.0,
    this.freezeTempC = -1.5,
  });

  /// Rate multiplier per 10 °C. Higher Q10 → harsher penalty for warmth.
  final double q10;

  /// The temperature at which 1 calendar day == 1 shelf-life day consumed.
  final double referenceTempC;

  /// Below this, ice crystals damage the meat (freeze burn), which we also
  /// treat as accelerated quality loss.
  final double freezeTempC;

  /// Relative spoilage rate (life-days consumed per calendar day) at [tempC].
  double rateAt(double tempC) {
    if (tempC <= freezeTempC) {
      // Freezing damage: penalise proportionally to how far below freezing.
      final below = freezeTempC - tempC;
      return 1.0 + 0.15 * below;
    }
    return math.pow(q10, (tempC - referenceTempC) / 10.0).toDouble();
  }

  /// Life consumed (days) over [hours] held constant at [tempC].
  double lifeConsumed(double tempC, double hours) =>
      rateAt(tempC) * (hours / 24.0);

  /// Integrate life consumed across an ordered list of readings using the
  /// trapezoid rule on the spoilage rate between consecutive samples.
  double lifeConsumedOver(List<TemperatureReading> readings) =>
      _integrate(readings, rateAt);

  /// The *excess* spoilage rate beyond what the product would experience while
  /// held at the warm edge of its target band (8 °C), plus a freezing penalty.
  /// This is zero whenever the product is comfortably inside 4–8 °C, so a
  /// flawless cold chain accrues no "abuse" at all.
  double penaltyRateAt(double tempC) {
    final warmEdge = rateAt(8.0);
    if (tempC > 8.0) return rateAt(tempC) - warmEdge;
    if (tempC < freezeTempC) return rateAt(tempC) - 1.0;
    return 0.0;
  }

  /// Abuse-days accrued over a leg: integral of the excess spoilage rate.
  double abuseOver(List<TemperatureReading> readings) =>
      _integrate(readings, penaltyRateAt);

  double _integrate(
      List<TemperatureReading> readings, double Function(double) f) {
    if (readings.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < readings.length; i++) {
      final a = readings[i - 1];
      final b = readings[i];
      final dtHours = b.hoursElapsed - a.hoursElapsed;
      if (dtHours <= 0) continue;
      final avgRate = 0.5 * (f(a.tempC) + f(b.tempC));
      total += avgRate * (dtHours / 24.0);
    }
    return total;
  }
}
