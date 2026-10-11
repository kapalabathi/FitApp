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
  indoorBike('indoor_bike', 'Indoor-Bike', Icons.directions_bike,
      indoorMachine: true),
  skiErg('ski_erg', 'SkiErg', Icons.downhill_skiing, indoorMachine: true),
  running('running', 'Laufen', Icons.directions_run),
  walking('walking', 'Spazieren', Icons.directions_walk),
  hiking('hiking', 'Wandern', Icons.hiking),
  yoga('yoga', 'Yoga', Icons.self_improvement),
  crossfit('crossfit', 'Crossfit', Icons.fitness_center),
  calisthenics('calisthenics', 'Calisthenics', Icons.sports_gymnastics),
  stretching('stretching', 'Dehnen', Icons.accessibility_new),
  other('other', 'Sonstiges', Icons.timer, indoorMachine: true);

  const Sport(this.id, this.label, this.icon, {this.indoorMachine = false});

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

  static Sport fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => Sport.other);
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

  double? get avgSpeedKmh =>
      durationS > 0 && distanceM > 0 ? distanceM / durationS * 3.6 : null;
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
