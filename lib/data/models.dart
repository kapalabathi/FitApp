import 'package:flutter/material.dart';

import '../ble/device_kind.dart';

/// Messgrößen, die Sensoren und Geräte liefern.
enum Metric {
  heartRate,
  speed,

  /// Tritt-, Schritt- oder Schlagfrequenz je Minute, je nach Sportart.
  cadence,
  power,
  incline,
  resistance,

  /// Zähler des Geräts seit dessen Start, in Metern.
  distanceTotal,

  /// Zähler des Geräts seit dessen Start, in Kilokalorien.
  energyTotal,
}

/// Sportarten laut Lastenheft A-020. [id] steht in der Datenbank und darf sich
/// nicht mehr ändern.
enum Sport {
  treadmill('treadmill', 'Laufband', Icons.directions_run, indoorMachine: true),
  indoorBike(
    'indoor_bike',
    'Indoor-Bike',
    Icons.directions_bike,
    indoorMachine: true,
  ),
  skiErg('ski_erg', 'SkiErg', Icons.downhill_skiing, indoorMachine: true),
  running('running', 'Laufen', Icons.directions_run),
  hiking('hiking', 'Spazieren/Wandern', Icons.hiking),
  cycling('cycling', 'Radfahren', Icons.pedal_bike),
  yoga('yoga', 'Yoga', Icons.self_improvement),
  crossfit('crossfit', 'Crossfit', Icons.fitness_center),
  calisthenics('calisthenics', 'Calisthenics', Icons.sports_gymnastics),
  stretching('stretching', 'Dehnen', Icons.accessibility_new),
  other('other', 'Sonstiges', Icons.timer, indoorMachine: true);

  const Sport(this.id, this.label, this.icon, {this.indoorMachine = false});

  /// Wird im Freien mit dem GPS des Phones aufgezeichnet.
  bool get usesGps =>
      this == Sport.running || this == Sport.hiking || this == Sport.cycling;

  /// Schneller bewegt man sich in dieser Sportart nicht; höhere Werte vom
  /// GPS sind Messfehler.
  double get maxPlausibleSpeedMps => switch (this) {
    Sport.running => 10,
    Sport.cycling => 25,
    _ => 5,
  };

  /// Lässt sich auf der Startseite frei starten; die übrigen Sportarten
  /// laufen über Trainingsprogramme.
  bool get freeRecording => indoorMachine || usesGps;

  final String id;
  final String label;
  final IconData icon;

  /// Wird ohne GPS und ohne Übungsprogramm aufgezeichnet.
  final bool indoorMachine;

  String get cadenceLabel => switch (this) {
    Sport.skiErg => 'Schlagfrequenz',
    Sport.treadmill || Sport.running => 'Schrittfrequenz',
    _ => 'Trittfrequenz',
  };

  /// Früher eine eigene Sportart, seit Version 0.4.2 Teil von [hiking].
  static const _formerWalkingId = 'walking';

  static Sport fromId(String id) => id == _formerWalkingId
      ? Sport.hiking
      : values.firstWhere((s) => s.id == id, orElse: () => Sport.other);
}

enum WorkoutStatus {
  recording('recording'),
  finished('finished'),

  /// Nach Absturz oder leerem Akku aus den gesicherten Messwerten abgeschlossen.
  recovered('recovered');

  const WorkoutStatus(this.id);

  final String id;

  static WorkoutStatus fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => finished);
}

class Workout {
  const Workout({
    required this.id,
    required this.uuid,
    required this.sport,
    required this.startedAt,
    required this.status,
    this.title,
    this.durationS = 0,
    this.distanceM = 0,
    this.avgHeartRate,
    this.maxHeartRate,
    this.avgPower,
    this.maxPower,
    this.avgCadence,
    this.energyKcal,
    this.ascentM,
    this.notes,
    this.stravaId,
    this.imported = false,
    this.energyEstimated = false,
  });

  final int id;

  /// Geräteübergreifend eindeutig, für die spätere Synchronisation.
  final String uuid;
  final Sport sport;
  final DateTime startedAt;
  final WorkoutStatus status;
  final String? title;

  /// Aktive Zeit ohne Pausen.
  final int durationS;
  final double distanceM;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final int? avgPower;
  final int? maxPower;
  final int? avgCadence;
  final int? energyKcal;

  /// Summe der Anstiege, nur bei Aufzeichnungen mit GPS.
  final int? ascentM;
  final String? notes;

  /// Nummer der zugehörigen Aktivität bei Strava, nach Upload oder Import.
  final int? stravaId;

  /// Von Strava übernommen statt in der App aufgezeichnet.
  final bool imported;

  /// [energyKcal] stammt nicht vom Gerät, sondern ist aus dem Puls
  /// geschätzt.
  final bool energyEstimated;

  double? get avgSpeedKmh =>
      durationS > 0 && distanceM > 0 ? distanceM / durationS * 3.6 : null;
}

/// Die Belastung eines Trainings, aus der Zeit in den Pulszonen.
class WorkoutLoad {
  const WorkoutLoad({
    required this.workoutId,
    required this.startedAt,
    required this.load,
  });

  final int workoutId;
  final DateTime startedAt;
  final int load;
}

