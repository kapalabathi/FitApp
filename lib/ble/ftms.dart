import 'byte_reader.dart';

/// Was ein FTMS-Gerät messen und was es als Zielwert annehmen kann
/// (Merkmal 0x2ACC).
class FtmsFeatures {
  const FtmsFeatures(this.machineBits, this.targetBits);

  final int machineBits;
  final int targetBits;

  static FtmsFeatures parse(List<int> bytes) {
    final r = ByteReader(bytes);
    return FtmsFeatures(r.u32(), r.u32());
  }

  static const _machineNames = [
    'Durchschnittsgeschwindigkeit',
    'Trittfrequenz',
    'Gesamtdistanz',
    'Steigung',
    'Höhengewinn',
    'Tempo',
    'Schrittzahl',
    'Widerstandsstufe',
    'Schrittfrequenz',
    'Energieverbrauch',
    'Herzfrequenz',
    'Metabolisches Äquivalent',
    'Verstrichene Zeit',
    'Restzeit',
    'Leistung',
    'Bandkraft und Leistungsabgabe',
    'Speicherung von Nutzerdaten',
  ];

  static const _targetNames = [
    'Zielgeschwindigkeit',
    'Zielsteigung',
    'Zielwiderstand',
    'Zielleistung',
    'Zielherzfrequenz',
    'Ziel-Energieverbrauch',
    'Ziel-Schrittzahl',
    'Ziel-Schrittfrequenzzahl',
    'Zieldistanz',
    'Ziel-Trainingszeit',
    'Zielzeit in zwei Pulszonen',
    'Zielzeit in drei Pulszonen',
    'Zielzeit in fünf Pulszonen',
    'Steigungssimulation (Indoor-Bike)',
    'Radumfang',
    'Ausrollkalibrierung',
    'Ziel-Trittfrequenz',
  ];

  List<String> get machineFeatures => _names(machineBits, _machineNames);
  List<String> get targetSettings => _names(targetBits, _targetNames);

  bool get canSetSpeed => targetBits & (1 << 0) != 0;
  bool get canSetInclination => targetBits & (1 << 1) != 0;
  bool get canSetResistance => targetBits & (1 << 2) != 0;
  bool get canSetPower => targetBits & (1 << 3) != 0;
  bool get canSimulateGrade => targetBits & (1 << 13) != 0;

  static List<String> _names(int bits, List<String> names) => [
        for (var i = 0; i < 32; i++)
          if (bits & (1 << i) != 0)
            i < names.length ? names[i] : 'unbekannt (Bit $i)',
      ];
}

/// Einstellbereich eines Zielwerts: kleinster und größter Wert, Schrittweite.
class FtmsRange {
  const FtmsRange(this.min, this.max, this.step);

  final double min;
  final double max;
  final double step;

  /// 0x2AD4, Einheit km/h.
  static FtmsRange parseSpeed(List<int> bytes) {
    final r = ByteReader(bytes);
    return FtmsRange(r.u16() / 100, r.u16() / 100, r.u16() / 100);
  }

  /// 0x2AD5, Einheit Prozent.
  static FtmsRange parseInclination(List<int> bytes) {
    final r = ByteReader(bytes);
    return FtmsRange(r.s16() / 10, r.s16() / 10, r.u16() / 10);
  }

  /// 0x2AD6, ohne Einheit.
  static FtmsRange parseResistance(List<int> bytes) {
    final r = ByteReader(bytes);
    return FtmsRange(r.s16() / 10, r.s16() / 10, r.u16() / 10);
  }

  /// 0x2AD8, Einheit Watt.
  static FtmsRange parsePower(List<int> bytes) {
    final r = ByteReader(bytes);
    return FtmsRange(
        r.s16().toDouble(), r.s16().toDouble(), r.u16().toDouble());
  }

  @override
  String toString() => '$min bis $max, Schritt $step';
}

/// Ein Datenpaket eines Laufbands (Merkmal 0x2ACD).
///
/// Felder, die das Gerät in diesem Paket nicht mitschickt, sind `null`.
class TreadmillData {
  const TreadmillData({
    this.speedKmh,
    this.averageSpeedKmh,
    this.totalDistanceM,
    this.inclinationPercent,
    this.elevationGainM,
    this.totalEnergyKcal,
    this.heartRate,
    this.elapsedSeconds,
    this.remainingSeconds,
    this.powerWatt,
  });

  final double? speedKmh;
  final double? averageSpeedKmh;
  final int? totalDistanceM;
  final double? inclinationPercent;
  final double? elevationGainM;
  final int? totalEnergyKcal;
  final int? heartRate;
  final int? elapsedSeconds;
  final int? remainingSeconds;
  final int? powerWatt;

