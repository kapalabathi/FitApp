import 'dart:io';

import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/gps/geo.dart';
import 'package:fitapp/programs/builtin_exercises.dart';
import 'package:fitapp/programs/builtin_programs.dart';
import 'package:fitapp/programs/program_models.dart';
import 'package:fitapp/programs/program_run.dart';
import 'package:fitapp/session/workout_recorder.dart';
import 'package:fitapp/ui/area_chips.dart';
import 'package:flutter_test/flutter_test.dart';

const _plank = Exercise(
    uuid: 'plank', category: ExerciseCategory.calisthenics, name: 'Stütz');
const _pushUp = Exercise(
    uuid: 'pushup',
    category: ExerciseCategory.calisthenics,
    name: 'Liegestütz',
    timed: false);
const _exercises = {'plank': _plank, 'pushup': _pushUp};

const _program = Program(
  name: 'Test',
  category: ExerciseCategory.calisthenics,
  rounds: 2,
  items: [
    ProgramItem(exerciseUuid: 'plank', timed: true, amount: 5, restS: 4),
    ProgramItem(exerciseUuid: 'pushup', timed: false, amount: 10, restS: 2),
    ProgramItem(exerciseUuid: 'gelöscht', timed: true, amount: 30),
  ],
);

String short(ProgramEvent e) => switch (e) {
      PhaseStarted(:final phase) =>
        '${phase.isRest ? 'pause vor' : 'start'} ${phase.exercise.name}',
      PhaseEnding(:final secondsLeft) => 'noch $secondsLeft',
      PhaseCompleted(:final phase, :final elapsedS) =>
        'fertig ${phase.exercise.name} nach $elapsedS',
      ProgramFinished() => 'ende',
    };

/// Der Ablauf ohne die Meldungen über abgeschlossene Übungen.
Iterable<String> flow(List<ProgramEvent> events) =>
    events.where((e) => e is! PhaseCompleted).map(short);

