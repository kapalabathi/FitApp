import '../data/models.dart';
import 'byte_reader.dart';

/// Weitere Standardprofile neben Pulsgurt, Laufband und Indoor-Bike
/// (Lastenheft A-006): Leistungsmesser, Tritt- und Geschwindigkeitssensoren,
/// Laufsensoren, Rudergeräte und Crosstrainer.

/// Rechnet aus einem Umdrehungszähler und dem Zeitpunkt der letzten
/// Umdrehung die Drehzahl je Minute. Sensoren senden beides fortlaufend;
/// erst der Unterschied zweier Pakete ergibt die Frequenz.
class RevolutionRate {
  RevolutionRate({required this.ticksPerSecond, this.counterBits = 16});

  /// Auflösung der Zeitangabe des Sensors.
  final int ticksPerSecond;

  /// Breite des Zählers; danach beginnt er wieder bei 0.
  final int counterBits;

  int? _lastCount;
  int? _lastTime;

  /// Umdrehungen seit dem vorigen Paket; 0 beim ersten.
  int lastStep = 0;

  /// Die Drehzahl je Minute seit dem vorigen Paket, oder `null`, solange es
  /// kein voriges gibt oder seither keine neue Umdrehung gemeldet wurde.
  double? update(int count, int time) {
    final previousCount = _lastCount;
    final previousTime = _lastTime;
    _lastCount = count;
    _lastTime = time;
    lastStep = 0;
    if (previousCount == null || previousTime == null) return null;
    // Zähler und Zeit laufen über; die Differenz stimmt trotzdem, wenn man
    // sie auf die Breite des Feldes begrenzt.
    final step = (count - previousCount) & ((1 << counterBits) - 1);
    final ticks = (time - previousTime) & 0xFFFF;
    if (ticks == 0) return null;
    lastStep = step;
    return step / (ticks / ticksPerSecond) * 60;
  }
}

/// Leistungsmesser am Rad (Merkmal 0x2A63): Leistung, dazu die Trittfrequenz,
/// wenn der Sensor Kurbelumdrehungen meldet.
Map<Metric, double> Function(List<int>) cyclingPowerDecoder() {
  final crank = RevolutionRate(ticksPerSecond: 1024);
  return (bytes) {
    final r = ByteReader(bytes);
    final flags = r.u16();
    bool has(int bit) => flags & (1 << bit) != 0;
    final values = {Metric.power: r.s16().toDouble()};
    if (has(0)) r.skip(1); // Verteilung links/rechts
    if (has(2)) r.skip(2); // Drehmoment
    if (has(4)) r.skip(6); // Radumdrehungen
    if (has(5)) {
      final cadence = crank.update(r.u16(), r.u16());
      if (cadence != null) values[Metric.cadence] = cadence;
    }
    return values;
  };
}

/// Umfang eines üblichen Rennrad-Laufrads (700 × 25C) in Metern. Der Sensor
/// zählt nur Umdrehungen; ohne den Umfang gibt es keine Geschwindigkeit.
const defaultWheelCircumferenceM = 2.105;

/// Tritt- und Geschwindigkeitssensor am Rad (Merkmal 0x2A5B).
Map<Metric, double> Function(List<int>) cyclingSpeedCadenceDecoder(
    {double wheelCircumferenceM = defaultWheelCircumferenceM}) {
  final wheel = RevolutionRate(ticksPerSecond: 1024, counterBits: 32);
  final crank = RevolutionRate(ticksPerSecond: 1024);
  var distanceM = 0.0;
  return (bytes) {
    final r = ByteReader(bytes);
    final flags = r.u8();
    final values = <Metric, double>{};
    if (flags & 0x01 != 0) {
      final perMinute = wheel.update(r.u32(), r.u16());
      if (perMinute != null) {
        values[Metric.speed] = perMinute * wheelCircumferenceM * 60 / 1000;
        distanceM += wheel.lastStep * wheelCircumferenceM;
        values[Metric.distanceTotal] = distanceM;
      }
    }
    if (flags & 0x02 != 0) {
      final cadence = crank.update(r.u16(), r.u16());
      if (cadence != null) values[Metric.cadence] = cadence;
    }
    return values;
  };
}

