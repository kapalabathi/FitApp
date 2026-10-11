import '../data/models.dart';
import 'byte_reader.dart';
import 'ftms.dart';
import 'heart_rate.dart';
import 'sensor_profiles.dart';
import 'uuids.dart';

typedef Decode = Map<Metric, double> Function(List<int> bytes);

/// Übersetzt die Pakete eines Bluetooth-Merkmals in Messwerte.
class CharacteristicDecoder {
  const CharacteristicDecoder(
      this.service, this.characteristic, Decode Function() create)
      : _create = create,
        _decode = null;

  /// Für Merkmale, deren Pakete für sich allein auswertbar sind.
  const CharacteristicDecoder.stateless(
      this.service, this.characteristic, Decode decode)
      : _decode = decode,
        _create = null;

  final String service;
  final String characteristic;
  final Decode Function()? _create;
  final Decode? _decode;

  /// Eine Auswertung für eine Verbindung. Manche Sensoren senden Zähler,
  /// aus denen erst der Vergleich mit dem vorigen Paket einen Messwert
  /// macht; jede Verbindung braucht dafür ihr eigenes Gedächtnis.
  Decode create() => _decode ?? _create!();
}

/// Alle Merkmale, die die App auswertet.
const List<CharacteristicDecoder> decoders = [
  CharacteristicDecoder.stateless(
      Uuids.heartRateService, Uuids.heartRateMeasurement, _heartRate),
  CharacteristicDecoder.stateless(
      Uuids.ftmsService, Uuids.treadmillData, _treadmill),
  CharacteristicDecoder.stateless(
      Uuids.ftmsService, Uuids.indoorBikeData, _indoorBike),
  CharacteristicDecoder.stateless(
      Uuids.ftmsService, Uuids.rowerData, rowerData),
  CharacteristicDecoder.stateless(
      Uuids.ftmsService, Uuids.crossTrainerData, crossTrainerData),
  CharacteristicDecoder.stateless(
      Uuids.pm5RowingService, Uuids.pm5GeneralStatus, pm5General),
  CharacteristicDecoder.stateless(
      Uuids.pm5RowingService, Uuids.pm5AdditionalStatus, pm5Additional),
  CharacteristicDecoder.stateless(Uuids.runningSpeedCadenceService,
      Uuids.rscMeasurement, runningSpeedCadence),
  CharacteristicDecoder(Uuids.cyclingPowerService,
      Uuids.cyclingPowerMeasurement, cyclingPowerDecoder),
  CharacteristicDecoder(Uuids.cyclingSpeedCadenceService,
      Uuids.cscMeasurement, cyclingSpeedCadenceDecoder),
];

Map<Metric, double> _heartRate(List<int> bytes) {
  final s = HeartRateSample.parse(bytes);
  // 0 senden Sensoren, solange sie noch keinen Puls erkannt haben.
  return {if (s.bpm > 0) Metric.heartRate: s.bpm.toDouble()};
}

Map<Metric, double> _treadmill(List<int> bytes) {
  final d = TreadmillData.parse(bytes);
  return _withoutNulls({
    Metric.speed: d.speedKmh,
    Metric.incline: d.inclinationPercent,
    Metric.distanceTotal: d.totalDistanceM?.toDouble(),
    Metric.energyTotal: d.totalEnergyKcal?.toDouble(),
    Metric.power: d.powerWatt?.toDouble(),
    Metric.heartRate: _machinePulse(d.heartRate),
  });
}

Map<Metric, double> _indoorBike(List<int> bytes) {
  final d = IndoorBikeData.parse(bytes);
  return _withoutNulls({
    Metric.speed: d.speedKmh,
    Metric.cadence: d.cadenceRpm,
    Metric.power: d.powerWatt?.toDouble(),
    Metric.resistance: d.resistanceLevel?.toDouble(),
    Metric.distanceTotal: d.totalDistanceM?.toDouble(),
    Metric.energyTotal: d.totalEnergyKcal?.toDouble(),
    Metric.heartRate: _machinePulse(d.heartRate),
  });
}

/// Concept2 PM5, Merkmal 0x0031: verstrichene Zeit und Distanz.
Map<Metric, double> pm5General(List<int> bytes) {
  final r = ByteReader(bytes);
  r.skip(3); // verstrichene Zeit in 0,01 s
  return {Metric.distanceTotal: r.u24() / 10};
}

/// Concept2 PM5, Merkmal 0x0032: Geschwindigkeit, Schlagfrequenz, Puls.
Map<Metric, double> pm5Additional(List<int> bytes) {
  final r = ByteReader(bytes);
  r.skip(3); // verstrichene Zeit
  final speedMmPerS = r.u16();
  final strokeRate = r.u8();
  final heartRate = r.u8();
  final paceCs = r.u16(); // Zeit je 500 m in 0,01 s
  return _withoutNulls({
    Metric.speed: speedMmPerS / 1000 * 3.6,
    Metric.cadence: strokeRate.toDouble(),
    // 255 heißt: kein Pulsgurt am PM5.
    Metric.heartRate: heartRate == 255 ? null : _machinePulse(heartRate),
    // Leistung nach der Formel von Concept2: 2,80 / (Sekunden je Meter)³.
    // So rechnet auch der Monitor selbst seine Watt-Anzeige aus dem Tempo.
    Metric.power: paceCs == 0 ? 0.0 : _pm5Watts(paceCs / 100 / 500),
  });
}

double _pm5Watts(double secondsPerMeter) =>
    2.8 / (secondsPerMeter * secondsPerMeter * secondsPerMeter);

/// Geräte ohne Handpulssensor oder gekoppelten Gurt melden 0.
double? _machinePulse(int? bpm) =>
    bpm == null || bpm == 0 ? null : bpm.toDouble();

Map<Metric, double> _withoutNulls(Map<Metric, double?> values) => {
      for (final e in values.entries)
        if (e.value != null) e.key: e.value!,
    };