/// Die Messwerte einer aktiven Sekunde. [t] zählt aktive Sekunden ab 1.
class Sample {
  const Sample({
    required this.t,
    this.heartRate,
    this.speedKmh,
    this.cadence,
    this.power,
    this.distanceM,
    this.incline,
    this.resistance,
    this.latitude,
    this.longitude,
    this.altitudeM,
  });

  final int t;
  final int? heartRate;
  final double? speedKmh;
  final double? cadence;
  final int? power;

  /// Zurückgelegte Strecke seit Trainingsbeginn.
  final double? distanceM;
  final double? incline;
  final double? resistance;

  // Nur bei Aufzeichnungen mit GPS und nur, solange ein Standort vorliegt.
  final double? latitude;
  final double? longitude;
  final double? altitudeM;
}

/// Eine Rundenmarke: Stand von Zeit und Strecke am Ende der Runde.
class Lap {
  const Lap({required this.t, required this.distanceM, required this.auto});

  /// Aktive Sekunden seit Trainingsbeginn.
  final int t;
  final double distanceM;

  /// Von der App nach jedem vollen Kilometer gesetzt, nicht von Hand.
  final bool auto;
}

/// Ein absolvierter Satz einer Übung innerhalb eines Trainings.
class SetLog {
  const SetLog({
    required this.exerciseUuid,
    required this.t,
    this.reps,
    this.weightKg,
    this.seconds,
    this.performedAt,
  });

  final String exerciseUuid;

  /// Aktive Sekunde des Trainings, in der der Satz abgeschlossen wurde.
  final int t;

  /// Wiederholungen; `null` bei Übungen auf Zeit.
  final int? reps;

  /// Zusatzgewicht; `null`, wenn keines erfasst wurde.
  final double? weightKg;

  /// Dauer bei Übungen auf Zeit.
  final int? seconds;

  /// Beginn des zugehörigen Trainings; nur beim Lesen eines Verlaufs gesetzt.
  final DateTime? performedAt;
}

/// Ein gemerktes Bluetooth-Gerät.
class SavedDevice {
  const SavedDevice({
    required this.deviceId,
    required this.name,
    required this.kind,
  });

  final String deviceId;
  final String name;
  final DeviceKind kind;
}

/// Ein Abbruch der Bluetooth-Verbindung zu einem Gerät während eines
/// Trainings, mit dem Grund, den Android dafür meldet.
class LinkLoss {
  const LinkLoss({
    required this.t,
    required this.device,
    this.reason,
    this.downS,
  });

  /// Aktive Sekunde des Trainings, in der die Verbindung abbrach.
  final int t;

  /// Name des Geräts.
  final String device;

  /// Der Grund in der Fassung von Android (englisch), oder `null`, wenn
  /// keiner gemeldet wurde.
  final String? reason;

  /// Sekunden bis zur erneuten Verbindung; `null`, wenn sie bis zum Ende
  /// des Trainings nicht zurückkam.
  final int? downS;

  /// Der Grund auf Deutsch.
  String get reasonLabel => linkReasonLabel(reason);

  /// Ob die Funkstrecke abgerissen ist, statt dass eine Seite die
  /// Verbindung bewusst beendet hat.
  bool get isTimeout {
    final r = reason?.toLowerCase() ?? '';
    return r.contains('timeout');
  }
}

/// Die Abbrüche als Text zum Weitergeben, je Zeile Zeitpunkt in Sekunden,
/// Gerät, Grund im Wortlaut von Android und Dauer.
String linkLossReport(List<LinkLoss> losses) => [
  for (final l in losses)
    '${l.t} s | ${l.device} | ${l.reason ?? 'ohne Grund'} | '
        '${l.downS == null ? 'nicht zurück' : '${l.downS} s getrennt'}',
].join('\n');

/// Der Grund, wenn die App selbst neu verbindet, weil nichts mehr kommt.
const linkSilentReason = 'No Data From Device';

/// Übersetzt die Gründe für einen Verbindungsabbruch, die Android meldet.
String linkReasonLabel(String? reason) {
  if (reason == null || reason.isEmpty) return 'ohne Angabe von Android';
  const known = {
    linkSilentReason: 'keine Daten mehr, von der App neu verbunden',
    'Connection Timeout': 'Funkverbindung abgerissen (Zeitüberschreitung)',
    'LMP Response Timeout / LL Response Timeout':
        'Gerät antwortet nicht mehr (Zeitüberschreitung)',
    'Remote User Terminated Connection': 'vom Gerät beendet',
    'Remote Device Terminated Connection due to Low Resources':
        'vom Gerät beendet, zu wenig Ressourcen',
    'Remote Device Terminated Connection due to Power Off':
        'Gerät ausgeschaltet',
    'Connection Terminated By Local Host': 'vom Phone beendet',
    'Connection Failed to be Established / Synchronization Timeout':
        'Verbindung kam nicht zustande',
    'Connection Terminated due to MIC Failure':
        'Verbindung wegen Prüfsummenfehler beendet',
    'Unacceptable Connection Parameters':
        'Verbindungsparameter nicht angenommen',
  };
  return known[reason] ?? reason;
}