/// Laufsensor am Schuh (Merkmal 0x2A53): Geschwindigkeit, Schrittfrequenz
/// und, falls gemeldet, die Gesamtstrecke.
Map<Metric, double> runningSpeedCadence(List<int> bytes) {
  final r = ByteReader(bytes);
  final flags = r.u8();
  final values = {
    Metric.speed: r.u16() / 256 * 3.6,
    Metric.cadence: r.u8().toDouble(),
  };
  if (flags & 0x01 != 0) r.skip(2); // Schrittlänge
  if (flags & 0x02 != 0) values[Metric.distanceTotal] = r.u32() / 10;
  return values;
}

/// Rudergerät über FTMS (Merkmal 0x2AD1).
Map<Metric, double> rowerData(List<int> bytes) {
  final r = ByteReader(bytes);
  final flags = r.u16();
  bool has(int bit) => flags & (1 << bit) != 0;
  final values = <Metric, double>{};
  // Bit 0 ist umgekehrt belegt: gesetzt heißt, die Schlagdaten fehlen.
  if (!has(0)) {
    values[Metric.cadence] = r.u8() / 2;
    r.skip(2); // Schlagzahl
  }
  if (has(1)) r.skip(1); // durchschnittliche Schlagfrequenz
  if (has(2)) values[Metric.distanceTotal] = r.u24().toDouble();
  if (has(3)) {
    final secondsPer500m = r.u16();
    if (secondsPer500m > 0 && secondsPer500m != 0xFFFF) {
      values[Metric.speed] = 500 / secondsPer500m * 3.6;
    }
  }
  if (has(4)) r.skip(2); // durchschnittliches Tempo
  if (has(5)) values[Metric.power] = r.s16().toDouble();
  if (has(6)) r.skip(2); // durchschnittliche Leistung
  if (has(7)) values[Metric.resistance] = r.s16().toDouble();
  if (has(8)) {
    final energy = r.u16();
    if (energy != 0xFFFF) values[Metric.energyTotal] = energy.toDouble();
    r.skip(3); // Energie je Stunde und je Minute
  }
  if (has(9)) {
    final pulse = r.u8();
    if (pulse > 0) values[Metric.heartRate] = pulse.toDouble();
  }
  return values;
}

/// Crosstrainer über FTMS (Merkmal 0x2ACE).
Map<Metric, double> crossTrainerData(List<int> bytes) {
  final r = ByteReader(bytes);
  final flags = r.u24();
  bool has(int bit) => flags & (1 << bit) != 0;
  final values = <Metric, double>{};
  // Bit 0 ist umgekehrt belegt: gesetzt heißt, die Geschwindigkeit fehlt.
  if (!has(0)) values[Metric.speed] = r.u16() / 100;
  if (has(1)) r.skip(2); // Durchschnittsgeschwindigkeit
  if (has(2)) values[Metric.distanceTotal] = r.u24().toDouble();
  if (has(3)) {
    values[Metric.cadence] = r.u16().toDouble(); // Schritte je Minute
    r.skip(2); // durchschnittliche Schrittfrequenz
  }
  if (has(4)) r.skip(2); // Schrittzahl
  if (has(5)) r.skip(4); // Höhengewinn auf und ab
  if (has(6)) {
    values[Metric.incline] = r.s16() / 10;
    r.skip(2); // Rampenwinkel
  }
  if (has(7)) values[Metric.resistance] = r.s16() / 10;
  if (has(8)) values[Metric.power] = r.s16().toDouble();
  if (has(9)) r.skip(2); // durchschnittliche Leistung
  if (has(10)) {
    final energy = r.u16();
    if (energy != 0xFFFF) values[Metric.energyTotal] = energy.toDouble();
    r.skip(3); // Energie je Stunde und je Minute
  }
  if (has(11)) {
    final pulse = r.u8();
    if (pulse > 0) values[Metric.heartRate] = pulse.toDouble();
  }
  return values;
}