  static TreadmillData parse(List<int> bytes) {
    final r = ByteReader(bytes);
    final flags = r.u16();
    bool has(int bit) => flags & (1 << bit) != 0;

    // Bit 0 ist umgekehrt belegt: gesetzt heißt, die Geschwindigkeit fehlt.
    final speed = has(0) ? null : r.u16() / 100;
    final avgSpeed = has(1) ? r.u16() / 100 : null;
    final distance = has(2) ? r.u24() : null;
    double? inclination;
    if (has(3)) {
      inclination = r.s16() / 10;
      r.skip(2); // Rampenwinkel
    }
    double? elevation;
    if (has(4)) {
      elevation = r.u16() / 10;
      r.skip(2); // negativer Höhengewinn
    }
    if (has(5)) r.skip(1); // momentanes Tempo
    if (has(6)) r.skip(1); // durchschnittliches Tempo
    int? energy;
    if (has(7)) {
      energy = _energy(r.u16());
      r.skip(3); // Energie je Stunde und je Minute
    }
    final heartRate = has(8) ? r.u8() : null;
    if (has(9)) r.skip(1); // metabolisches Äquivalent
    final elapsed = has(10) ? r.u16() : null;
    final remaining = has(11) ? r.u16() : null;
    int? power;
    if (has(12)) {
      r.skip(2); // Bandkraft
      power = r.s16();
    }
    return TreadmillData(
      speedKmh: speed,
      averageSpeedKmh: avgSpeed,
      totalDistanceM: distance,
      inclinationPercent: inclination,
      elevationGainM: elevation,
      totalEnergyKcal: energy,
      heartRate: heartRate,
      elapsedSeconds: elapsed,
      remainingSeconds: remaining,
      powerWatt: power,
    );
  }
}

/// Ein Datenpaket eines Indoor-Bikes (Merkmal 0x2AD2).
///
/// Felder, die das Gerät in diesem Paket nicht mitschickt, sind `null`.
class IndoorBikeData {
  const IndoorBikeData({
    this.speedKmh,
    this.averageSpeedKmh,
    this.cadenceRpm,
    this.averageCadenceRpm,
    this.totalDistanceM,
    this.resistanceLevel,
    this.powerWatt,
    this.averagePowerWatt,
    this.totalEnergyKcal,
    this.heartRate,
    this.elapsedSeconds,
    this.remainingSeconds,
  });

  final double? speedKmh;
  final double? averageSpeedKmh;
  final double? cadenceRpm;
  final double? averageCadenceRpm;
  final int? totalDistanceM;
  final int? resistanceLevel;
  final int? powerWatt;
  final int? averagePowerWatt;
  final int? totalEnergyKcal;
  final int? heartRate;
  final int? elapsedSeconds;
  final int? remainingSeconds;

  static IndoorBikeData parse(List<int> bytes) {
    final r = ByteReader(bytes);
    final flags = r.u16();
    bool has(int bit) => flags & (1 << bit) != 0;

    // Bit 0 ist umgekehrt belegt: gesetzt heißt, die Geschwindigkeit fehlt.
    final speed = has(0) ? null : r.u16() / 100;
    final avgSpeed = has(1) ? r.u16() / 100 : null;
    final cadence = has(2) ? r.u16() / 2 : null;
    final avgCadence = has(3) ? r.u16() / 2 : null;
    final distance = has(4) ? r.u24() : null;
    final resistance = has(5) ? r.s16() : null;
    final power = has(6) ? r.s16() : null;
    final avgPower = has(7) ? r.s16() : null;
    int? energy;
    if (has(8)) {
      energy = _energy(r.u16());
      r.skip(3); // Energie je Stunde und je Minute
    }
    final heartRate = has(9) ? r.u8() : null;
    if (has(10)) r.skip(1); // metabolisches Äquivalent
    final elapsed = has(11) ? r.u16() : null;
    final remaining = has(12) ? r.u16() : null;
    return IndoorBikeData(
      speedKmh: speed,
      averageSpeedKmh: avgSpeed,
      cadenceRpm: cadence,
      averageCadenceRpm: avgCadence,
      totalDistanceM: distance,
      resistanceLevel: resistance,
      powerWatt: power,
      averagePowerWatt: avgPower,
      totalEnergyKcal: energy,
      heartRate: heartRate,
      elapsedSeconds: elapsed,
      remainingSeconds: remaining,
    );
  }
}

/// 0xFFFF bedeutet laut Standard „Wert nicht verfügbar".
int? _energy(int raw) => raw == 0xFFFF ? null : raw;
