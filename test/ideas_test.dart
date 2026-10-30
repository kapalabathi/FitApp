import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/export/fit_writer.dart';
import 'package:fitapp/import/file_import.dart';
import 'package:fitapp/programs/builtin_programs.dart';
import 'package:fitapp/programs/program_models.dart';
import 'package:fitapp/programs/program_run.dart';
import 'package:fitapp/session/auto_pause.dart';
import 'package:fitapp/session/heart_rate_regulator.dart';
import 'package:fitapp/session/workout_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  group('Radfahren', () {
    test('zeichnet mit GPS auf und lässt Radtempo zu', () {
      expect(Sport.cycling.usesGps, isTrue);
      expect(Sport.cycling.freeRecording, isTrue);
      expect(Sport.cycling.maxPlausibleSpeedMps * 3.6, 90);
      expect(Sport.fromId('cycling'), Sport.cycling);
      expect(AutoPause.forSport(Sport.cycling), isNotNull);
    });

    test('eine FIT-Datei trägt die Sportart Radfahren', () {
      final id = db.startWorkout(Sport.cycling, DateTime(2026, 10, 30, 9));
      for (var t = 1; t <= 600; t++) {
        db.addSample(id, Sample(t: t, speedKmh: 25, distanceM: t * 6.9));
      }
      db.finishWorkout(id);
      final bytes = buildFit(db.workout(id)!, db.samples(id), db.laps(id));
      expect(parseActivityFile('fahrt.fit', bytes).sport, Sport.cycling);
    });
  });

  group('Überbrückung kurzer Abbrüche', () {
    late DateTime now;
    late WorkoutRecorder recorder;
    setUp(() {
      now = DateTime(2026, 10, 30, 9);
      recorder =
          WorkoutRecorder(db: db, sport: Sport.treadmill, clock: () => now)
            ..addSource('band', dedicatedHeartRate: false, bridgeGaps: true)
            ..addSource('sensor', dedicatedHeartRate: false);
    });

    test('der letzte Wert des Geräts hält 20 Sekunden', () {
      recorder.onData('band', {Metric.speed: 10});
      now = now.add(const Duration(seconds: 16));
      expect(recorder.value(Metric.speed), 10);
      now = now.add(const Duration(seconds: 5));
      expect(recorder.value(Metric.speed), isNull);
    });

    test('für Entscheidungen gilt nur der frische Wert', () {
      recorder.onData('band', {Metric.speed: 10});
      now = now.add(const Duration(seconds: 6));
      expect(recorder.value(Metric.speed), 10);
      expect(recorder.liveValue(Metric.speed), isNull);
    });

    test('Sensoren ohne Überbrückung verfallen weiter nach 5 Sekunden', () {
      recorder.onData('sensor', {Metric.cadence: 80});
      now = now.add(const Duration(seconds: 6));
      expect(recorder.value(Metric.cadence), isNull);
    });
  });

  group('Pulsregelung', () {
    HeartRateRegulator regulator() =>
        HeartRateRegulator(targetBpm: 140, step: 0.5, min: 1, max: 10);

    /// Lässt [seconds] Sekunden laufen und gibt die Änderungen zurück.
    List<double> run(
        HeartRateRegulator r, int seconds, double? hr, double? current) {
      final changes = <double>[];
      var value = current;
      for (var i = 0; i < seconds; i++) {
        final next = r.update(hr, value);
        if (next != null) {
          changes.add(next);
          value = next;
        }
      }
      return changes;
    }

    test('steigert erst nach dem Aufwärmen und nur in kleinen Schritten', () {
      final r = regulator();
      expect(run(r, HeartRateRegulator.warmUpS - 1, 120, 8), isEmpty);
      final changes = run(r, 100, 120, 8);
      expect(changes.first, 8.5);
      // Zwischen zwei Schritten liegt die Wartezeit.
      expect(changes, hasLength(lessThanOrEqualTo(3)));
    });

    test('nimmt bei zu hohem Puls sofort zurück, auch beim Aufwärmen', () {
      final changes = run(regulator(), 30, 155, 8);
      expect(changes.first, 7.5);
      expect(changes, hasLength(2));
    });

    test('bleibt innerhalb der Toleranz ruhig', () {
      expect(run(regulator(), 600, 142, 8), isEmpty);
    });

    test('hält die Obergrenze ein', () {
      final r = regulator();
      run(r, HeartRateRegulator.warmUpS, 120, 10);
      expect(run(r, 300, 120, 10), isEmpty);
    });

    test('tut ohne Puls oder Gerätewert nichts', () {
      final r = regulator();
      expect(run(r, 600, null, 8), isEmpty);
      expect(r.holding, isTrue);
      expect(run(r, 600, 120, null), isEmpty);
      expect(r.holding, isTrue);
    });

    test('startet ein stehendes Band nie', () {
      final r = regulator();
      run(r, HeartRateRegulator.warmUpS, 120, 0);
      expect(run(r, 300, 120, 0), isEmpty);
    });
  });

  group('Routinen', () {
    test('die fünf Routinen sind angelegt', () {
      final names = db.programs().map((p) => p.name);
      expect(builtinProgramsBatch4, hasLength(5));
      expect(names, containsAll(builtinProgramsBatch4.map((p) => p.name)));
    });
  });

  group('Tausch beim Abspielen', () {
    test('gilt für die laufende und alle späteren Phasen', () {
      final byKey = {for (final e in db.exercises()) e.builtinKey: e};
      final knie = byKey['cali_02_liegestuetz_knie']!;
      final voll = byKey['cali_01_liegestuetz']!;
      final squat = byKey['crossfit_01_air_squat']!;
      final run = ProgramRun(
        Program(
          name: 'Test',
          category: ExerciseCategory.calisthenics,
          rounds: 2,
          items: [
            ProgramItem(
                exerciseUuid: voll.uuid, timed: false, amount: 8, restS: 10),
            ProgramItem(exerciseUuid: squat.uuid, timed: false, amount: 10),
          ],
        ),
        {voll.uuid: voll, squat.uuid: squat},
      )..start();
      run.replaceExercise(knie);
      expect(run.current!.exercise.name, knie.name);
      expect(run.current!.item.amount, 8);
      expect(
        run.phases.where((p) => !p.isRest).map((p) => p.exercise.uuid),
        [knie.uuid, squat.uuid, knie.uuid, squat.uuid],
      );
    });
  });
}
