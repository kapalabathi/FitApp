import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/programs/builtin_exercises.dart';
import 'package:fitapp/ui/hero_pages.dart';
import 'package:fitapp/vision/hero_workouts.dart';
import 'package:fitapp/vision/pose_smoother.dart';
import 'package:fitapp/vision/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Eine Haltung, bei der Arm und Bein den Winkel [degrees] bilden.
BodyPose bent(double degrees, {double likelihood = 0.9}) {
  // Gelenk im Ursprung, ein Arm nach rechts, der andere um den Winkel gedreht.
  final rad = degrees * 3.141592653589793 / 180;
  PosePoint outer() => PosePoint(100 * _cos(rad), 100 * _sin(rad), likelihood);
  final middle = PosePoint(0, 0, likelihood);
  final first = PosePoint(100, 0, likelihood);
  return {
    Joint.leftShoulder: first,
    Joint.leftElbow: middle,
    Joint.leftWrist: outer(),
    Joint.leftHip: first,
    Joint.leftKnee: middle,
    Joint.leftAnkle: outer(),
  };
}

double _cos(double x) {
  var term = 1.0, sum = 1.0;
  for (var i = 1; i < 20; i++) {
    term *= -x * x / ((2 * i - 1) * (2 * i));
    sum += term;
  }
  return sum;
}

double _sin(double x) {
  var term = x, sum = x;
  for (var i = 1; i < 20; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    sum += term;
  }
  return sum;
}

BodyPose torso({required bool upright}) => upright
    ? const {
        Joint.leftShoulder: PosePoint(100, 100, 0.9),
        Joint.leftHip: PosePoint(100, 300, 0.9),
      }
    : const {
        Joint.leftShoulder: PosePoint(100, 300, 0.9),
        Joint.leftHip: PosePoint(300, 310, 0.9),
      };

