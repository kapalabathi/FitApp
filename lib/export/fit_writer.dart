import 'dart:typed_data';

import '../data/models.dart';

/// Schreibt ein Training als FIT-Datei, das Format von Garmin, das Strava und
/// die meisten Sport-Plattformen lesen (Lastenheft A-062).
///
/// Die Zeitachse der Datei ist die aktive Zeit: Pausen sind herausgerechnet,
/// weil die App nur aktive Sekunden aufzeichnet.
///
/// Mit [fixedLocation] bekommt ein Training ohne eigene Strecke in jedem
/// Messpunkt diesen einen Standort. Manche Programme nehmen nur Dateien mit
/// Standort an. Hat das Training eine Strecke, bleibt sie unverändert.
///
/// Jeder Abbruch aus [linkLosses] wird als Ereignis „Verbindung verloren"
/// (comm_timeout) an seiner Stelle eingefügt. Einen Freitext sieht FIT dort
/// nicht vor; unterschieden wird nur, ob die Funkstrecke abriss
/// (connection_timeout) oder die Verbindung beendet wurde (connection_lost).
Uint8List buildFit(
  Workout workout,
  List<Sample> samples,
  List<Lap> laps, {
  ({double latitude, double longitude})? fixedLocation,
  List<LinkLoss> linkLosses = const [],
}) {
  final hasRoute = samples.any((s) => s.latitude != null);
  final everywhere = hasRoute ? null : fixedLocation;
  final out = _FitWriter();
  final start = _fitTime(workout.startedAt);
  final end = start + workout.durationS;
  final (sport, subSport) = _sport(workout.sport);
  // FIT zählt beim Laufen und Gehen die Schritte eines Beins, die App die
  // beider Beine.
  final cadenceDivisor = sport == _sportRunning || sport == _sportHiking ? 2 : 1;

  out
    ..define(0, _fileId, const [
      (0, _T.enumeration), // Art der Datei
      (1, _T.uint16), // Hersteller
      (2, _T.uint16), // Produkt
      (4, _T.uint32), // erstellt am
    ])
    ..data(0, [_fileTypeActivity, _manufacturerDevelopment, 1, start])
    ..define(1, _event, const [
      (253, _T.uint32),
      (0, _T.enumeration), // Ereignis
      (1, _T.enumeration), // Art
    ])
    ..data(1, [start, _eventTimer, _eventStart])
    ..define(6, _event, const [
      (253, _T.uint32),
      (0, _T.enumeration), // Ereignis
      (1, _T.enumeration), // Art
      (3, _T.uint32), // Daten: Art des Abbruchs
    ])
    ..define(2, _record, const [
      (253, _T.uint32),
      (0, _T.sint32), // Breite in Halbkreisen
      (1, _T.sint32), // Länge in Halbkreisen
      (2, _T.uint16), // Höhe: (m + 500) × 5
      (3, _T.uint8), // Puls
      (4, _T.uint8), // Frequenz
      (5, _T.uint32), // Strecke in cm
      (6, _T.uint16), // Geschwindigkeit in mm/s
      (7, _T.uint16), // Leistung in W
    ]);

  final losses = [...linkLosses]..sort((a, b) => a.t.compareTo(b.t));
  var nextLoss = 0;
  void writeLossesUntil(int t) {
    while (nextLoss < losses.length && losses[nextLoss].t <= t) {
      final loss = losses[nextLoss++];
      out.data(6, [
        start + loss.t,
        _eventCommTimeout,
        _eventMarker,
        loss.isTimeout ? _commConnectionTimeout : _commConnectionLost,
      ]);
    }
  }

  for (final s in samples) {
    writeLossesUntil(s.t);
    final speed = s.speedKmh;
    final altitude = s.altitudeM;
    final distance = s.distanceM;
    out.data(2, [
      start + s.t,
      _semicircles(s.latitude ?? everywhere?.latitude),
      _semicircles(s.longitude ?? everywhere?.longitude),
      altitude == null ? null : ((altitude + 500) * 5).round(),
      s.heartRate,
      s.cadence == null ? null : (s.cadence! / cadenceDivisor).round(),
      distance == null ? null : (distance * 100).round(),
      speed == null ? null : (speed / 3.6 * 1000).round(),
      s.power,
    ]);
  }

  writeLossesUntil(workout.durationS);
  out
    ..data(1, [end, _eventTimer, _eventStopAll])
    ..define(3, _lap, const [
      (254, _T.uint16), // Nummer
      (253, _T.uint32),
      (2, _T.uint32), // Beginn
      (7, _T.uint32), // Dauer in ms
      (8, _T.uint32), // aktive Dauer in ms
      (9, _T.uint32), // Strecke in cm
      (0, _T.enumeration),
      (1, _T.enumeration),
    ]);

  // Der Rest nach der letzten Marke ist die letzte Runde; ohne Marken ist
  // das ganze Training eine Runde.
  final marks = [
    ...laps,
    if (laps.isEmpty || laps.last.t < workout.durationS)
      Lap(t: workout.durationS, distanceM: workout.distanceM, auto: false),
  ];
  var lapStartT = 0;
  var lapStartDistance = 0.0;
  for (var i = 0; i < marks.length; i++) {
    final seconds = marks[i].t - lapStartT;
    out.data(3, [
      i,
      start + marks[i].t,
      start + lapStartT,
      seconds * 1000,
      seconds * 1000,
      ((marks[i].distanceM - lapStartDistance) * 100).round(),
      _eventLap,
      _eventStop,
    ]);
    lapStartT = marks[i].t;
    lapStartDistance = marks[i].distanceM;
  }

  out
    ..define(4, _session, const [
      (254, _T.uint16),
      (253, _T.uint32),
      (2, _T.uint32), // Beginn
      (7, _T.uint32), // Dauer in ms
      (8, _T.uint32), // aktive Dauer in ms
      (9, _T.uint32), // Strecke in cm
      (11, _T.uint16), // Energie in kcal
      (22, _T.uint16), // Anstieg in m
      (25, _T.uint16), // erste Runde
      (26, _T.uint16), // Anzahl Runden
      (0, _T.enumeration),
      (1, _T.enumeration),
      (5, _T.enumeration), // Sportart
      (6, _T.enumeration), // Unterart
      (16, _T.uint8), // Ø Puls
      (17, _T.uint8), // max. Puls
      (20, _T.uint16), // Ø Leistung
      (21, _T.uint16), // max. Leistung
    ])
    ..data(4, [
      0,
      end,
      start,
      workout.durationS * 1000,
      workout.durationS * 1000,
      (workout.distanceM * 100).round(),
      workout.energyKcal,
      workout.ascentM,
      0,
      marks.length,
      _eventSession,
      _eventStop,
      sport,
      subSport,
      workout.avgHeartRate,
      workout.maxHeartRate,
      workout.avgPower,
      workout.maxPower,
    ])
    ..define(5, _activity, const [
      (253, _T.uint32),
      (0, _T.uint32), // aktive Dauer in ms
      (1, _T.uint16), // Anzahl Sitzungen
      (2, _T.enumeration), // Art
      (3, _T.enumeration),
      (4, _T.enumeration),
    ])
    ..data(5, [
      end,
      workout.durationS * 1000,
      1,
      _activityManual,
      _eventActivity,
      _eventStop,
    ]);

  return out.finish();
}

