import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';

Workout workout(Sport sport, DateTime start,
        {int seconds = 1800, double meters = 5000}) =>
    Workout(
      id: start.millisecondsSinceEpoch,
      uuid: '$start',
      sport: sport,
      startedAt: start,
      status: WorkoutStatus.finished,
      durationS: seconds,
      distanceM: meters,
    );

void main() {
  group('Maximalpuls und Zonen', () {
    final now = DateTime(2026, 10, 11);

    test('Faustformel 220 minus Lebensalter', () {
      const profile = HeartProfile(birthYear: 1986);
      expect(profile.maxHr(now), 180);
    });

    test('ein eigener Wert hat Vorrang; ohne Angaben gibt es keinen', () {
      expect(const HeartProfile(birthYear: 1986, manualMaxHr: 192).maxHr(now),
          192);
      expect(const HeartProfile().maxHr(now), isNull);
    });

    test('Zonengrenzen bei 60, 70, 80 und 90 Prozent', () {
      expect(HeartZone.thresholds(180), [108, 126, 144, 162]);
      expect(HeartZone.z1.range(180), 'bis 107');
      expect(HeartZone.z3.range(180), '126–143');
      expect(HeartZone.z5.range(180), 'ab 162');
    });

    test('Profil wird gespeichert und lässt sich wieder leeren', () {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      const HeartProfile(birthYear: 1986, manualMaxHr: 190).save(db);
      expect(HeartProfile.load(db).birthYear, 1986);
      expect(HeartProfile.load(db).manualMaxHr, 190);
      const HeartProfile(birthYear: 1986).save(db);
      expect(HeartProfile.load(db).manualMaxHr, isNull);
    });
  });

  group('Umfang', () {
    // Sonntag, 11. Oktober 2026; die laufende Woche beginnt am Montag, 5.10.
    final now = DateTime(2026, 10, 11, 15);
    final workouts = [
      workout(Sport.running, DateTime(2026, 10, 5, 7)), // Montag früh
      workout(Sport.running, DateTime(2026, 10, 11, 9), meters: 10000),
      workout(Sport.indoorBike, DateTime(2026, 10, 7, 18), seconds: 3600),
      workout(Sport.hiking, DateTime(2026, 10, 4, 23, 59)), // Sonntag davor
      workout(Sport.running, DateTime(2026, 1, 3)), // außerhalb der 12 Wochen
    ];

    test('Wochen beginnen am Montag; die laufende Woche steht am Ende', () {
      final weeks = buildVolume(workouts, VolumePeriod.week, now: now);
      expect(weeks, hasLength(12));
      expect(weeks.last.start, DateTime(2026, 10, 5));
      expect(weeks.first.start, DateTime(2026, 7, 20));

      final current = weeks.last;
      expect(current.count, 3);
      expect(current.seconds, 1800 + 1800 + 3600);
      expect(current.meters, 20000);
      expect(current.bySport[Sport.running]!.count, 2);
      expect(current.bySport[Sport.running]!.meters, 15000);
      expect(current.bySport[Sport.indoorBike]!.seconds, 3600);

      expect(weeks[10].bySport.keys, [Sport.hiking]);
      expect(weeks[9].count, 0);
    });

    test('Monate über den Jahreswechsel', () {
      final months = buildVolume(workouts, VolumePeriod.month,
          now: now, buckets: 12);
      expect(months.last.start, DateTime(2026, 10));
      expect(months.first.start, DateTime(2025, 11));
      expect(months.last.count, 4);
      expect(months[2].start, DateTime(2026, 1));
      expect(months[2].count, 1);
    });
  });

  group('Bestwerte', () {
    test('schnellster Abschnitt irgendwo im Training', () {
      // 100 s mit 2 m/s, 100 s mit 5 m/s, 100 s mit 2 m/s
      final distance = <double>[];
      var d = 0.0;
      for (var t = 0; t < 300; t++) {
        d += t >= 100 && t < 200 ? 5 : 2;
        distance.add(d);
      }
      expect(fastestSeconds(distance, 500), 100);
      // 500 m schnell, die restlichen 100 m langsam: 100 s + 50 s
      expect(fastestSeconds(distance, 600), 150);
      expect(fastestSeconds(distance, 900), 300);
      expect(fastestSeconds(distance, 901), isNull);
    });

    test('gleichmäßiges Tempo: Strecke durch Geschwindigkeit', () {
      final distance = [for (var t = 1; t <= 600; t++) t * 4.0];
      expect(fastestSeconds(distance, 1000), 250);
    });

    test('höchster Durchschnitt über ein Zeitfenster', () {
      final power = [100, 100, 300, 300, 300, 100, 100];
      expect(bestAverage(power, 3), 300);
      expect(bestAverage(power, 5), 220);
      expect(bestAverage(power, 8), isNull);
    });
  });

  group('Auswertung in der Datenbank', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    int record(Sport sport, DateTime start,
        {required int seconds,
        double speedMps = 0,
        int? Function(int t)? hr,
        int? Function(int t)? power}) {
      final id = db.startWorkout(sport, start);
      for (var t = 1; t <= seconds; t++) {
        db.addSample(
          id,
          Sample(
            t: t,
            heartRate: hr?.call(t),
            power: power?.call(t),
            distanceM: t * speedMps,
          ),
        );
      }
      db.finishWorkout(id);
      return id;
    }

    test('Zeit je Pulszone für ein Training und für einen Zeitraum', () {
      final thresholds = HeartZone.thresholds(180); // 108, 126, 144, 162
      final recent = record(Sport.running, DateTime.now(), seconds: 100,
          hr: (t) => t <= 10
              ? 100 // Zone 1
              : t <= 40
                  ? 126 // Zone 3, genau auf der Grenze
                  : t <= 90
                      ? 150 // Zone 4
                      : null); // Sensor ausgefallen
      record(Sport.running, DateTime.now().subtract(const Duration(days: 60)),
          seconds: 20, hr: (_) => 170);

      expect(db.zoneSeconds(thresholds, workoutId: recent), [10, 0, 30, 50, 0]);
      expect(
          db.zoneSeconds(thresholds,
              since: DateTime.now().subtract(const Duration(days: 30))),
          [10, 0, 30, 50, 0]);
      expect(db.zoneSeconds(thresholds), [10, 0, 30, 50, 20]);
    });

    test('Bestwerte je Sportart mit dem Training, das sie hält', () {
      final slow = record(Sport.running, DateTime(2026, 9, 1),
          seconds: 3000, speedMps: 2.5); // 7,5 km
      final fast = record(Sport.running, DateTime(2026, 10, 1),
          seconds: 400, speedMps: 4); // 1,6 km
      record(Sport.indoorBike, DateTime(2026, 10, 2),
          seconds: 400, speedMps: 8, power: (t) => t <= 100 ? 250 : 150);

      final running = db.bestEfforts(Sport.running);
      expect(running[EffortKind.fastest1km]!.value, 250);
      expect(running[EffortKind.fastest1km]!.workoutId, fast);
      expect(running[EffortKind.fastest5km]!.value, 2000);
      expect(running[EffortKind.fastest5km]!.workoutId, slow);
      expect(running.containsKey(EffortKind.fastest10km), isFalse);
      expect(running.containsKey(EffortKind.power1min), isFalse);

      final bike = db.bestEfforts(Sport.indoorBike);
      expect(bike[EffortKind.power1min]!.value, 250);
      expect(bike[EffortKind.power5min]!.value, closeTo(183.33, 0.01));
      expect(bike.containsKey(EffortKind.power20min), isFalse);
    });

    test('gelöschte Trainings halten keine Bestwerte mehr', () {
      final fast = record(Sport.running, DateTime(2026, 10, 1),
          seconds: 400, speedMps: 4);
      record(Sport.running, DateTime(2026, 9, 1), seconds: 600, speedMps: 2);
      db.deleteWorkout(fast);
      expect(db.bestEfforts(Sport.running)[EffortKind.fastest1km]!.value, 500);
    });

    test('Titel, Sportart und Notiz lassen sich ändern und wieder leeren', () {
      final id = record(Sport.running, DateTime(2026, 10, 1), seconds: 10);
      db.updateWorkout(id,
          title: ' Morgenrunde ', sport: Sport.hiking, notes: 'Regen');
      var w = db.workout(id)!;
      expect(w.title, 'Morgenrunde');
      expect(w.sport, Sport.hiking);
      expect(w.notes, 'Regen');

      db.updateWorkout(id, title: '', sport: Sport.hiking, notes: '  ');
      w = db.workout(id)!;
      expect(w.title, isNull);
      expect(w.notes, isNull);
    });
  });
}