void main() {
  /// Spielt eine Folge von Winkeln ab, je Wert drei Bilder im Abstand 100 ms.
  var t = Duration.zero;
  int play(RepCounter counter, List<double> angles) {
    for (final a in angles) {
      for (var i = 0; i < 3; i++) {
        t += const Duration(milliseconds: 100);
        counter.add(bent(a), t);
      }
    }
    return counter.count;
  }

  group('Wiederholungen zählen', () {
    test('misst den Winkel an einem Gelenk', () {
      const a = PosePoint(1, 0, 1);
      const b = PosePoint(0, 0, 1);
      const c = PosePoint(0, 1, 1);
      expect(RepCounter.angleAt(a, b, c), closeTo(90, 0.001));
    });

    test('zählt eine Wiederholung erst nach hoch, tief und wieder hoch', () {
      final c = RepCounter(RepKind.squat);
      expect(play(c, [170, 90]), 0);
      expect(play(c, [170]), 1);
      expect(play(c, [90, 170, 90, 170]), 3);
    });

    test('halbe Bewegungen zählen nicht', () {
      expect(play(RepCounter(RepKind.squat), [170, 130, 170, 130, 170]), 0);
    });

    test('beginnt erst nach dem ersten Mal oben', () {
      expect(play(RepCounter(RepKind.pushUp), [90, 170]), 0);
    });

    test('ein einzelner Ausreißer zählt nicht', () {
      final c = RepCounter(RepKind.pushUp);
      var t = Duration.zero;
      void frame(double a) {
        t += const Duration(milliseconds: 100);
        c.add(bent(a), t);
      }

      for (final a in const <double>[170, 170, 170, 90, 170, 170, 170]) {
        frame(a);
      }
      expect(c.count, 0);
    });

    test('unsicher erkannte Gelenke werden ignoriert', () {
      final c = RepCounter(RepKind.squat);
      c.add(bent(170, likelihood: 0.2), Duration.zero);
      expect(c.tracking, isFalse);
      expect(c.angle, isNull);
      c.add(bent(170), Duration.zero);
      expect(c.tracking, isTrue);
    });

    test('kurze Aussetzer lassen die Erkennung nicht flackern', () {
      final c = RepCounter(RepKind.squat);
      c.add(bent(170), Duration.zero);
      c.add(const {}, const Duration(milliseconds: 800));
      expect(c.tracking, isTrue);
      c.add(const {}, const Duration(milliseconds: 1200));
      expect(c.tracking, isFalse);
    });

    test('Burpees zählen über die Lage des Oberkörpers', () {
      final c = RepCounter(RepKind.burpee);
      var t = Duration.zero;
      void hold(bool upright) {
        for (var i = 0; i < 3; i++) {
          t += const Duration(milliseconds: 200);
          c.add(torso(upright: upright), t);
        }
      }

      hold(true);
      hold(false);
      hold(true);
      hold(false);
      hold(true);
      expect(c.count, 2);
    });
  });

  group('Ruhiges Gerüst', () {
    const scale = 1000.0;
    BodyPose at(double x, {double likelihood = 0.9}) =>
        {Joint.leftWrist: PosePoint(x, 100, likelihood)};
    Duration ms(int v) => Duration(milliseconds: v);

    test('kleines Zittern wird stark gedämpft', () {
      final s = PoseSmoother();
      s.update(at(100), ms(0), scale);
      final out = s.update(at(105), ms(100), scale);
      expect(out[Joint.leftWrist]!.x, lessThan(102.5));
    });

    test('große Bewegungen folgen sofort', () {
      final s = PoseSmoother();
      s.update(at(100), ms(0), scale);
      final out = s.update(at(300), ms(100), scale);
      expect(out[Joint.leftWrist]!.x, closeTo(300, 0.01));
    });

    test('kurze Lücken bleiben stehen, lange lassen das Gelenk verschwinden',
        () {
      final s = PoseSmoother();
      s.update(at(100), ms(0), scale);
      expect(s.update(const {}, ms(600), scale)[Joint.leftWrist], isNotNull);
      expect(s.update(const {}, ms(800), scale)[Joint.leftWrist], isNull);
    });

    test('um die Schwelle herum flackert nichts', () {
      final s = PoseSmoother();
      // Unsicher: erscheint nicht
      expect(s.update(at(100, likelihood: 0.4), ms(0), scale), isEmpty);
      s.update(at(100), ms(100), scale);
      // Sichtbar: bleibt trotz gleicher Unsicherheit
      expect(s.update(at(100, likelihood: 0.4), ms(200), scale), isNotEmpty);
    });

    test('nach dem Zurücksetzen ist nichts mehr da', () {
      final s = PoseSmoother();
      s.update(at(100), ms(0), scale);
      s.reset();
      expect(s.update(const {}, ms(10), scale), isEmpty);
    });
  });

  group('Workouts', () {
    test('es gibt vier, und alle Übungen sind vorhanden', () {
      final known = {for (final e in builtinExercises) e.key};
      expect(heroWorkouts, hasLength(4));
      for (final w in heroWorkouts) {
        for (final b in w.blocks) {
          expect(known, contains(b.exerciseKey), reason: w.name);
          expect(b.reps, greaterThan(0));
        }
      }
    });

    test('die Mengen stimmen', () {
      int sum(String name, String label) => heroWorkouts
          .firstWhere((w) => w.name.startsWith(name))
          .blocks
          .where((b) => b.label == label)
          .fold(0, (a, b) => a + b.reps);
      expect(sum('Murph', 'Klimmzüge'), 50);
      expect(sum('Murph', 'Liegestütze'), 100);
      expect(sum('Murph', 'Kniebeugen'), 150);
      expect(sum('JT', 'Bank-Dips'), 45);
      expect(sum('Ryan', 'Burpees'), 105);
      expect(sum('Jason', 'Kniebeugen'), 250);
      expect(sum('Jason', 'Klimmzüge'), 50);
    });
  });

  group('Ablauf', () {
    final workout = HeroWorkout(
      name: 'Test',
      description: '',
      equipment: '',
      blocks: const [
        HeroBlock('A', 'cali_05_klimmzug', 2, RepKind.pullUp),
        HeroBlock('B', 'cali_01_liegestuetz', 1, RepKind.pushUp),
      ],
    );

    test('schaltet weiter und misst die Abschnitte', () {
      final run = HeroRun(workout);
      expect(run.addRep(5), HeroChange.counted);
      expect(run.addRep(12), HeroChange.blockDone);
      expect(run.current!.label, 'B');
      expect(run.count, 0);
      expect(run.addRep(20), HeroChange.finished);
      expect(run.finished, isTrue);
      expect(run.splits.map((s) => (s.reps, s.seconds)), [(2, 12), (1, 8)]);
      expect(run.progress, 1);
    });

    test('lässt sich von Hand korrigieren', () {
      final run = HeroRun(workout);
      run.addRep(1);
      run.removeRep();
      run.removeRep();
      expect(run.count, 0);
      run.addRep(2);
      expect(run.skipBlock(9), HeroChange.blockDone);
      expect(run.splits.single.reps, 1);
    });
  });

  test('als Bestzeit zählen nur beendete Workouts', () {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final w = heroWorkouts.first;
    int save(int seconds, String title) {
      final id = db.startWorkout(Sport.crossfit, DateTime(2026, 10, 30, 9));
      for (var t = 1; t <= seconds; t++) {
        db.addSample(id, Sample(t: t));
      }
      db.finishWorkout(id);
      db.updateWorkout(id, title: title, sport: Sport.crossfit, notes: '');
      return id;
    }

    expect(heroBestTime(db, w), isNull);
    save(120, w.title);
    save(90, w.title);
    save(10, w.abortedTitle);
    expect(heroBestTime(db, w), 90);
  });
}