// Nummern der Nachrichten laut FIT-Profil
const _fileId = 0;
const _session = 18;
const _lap = 19;
const _record = 20;
const _event = 21;
const _activity = 34;

const _fileTypeActivity = 4;
const _manufacturerDevelopment = 255;
const _activityManual = 0;

// Ereignisse und ihre Arten
const _eventTimer = 0;
const _eventSession = 8;
const _eventLap = 9;
const _eventActivity = 26;
const _eventStart = 0;
const _eventStop = 1;
const _eventStopAll = 4;
const _eventMarker = 3;
const _eventCommTimeout = 47;
const _commConnectionLost = 2;
const _commConnectionTimeout = 3;

const _sportRunning = 1;
const _sportHiking = 17;

/// Sportart und Unterart laut FIT-Profil.
(int, int) _sport(Sport sport) => switch (sport) {
      Sport.running => (_sportRunning, 0),
      Sport.treadmill => (_sportRunning, 1),
      Sport.indoorBike => (2, 6),
      Sport.hiking => (_sportHiking, 0),
      Sport.skiErg => (4, 0), // Fitnessgerät
      Sport.yoga => (10, 43),
      Sport.stretching => (10, 19),
      Sport.crossfit || Sport.calisthenics => (10, 20),
      Sport.other => (0, 0),
    };

