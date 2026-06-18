import 'stage.dart';

/// Where a reading came from.
enum ReadingSource {
  /// The planned/ideal "cooltag" profile: what the chain is *supposed* to look
  /// like if every link holds 4–8 °C.
  cooltag,

  /// The actual sensor trace from the physical fridge/reefer for this leg.
  actualSensor,
}

/// A single temperature sample on a chain's timeline.
class TemperatureReading {
  const TemperatureReading({
    required this.hoursElapsed,
    required this.tempC,
    required this.stage,
    required this.source,
  });

  /// Hours since the start of the chain (slaughter = 0).
  final double hoursElapsed;
  final double tempC;
  final Stage stage;
  final ReadingSource source;

  bool get isBreach {
    final def = stageDefOf(stage);
    return tempC > def.targetMax || tempC < def.targetMin;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hoursElapsed': double.parse(hoursElapsed.toStringAsFixed(3)),
        'tempC': double.parse(tempC.toStringAsFixed(3)),
        'stage': stage.name,
        'source': source.name,
      };
}