void main() {
  group('Mitgelieferte Inhalte', () {
    test('164 Übungen, 40 je Bereich und 4 Umkehrhaltungen, mit eindeutigen '
        'Kennungen', () {
      expect(builtinExercises, hasLength(164));
      for (final c in ExerciseCategory.values) {
        expect(builtinExercises.where((e) => e.category == c),
            hasLength(c == ExerciseCategory.yoga ? 44 : 40));
      }
      expect(builtinExercises.map((e) => e.uuid).toSet(), hasLength(164));
      expect(builtinExercises.where((e) => e.batch == 1), hasLength(80));
      // Jede Übung nennt mindestens einen Körperbereich.
      expect(builtinExercises.every((e) => e.areas.isNotEmpty), isTrue);
      expect(builtinExercises.every((e) => e.description.length > 20), isTrue);
    });

    test('zu jeder mitgelieferten Übung liegt die Grafik bei', () {
      // Noch nicht gezeichnet (G-161 bis G-164); bis dahin zeigt die App
      // den Platzhalter.
      const pending = {
        'yoga_41_pflug',
        'yoga_42_schulterstand',
        'yoga_43_unterarmstand_wand',
        'yoga_44_kopfstand',
      };
      final missing = [
        for (final e in builtinExercises)
          if (!File('assets/exercises/${e.key}.webp').existsSync()) e.key,
      ];
      expect(missing.toSet().difference(pending), isEmpty);
    });

    test('jedes mitgelieferte Programm verweist nur auf vorhandene Übungen',
        () {
      final known = builtinExercises.map((e) => e.uuid).toSet();
      for (final p in [...builtinPrograms, ...builtinProgramsBatch2]) {
        expect(p.items, isNotEmpty, reason: p.name);
        for (final item in p.items) {
          expect(known, contains(item.exerciseUuid), reason: p.name);
        }
      }
    });

    test('eine neue Datenbank enthält Übungen und Programme', () {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      expect(db.exercises(), hasLength(164));
      expect(db.exercises(category: ExerciseCategory.yoga), hasLength(44));
      expect(db.programs(),
          hasLength(builtinPrograms.length + builtinProgramsBatch2.length));
      final first = db.exercises().firstWhere(
          (e) => e.builtinKey == 'yoga_01_berghaltung');
      expect(first.imageAsset, 'assets/exercises/yoga_01_berghaltung.webp');
      expect(first.areas, [BodyArea.core, BodyArea.legs]);
      // Auch die Übungen der zweiten Lieferung tragen ihre Bereiche.
      final plank =
          db.exercises().firstWhere((e) => e.builtinKey == 'yoga_22_brett');
      expect(plank.areas, [BodyArea.core, BodyArea.shoulders, BodyArea.arms]);
    });
  });

  group('Übungen und Programme in der Datenbank', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    test('eigene Übung anlegen, ändern, löschen', () {
      final id = db.saveExercise(Exercise(
        uuid: db.newExerciseUuid(),
        category: ExerciseCategory.crossfit,
        name: 'Schlittenziehen',
        timed: false,
        areas: const [BodyArea.legs, BodyArea.back],
      ));
      var stored = db.exercises().firstWhere((e) => e.id == id);
      expect(stored.builtinKey, isNull);
      expect(stored.imageAsset, isNull);
      expect(stored.timed, isFalse);
      expect(stored.areas, [BodyArea.legs, BodyArea.back]);

      db.saveExercise(stored.copyWith(name: 'Schlitten', imagePath: '/x.jpg'));
      stored = db.exercises().firstWhere((e) => e.id == id);
      expect(stored.name, 'Schlitten');
      expect(stored.imagePath, '/x.jpg');
      expect(db.exercises(), hasLength(165));

      db.deleteExercise(id);
      expect(db.exercises(), hasLength(164));
    });

    test('Programm speichern und wieder laden', () {
      final id = db.saveProgram(_program);
      final stored = db.programs().firstWhere((p) => p.id == id);
      expect(stored.rounds, 2);
      expect(stored.items, hasLength(3));
      expect(stored.items[1].timed, isFalse);
      expect(stored.items[1].amount, 10);
      expect(stored.timedSeconds, 2 * (5 + 4 + 2 + 30));
      expect(stored.hasRepetitions, isTrue);

      db.deleteProgram(id);
      expect(db.programs().any((p) => p.id == id), isFalse);
    });
  });

  group('Körperbereiche', () {
    test('werden als Liste abgelegt und wieder gelesen', () {
      const areas = [BodyArea.shoulders, BodyArea.core];
      expect(BodyArea.store(areas), 'schultern,rumpf');
      expect(BodyArea.parse('schultern,rumpf'), areas);
      expect(BodyArea.parse(''), isEmpty);
      expect(BodyArea.parse(null), isEmpty);
      expect(BodyArea.parse('unbekannt,beine'), [BodyArea.legs]);
    });

    test('ein Programm nennt seine Bereiche, die häufigsten zuerst', () {
      const exercises = {
        'a': Exercise(
            uuid: 'a',
            category: ExerciseCategory.calisthenics,
            name: 'A',
            areas: [BodyArea.arms, BodyArea.core]),
        'b': Exercise(
            uuid: 'b',
            category: ExerciseCategory.calisthenics,
            name: 'B',
            areas: [BodyArea.core, BodyArea.legs]),
      };
      const program = Program(
        name: 'P',
        category: ExerciseCategory.calisthenics,
        items: [
          ProgramItem(exerciseUuid: 'a', timed: true, amount: 10),
          ProgramItem(exerciseUuid: 'b', timed: true, amount: 10),
          ProgramItem(exerciseUuid: 'gelöscht', timed: true, amount: 10),
        ],
      );
      expect(programAreas(program, exercises),
          [BodyArea.core, BodyArea.arms, BodyArea.legs]);
    });
  });

  group('ProgramRun', () {
    test('Übung, Pause, Übung über alle Runden; gelöschte Übungen entfallen',
        () {
      final run = ProgramRun(_program, _exercises);
      final log = <String>[...flow(run.start())];
      void ticks(int n) {
        for (var i = 0; i < n; i++) {
          log.addAll(flow(run.tick()));
        }
      }

      ticks(9); // 5 s Stütz, 4 s Pause
      ticks(20); // Liegestütze warten auf den Nutzer
      log.addAll(flow(run.advance()));
      ticks(2); // Pause
      ticks(9);
      log.addAll(flow(run.advance()));

      expect(log, [
        'start Stütz',
        'noch 3', 'noch 2', 'noch 1',
        'pause vor Liegestütz',
        'noch 3', 'noch 2', 'noch 1',
        'start Liegestütz',
        'pause vor Stütz',
        'noch 1',
        'start Stütz',
        'noch 3', 'noch 2', 'noch 1',
        'pause vor Liegestütz',
        'noch 3', 'noch 2', 'noch 1',
        'start Liegestütz',
        // nach der letzten Übung folgt keine Pause mehr
        'ende',
      ]);
      expect(run.finished, isTrue);
      expect(run.progress, 1);
    });

    test('meldet jede abgeschlossene Übung mit ihrer Dauer, Pausen nicht', () {
      final run = ProgramRun(_program, _exercises)..start();
      final done = <String>[];
      void note(List<ProgramEvent> events) =>
          done.addAll(events.whereType<PhaseCompleted>().map(short));
      for (var i = 0; i < 9; i++) {
        note(run.tick()); // Stütz 5 s, Pause 4 s
      }
      for (var i = 0; i < 7; i++) {
        note(run.tick()); // Liegestütze, 7 s bis „Fertig"
      }
      note(run.advance());
      expect(done, ['fertig Stütz nach 5', 'fertig Liegestütz nach 7']);
    });

    test('kennt Restzeit, Fortschritt und die nächste Übung', () {
      final run = ProgramRun(_program, _exercises)..start();
      expect(run.remainingInPhase, 5);
      expect(run.nextExercise!.exercise.name, 'Liegestütz');
      expect(run.progress, 0);

      for (var i = 0; i < 9; i++) {
        run.tick();
      }
      expect(run.current!.exercise.name, 'Liegestütz');
      expect(run.remainingInPhase, isNull);
      expect(run.progress, 0.25);
      expect(run.current!.round, 1);
    });
  });

  group('GPS-Aufzeichnung', () {
    late AppDatabase db;
    late DateTime now;
    late WorkoutRecorder recorder;

    /// Ein Standort [steps] × 11,1 m nördlich des Startpunkts.
    GpsFix at(int steps, {double accuracy = 5, double? altitude}) => GpsFix(
          latitude: 50 + steps * 0.0001,
          longitude: 8,
          accuracyM: accuracy,
          altitudeM: altitude,
          speedMps: 3,
        );

    void second() {
      now = now.add(const Duration(seconds: 1));
      recorder.tick();
    }

    setUp(() {
      db = AppDatabase.inMemory();
      now = DateTime(2026, 10, 11, 8);
      recorder =
          WorkoutRecorder(db: db, sport: Sport.running, clock: () => now);
    });
    tearDown(() => db.close());

    test('Entfernung zweier Punkte', () {
      expect(distanceMeters(50, 8, 50.0001, 8), closeTo(11.12, 0.01));
      expect(distanceMeters(50, 8, 50, 8), 0);
    });

    test('Strecke, Geschwindigkeit und Position kommen vom GPS', () {
      for (var i = 0; i <= 10; i++) {
        recorder.onPosition(at(i));
        second();
      }
      expect(recorder.distanceM, closeTo(111.2, 0.2));
      expect(recorder.value(Metric.speed), closeTo(10.8, 0.001));
      final sample = db.samples(recorder.workoutId).last;
      expect(sample.latitude, closeTo(50.001, 1e-9));
      expect(sample.longitude, 8);
      expect(recorder.gpsAccuracyM, 5);
    });

    test('ein Sprung des GPS zählt weder als Strecke noch als Position', () {
      for (var i = 0; i <= 5; i++) {
        recorder.onPosition(at(i));
        second();
      }
      // 500 m in einer Sekunde sind beim Laufen unmöglich.
      recorder.onPosition(at(50));
      second();
      expect(db.samples(recorder.workoutId).last.latitude,
          closeTo(50.0005, 1e-9));
      for (var i = 6; i <= 10; i++) {
        recorder.onPosition(at(i));
        second();
      }
      expect(recorder.distanceM, closeTo(111.2, 0.2));
    });

    test('beim Wandern gilt eine niedrigere Grenze als beim Laufen', () {
      final hike =
          WorkoutRecorder(db: db, sport: Sport.hiking, clock: () => now);
      // 11,1 m je Sekunde: zu schnell zum Wandern, jeder Schritt ein Sprung
      for (var i = 0; i <= 5; i++) {
        hike.onPosition(at(i));
        now = now.add(const Duration(seconds: 1));
      }
      expect(hike.distanceM, 0);
    });

    test('einzelne Ausreißer verändern die angezeigte Geschwindigkeit nicht',
        () {
      GpsFix moving(int i, double speed, {double? error}) => GpsFix(
            latitude: 50 + i * 0.00003, // 3,3 m je Sekunde
            longitude: 8,
            accuracyM: 5,
            speedMps: speed,
            speedAccuracyMps: error,
          );
      final speeds = [3.0, 3.1, 2.9, 9.5, 3.0, 3.2, 0.0, 3.1];
      for (var i = 0; i < speeds.length; i++) {
        recorder.onPosition(moving(i, speeds[i]));
        second();
        expect(recorder.value(Metric.speed), inInclusiveRange(10.4, 11.6),
            reason: 'nach Messung $i');
      }
      // Unmögliche und als unsicher gemeldete Werte werden gar nicht gewertet.
      recorder.onPosition(moving(8, 40));
      recorder.onPosition(moving(9, 8, error: 4));
      expect(recorder.value(Metric.speed), inInclusiveRange(10.4, 11.6));
    });

    test('bei ungenauem Standort zählt erst eine größere Bewegung', () {
      // ±20 m Genauigkeit: Schritte von 3,3 m liegen im Rauschen …
      for (var i = 0; i < 3; i++) {
        recorder.onPosition(GpsFix(
            latitude: 50 + i * 0.00003, longitude: 8, accuracyM: 20));
        second();
      }
      expect(recorder.distanceM, 0);
      // … erst 11 m vom Ausgangspunkt entfernt wird die Strecke gewertet.
      recorder.onPosition(
          const GpsFix(latitude: 50.0001, longitude: 8, accuracyM: 20));
      expect(recorder.distanceM, closeTo(11.1, 0.1));
    });

    test('ungenaue Standorte werden verworfen', () {
      recorder.onPosition(at(0));
      recorder.onPosition(at(50, accuracy: 80));
      recorder.onPosition(at(1));
      expect(recorder.distanceM, closeTo(11.1, 0.1));
    });

    test('Zittern im Stand ergibt keine Strecke', () {
      for (var i = 0; i < 30; i++) {
        recorder.onPosition(GpsFix(
            latitude: 50 + (i.isEven ? 0.00001 : 0), // ±1,1 m
            longitude: 8,
            accuracyM: 5));
        second();
      }
      expect(recorder.distanceM, 0);
    });

    test('der Weg während einer Pause zählt nicht', () {
      recorder.onPosition(at(0));
      recorder.onPosition(at(1));
      recorder.pause();
      now = now.add(const Duration(minutes: 5));
      recorder.onPosition(at(40));
      recorder.resume();
      recorder.onPosition(at(41));
      recorder.onPosition(at(42));
      expect(recorder.distanceM, closeTo(22.2, 0.2));
    });

    test('ohne frischen Standort bleibt die Position im Messpunkt leer', () {
      recorder.onPosition(at(0));
      second();
      for (var i = 0; i < 10; i++) {
        second();
      }
      expect(db.samples(recorder.workoutId).first.latitude, isNotNull);
      expect(db.samples(recorder.workoutId).last.latitude, isNull);
      expect(recorder.gpsAccuracyM, isNull);
    });

    test('Anstieg zählt nur über der Rauschschwelle und nur bergauf', () {
      final heights = <double>[100, 101, 99.5, 104, 110, 108, 103, 106.5];
      for (var i = 0; i < heights.length; i++) {
        recorder.onPosition(at(i, altitude: heights[i]));
        second();
      }
      // 100 → 104 (+4), → 110 (+6), abwärts bis 103, → 106,5 (+3,5)
      expect(recorder.ascentM, 14);
      final w = recorder.finish()!;
      expect(w.ascentM, 14);
    });

    test('jeder volle Kilometer setzt von selbst eine Rundenmarke', () {
      recorder.enableAutoLap(1000);
      final laps = <Lap>[];
      for (var i = 0; i <= 200; i++) {
        recorder.onPosition(at(i)); // 11,1 m je Sekunde
        now = now.add(const Duration(seconds: 1));
        final lap = recorder.tick();
        if (lap != null) laps.add(lap);
      }
      expect(laps, hasLength(2));
      expect(laps.every((l) => l.auto), isTrue);
      expect(laps[0].distanceM, closeTo(1000, 12));
      expect(laps[1].t - laps[0].t, closeTo(90, 1));
      expect(db.laps(recorder.workoutId), hasLength(2));
    });

    test('Rundenmarken von Hand, höchstens eine je Sekunde', () {
      expect(recorder.markLap(), isNull); // noch keine Sekunde vergangen
      second();
      second();
      final lap = recorder.markLap()!;
      expect(lap.t, 2);
      expect(lap.auto, isFalse);
      expect(recorder.markLap(), isNull);
      second();
      expect(recorder.markLap(), isNotNull);
      expect(db.laps(recorder.workoutId).map((l) => l.t), [2, 3]);
    });
  });
}
