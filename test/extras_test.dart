import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/session/auto_pause.dart';
import 'package:fitapp/session/quick_start.dart';
import 'package:fitapp/session/tile_layout.dart';
import 'package:fitapp/session/workout_recorder.dart';
import 'package:fitapp/stats/stats.dart';
import 'package:fitapp/sync/auto_backup.dart';
import 'package:fitapp/sync/sync_engine.dart';
import 'package:fitapp/ui/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase db;
  setUpAll(() => initializeDateFormatting('de'));
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  group('Automatische Pause', () {
    /// Meldet die Geschwindigkeiten der Reihe nach und nennt die Sekunden,
    /// in denen sich der Zustand geändert hat.
    List<String> changes(AutoPause auto, List<double?> speeds) => [
          for (var i = 0; i < speeds.length; i++)
            if (auto.update(speeds[i]))
              '${i + 1}: ${auto.paused ? 'Pause' : 'weiter'}',
        ];

    test('pausiert nach anhaltendem Stillstand und läuft bei Bewegung weiter',
        () {
      final auto = AutoPause.forSport(Sport.treadmill)!;
      expect(
        changes(auto, [9, 9, 0, 0, 0, 0, 0, 9, 9, 9]),
        ['5: Pause', '9: weiter'],
      );
    });

    test('ein kurzer Aussetzer pausiert nicht', () {
      final auto = AutoPause.forSport(Sport.treadmill)!;
      expect(changes(auto, [9, 0, 0, 9, 0, 0, 9]), isEmpty);
    });

    test('ohne Messwert bleibt alles, wie es ist', () {
      // Ein Verbindungsabbruch ist kein Stillstand.
      final auto = AutoPause.forSport(Sport.treadmill)!;
      expect(changes(auto, [9, null, null, null, null, null, 9]), isEmpty);
      expect(changes(auto, [0, 0, 0]), ['3: Pause']);
      expect(changes(auto, [null, null, null]), isEmpty);
      expect(auto.paused, isTrue);
    });

    test('draußen wartet die Pause länger als am Gerät', () {
      final hike = AutoPause.forSport(Sport.hiking)!;
      // 0,5 km/h gelten beim Wandern als Stillstand, aber erst nach 10 s.
      expect(changes(hike, List.filled(9, 0.5)), isEmpty);
      expect(changes(hike, [0.5]), ['1: Pause']);
    });

    test('nach „Weiter" von Hand greift sie erst nach erneuter Bewegung', () {
      final auto = AutoPause.forSport(Sport.treadmill)!;
      changes(auto, [0, 0, 0]);
      auto.overrideByUser();
      expect(auto.paused, isFalse);
      // Weiter Stillstand: Der Nutzer wollte es so.
      expect(changes(auto, List.filled(20, 0)), isEmpty);
      // Nach Bewegung gilt die Automatik wieder.
      expect(changes(auto, [9, 9, 0, 0, 0]), ['5: Pause']);
    });

    test('Sportarten ohne Geschwindigkeit haben keine automatische Pause', () {
      expect(AutoPause.forSport(Sport.yoga), isNull);
      expect(AutoPause.forSport(Sport.other), isNull);
    });
  });

  group('Energieverbrauch', () {
    final now = DateTime(2026, 10, 12);

    test('wird aus Puls, Gewicht, Alter und Geschlecht geschätzt', () {
      const man = HeartProfile(birthYear: 1986, weightKg: 80, sex: Sex.male);
      const woman =
          HeartProfile(birthYear: 1986, weightKg: 65, sex: Sex.female);
      // Formel nach Keytel, von Hand nachgerechnet
      expect(man.kcalPerMinute(150, now), closeTo(15.18, 0.01));
      expect(woman.kcalPerMinute(150, now), closeTo(9.90, 0.01));
      // Ohne Angabe des Geschlechts das Mittel aus beiden Formeln
      const unknown = HeartProfile(birthYear: 1986, weightKg: 80);
      expect(unknown.kcalPerMinute(150, now), closeTo(12.31, 0.01));
    });

    test('in Ruhe nie weniger als 0; ohne Gewicht keine Schätzung', () {
      const man = HeartProfile(birthYear: 1986, weightKg: 80, sex: Sex.male);
      expect(man.kcalPerMinute(40, now), 0);
      expect(const HeartProfile(birthYear: 1986).kcalPerMinute(150, now),
          isNull);
    });

    test('ein Training ohne Wert vom Gerät bekommt die Schätzung', () {
      const HeartProfile(birthYear: 1986, weightKg: 80, sex: Sex.male)
          .save(db);
      final id = db.startWorkout(Sport.yoga, DateTime(2026, 10, 12, 8));
      for (var t = 1; t <= 600; t++) {
        db.addSample(id, Sample(t: t, heartRate: 150));
      }
      db.finishWorkout(id);
      final w = db.workout(id)!;
      // 10 Minuten zu rund 15,2 kcal
      expect(w.energyKcal, inInclusiveRange(151, 153));
      expect(w.energyEstimated, isTrue);
    });

    test('ein Wert vom Gerät hat Vorrang und gilt nicht als geschätzt', () {
      const HeartProfile(birthYear: 1986, weightKg: 80).save(db);
      final id = db.startWorkout(Sport.treadmill, DateTime(2026, 10, 12, 8));
      db.addSample(id, const Sample(t: 1, heartRate: 150));
      db.finishWorkout(id, energyKcal: 321);
      expect(db.workout(id)!.energyKcal, 321);
      expect(db.workout(id)!.energyEstimated, isFalse);
    });

    test('ohne Profil oder ohne Puls bleibt der Verbrauch leer', () {
      final a = db.startWorkout(Sport.yoga, DateTime(2026, 10, 12, 8));
      db.addSample(a, const Sample(t: 1, heartRate: 150));
      db.finishWorkout(a);
      expect(db.workout(a)!.energyKcal, isNull);

      const HeartProfile(birthYear: 1986, weightKg: 80).save(db);
      final b = db.startWorkout(Sport.yoga, DateTime(2026, 10, 12, 9));
      db.addSample(b, const Sample(t: 1));
      db.finishWorkout(b);
      expect(db.workout(b)!.energyKcal, isNull);
    });

    test('die Schätzung läuft während des Trainings mit', () {
      var now = DateTime(2026, 10, 12, 8);
      final recorder = WorkoutRecorder(
        db: db,
        sport: Sport.yoga,
        clock: () => now,
        kcalPerMinute: (hr) => 12,
      )..addSource('gurt', dedicatedHeartRate: true);
      expect(recorder.energyKcal, isNull);
      for (var i = 0; i < 300; i++) {
        recorder.onData('gurt', {Metric.heartRate: 150});
        now = now.add(const Duration(seconds: 1));
        recorder.tick();
      }
      expect(recorder.energyKcal, 60);
      expect(recorder.energyEstimated, isTrue);
      expect(recorder.heartRateHistory, hasLength(300));
      expect(recorder.heartRateHistory.last, 150);
    });
  });

  group('Kacheln der Trainingsansicht', () {
    test('ohne Einstellung sind alle Kacheln sichtbar, in fester Reihenfolge',
        () {
      final layout = TileLayout.load(db, Sport.treadmill);
      expect(layout.visible, LiveTileKind.values);
      expect(layout.showChart, isTrue);
    });

    test('Reihenfolge und Ausblenden werden je Sportart gemerkt', () {
      const TileLayout(
        order: [
          LiveTileKind.heartRate,
          LiveTileKind.pace,
          LiveTileKind.time,
          ...[
            LiveTileKind.distance,
            LiveTileKind.power,
            LiveTileKind.cadence,
            LiveTileKind.incline,
            LiveTileKind.resistance,
            LiveTileKind.energy,
            LiveTileKind.ascent,
            LiveTileKind.lap,
          ],
        ],
        hidden: {LiveTileKind.power, LiveTileKind.incline},
        showChart: false,
      ).save(db, Sport.treadmill);

      final loaded = TileLayout.load(db, Sport.treadmill);
      expect(loaded.visible.take(4), [
        LiveTileKind.heartRate,
        LiveTileKind.pace,
        LiveTileKind.time,
        LiveTileKind.distance,
      ]);
      expect(loaded.visible, isNot(contains(LiveTileKind.power)));
      expect(loaded.showChart, isFalse);
      // Andere Sportarten bleiben unberührt.
      expect(TileLayout.load(db, Sport.indoorBike).visible,
          LiveTileKind.values);
    });

    test('später hinzugekommene Kacheln stehen sichtbar am Ende', () {
      final layout = TileLayout.parse('heartRate,-time,unbekannt');
      expect(layout.order.take(2), [LiveTileKind.heartRate, LiveTileKind.time]);
      expect(layout.order, hasLength(LiveTileKind.values.length));
      expect(layout.hidden, {LiveTileKind.time});
    });
  });

  group('Schnellstart', () {
    final t0 = DateTime(2026, 10, 12, 8);
    QuickStart entry(Sport sport, {int? template, Set<String> devices = const {}}) =>
        QuickStart(sport: sport, templateId: template, deviceIds: devices);

    test('das zuletzt gestartete Training steht oben', () {
      QuickStarts.remember(db, entry(Sport.treadmill), now: t0);
      QuickStarts.remember(db, entry(Sport.indoorBike),
          now: t0.add(const Duration(hours: 1)));
      expect(QuickStarts.load(db).map((q) => q.sport),
          [Sport.indoorBike, Sport.treadmill]);
    });

    test('dasselbe Training erscheint nur einmal', () {
      final same = entry(Sport.treadmill, template: 3, devices: {'b', 'a'});
      QuickStarts.remember(db, same, now: t0);
      QuickStarts.remember(db, entry(Sport.treadmill, template: 3, devices: {'a', 'b'}),
          now: t0.add(const Duration(hours: 1)));
      QuickStarts.remember(db, entry(Sport.treadmill, template: 4, devices: {'a', 'b'}),
          now: t0.add(const Duration(hours: 2)));
      expect(QuickStarts.load(db), hasLength(2));
    });

    test('Favoriten stehen vorn und werden nie verdrängt', () {
      QuickStarts.remember(db, entry(Sport.skiErg), now: t0);
      QuickStarts.setPinned(db, QuickStarts.load(db).single, true);
      for (var i = 1; i <= 8; i++) {
        QuickStarts.remember(db, entry(Sport.treadmill, template: i),
            now: t0.add(Duration(hours: i)));
      }
      final all = QuickStarts.load(db);
      expect(all.first.sport, Sport.skiErg);
      expect(all.first.pinned, isTrue);
      expect(all, hasLength(1 + QuickStarts.maxRecent));
      // Erneutes Starten behält die Markierung.
      QuickStarts.remember(db, entry(Sport.skiErg),
          now: t0.add(const Duration(days: 1)));
      expect(QuickStarts.load(db).first.pinned, isTrue);
    });

    test('Programme und entfernte Einträge', () {
      QuickStarts.remember(
          db, const QuickStart(sport: Sport.yoga, programId: 7),
          now: t0);
      final program = QuickStarts.load(db).single;
      expect(program.programId, 7);
      QuickStarts.remove(db, program);
      expect(QuickStarts.load(db), isEmpty);
    });
  });

  group('Kraft-Protokoll', () {
    int workout(DateTime start) {
      final id = db.startWorkout(Sport.calisthenics, start);
      db.addSample(id, const Sample(t: 1));
      db.finishWorkout(id);
      return id;
    }

    test('Sätze werden je Training und je Übung geführt', () {
      final first = workout(DateTime(2026, 10, 1));
      final second = workout(DateTime(2026, 10, 8));
      db.addSetLog(first,
          const SetLog(exerciseUuid: 'squat', t: 30, reps: 10, weightKg: 20));
      db.addSetLog(first,
          const SetLog(exerciseUuid: 'plank', t: 70, seconds: 40));
      db.addSetLog(second,
          const SetLog(exerciseUuid: 'squat', t: 20, reps: 8, weightKg: 22.5));
      db.addSetLog(
          second, const SetLog(exerciseUuid: 'squat', t: 60, reps: 12));

      expect(db.setLogs(first).map(formatSet), ['10 × 20 kg', '40 s']);

      final history = db.exerciseHistory('squat');
      // Neuestes Training zuerst, darin in der Reihenfolge der Sätze
      expect(history.map(formatSet), ['8 × 22,5 kg', '12 ×', '10 × 20 kg']);
      expect(history.first.performedAt, DateTime(2026, 10, 8));
      // Als Vorschlag gilt das zuletzt erfasste Gewicht.
      expect(db.lastWeight('squat'), 22.5);
      expect(db.lastWeight('plank'), isNull);
    });

    test('Sätze gelöschter Trainings zählen nicht mehr', () {
      final id = workout(DateTime(2026, 10, 1));
      db.addSetLog(id, const SetLog(exerciseUuid: 'squat', t: 1, reps: 5));
      db.deleteWorkout(id);
      expect(db.exerciseHistory('squat'), isEmpty);
    });

    test('Sätze und Profil wandern bei der Synchronisation mit', () async {
      final other = AppDatabase.inMemory();
      addTearDown(other.close);
      final store = MemorySyncStore();
      const HeartProfile(birthYear: 1986, weightKg: 78.5, sex: Sex.male)
          .save(db);
      final id = workout(DateTime(2026, 10, 1));
      db.addSetLog(id,
          const SetLog(exerciseUuid: 'squat', t: 1, reps: 10, weightKg: 20));

      await synchronize(db, store);
      await synchronize(other, store);

      final there = other.workouts().single;
      expect(other.setLogs(there.id).map(formatSet), ['10 × 20 kg']);
      final profile = HeartProfile.load(other);
      expect(profile.weightKg, 78.5);
      expect(profile.sex, Sex.male);
    });
  });

  group('Automatische Sicherung', () {
    test('je Wochentag eine Datei', () {
      expect(AutoBackup.fileName(DateTime(2026, 10, 12)), // Montag
          'fitapp_sicherung_Mo.fitapp');
      expect(AutoBackup.fileName(DateTime(2026, 10, 18)),
          'fitapp_sicherung_So.fitapp');
    });

    test('ohne gewählten Ordner ist sie ausgeschaltet', () {
      expect(AutoBackup.folderName(db), isNull);
      expect(AutoBackup.lastRun(db), isNull);
    });

    test('fällig ist sie einmal am Tag', () {
      final morning = DateTime(2026, 10, 12, 7);
      expect(AutoBackup.isDue(db, morning), isTrue);
      db.setSetting('backup.lastRun', '${morning.millisecondsSinceEpoch}');
      expect(AutoBackup.isDue(db, DateTime(2026, 10, 12, 22)), isFalse);
      expect(AutoBackup.isDue(db, DateTime(2026, 10, 13, 0, 5)), isTrue);
    });
  });
}