/// FIT zählt Sekunden ab dem 31.12.1989, 0 Uhr UTC.
int _fitTime(DateTime time) =>
    time.toUtc().millisecondsSinceEpoch ~/ 1000 - 631065600;

int? _semicircles(double? degrees) =>
    degrees == null ? null : (degrees * 2147483648 / 180).round();

/// Die Zahlentypen der Datei mit Größe, Kennung und dem Wert für „fehlt".
enum _T {
  enumeration(1, 0x00, 0xFF),
  uint8(1, 0x02, 0xFF),
  uint16(2, 0x84, 0xFFFF),
  sint32(4, 0x85, 0x7FFFFFFF),
  uint32(4, 0x86, 0xFFFFFFFF);

  const _T(this.size, this.code, this.invalid);

  final int size;
  final int code;
  final int invalid;

  /// Der größte Wert, der kein „fehlt" ist.
  int get max => invalid - 1;
  int get min => this == sint32 ? -0x7FFFFFFF : 0;
}

class _FitWriter {
  final BytesBuilder _body = BytesBuilder();
  final Map<int, List<(int, _T)>> _definitions = {};

  /// Legt fest, welche Felder die Nachrichten mit der Kennung [local] tragen.
  void define(int local, int global, List<(int, _T)> fields) {
    _definitions[local] = fields;
    _body
      ..addByte(0x40 | local)
      ..addByte(0) // reserviert
      ..addByte(0) // Little Endian
      ..addByte(global & 0xFF)
      ..addByte(global >> 8)
      ..addByte(fields.length);
    for (final (number, type) in fields) {
      _body
        ..addByte(number)
        ..addByte(type.size)
        ..addByte(type.code);
    }
  }

  /// Schreibt eine Nachricht; `null` steht für einen fehlenden Wert, zu
  /// große oder zu kleine Werte werden an die Grenze des Typs gesetzt.
  void data(int local, List<int?> values) {
    final fields = _definitions[local]!;
    assert(values.length == fields.length);
    _body.addByte(local);
    for (var i = 0; i < fields.length; i++) {
      final type = fields[i].$2;
      final value = values[i]?.clamp(type.min, type.max) ?? type.invalid;
      for (var b = 0; b < type.size; b++) {
        _body.addByte((value >> (8 * b)) & 0xFF);
      }
    }
  }

  Uint8List finish() {
    final body = _body.toBytes();
    final header = ByteData(14)
      ..setUint8(0, 14) // Länge des Kopfs
      ..setUint8(1, 0x20) // Protokoll 2.0
      ..setUint16(2, 2132, Endian.little) // Profil 21.32
      ..setUint32(4, body.length, Endian.little)
      ..setUint8(8, 0x2E) // ".FIT"
      ..setUint8(9, 0x46)
      ..setUint8(10, 0x49)
      ..setUint8(11, 0x54);
    final headerBytes = header.buffer.asUint8List();
    header.setUint16(12, _crc(headerBytes.sublist(0, 12)), Endian.little);

    final file = BytesBuilder()
      ..add(headerBytes)
      ..add(body);
    final crc = _crc(file.toBytes());
    file
      ..addByte(crc & 0xFF)
      ..addByte(crc >> 8);
    return file.toBytes();
  }

  static const _crcTable = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401, //
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
  ];

  /// Prüfsumme, wie das FIT-Protokoll sie vorschreibt.
  static int _crc(List<int> bytes) {
    var crc = 0;
    for (final byte in bytes) {
      var tmp = _crcTable[crc & 0xF];
      crc = (crc >> 4) & 0x0FFF;
      crc = crc ^ tmp ^ _crcTable[byte & 0xF];
      tmp = _crcTable[crc & 0xF];
      crc = (crc >> 4) & 0x0FFF;
      crc = crc ^ tmp ^ _crcTable[(byte >> 4) & 0xF];
    }
    return crc;
  }
}
