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

    test('Sit-ups beginnen liegend, die erste zählt beim Aufrichten', () {
      final c = RepCounter(RepKind.sitUp);
      var at = Duration.zero;
      void hold(bool upright) {
        for (var i = 0; i < 3; i++) {
          at += const Duration(milliseconds: 200);
          c.add(torso(upright: upright), at);
        }
      }

      hold(false);
      hold(true);
      expect(c.count, 1);
      hold(false);
      hold(true);
      expect(c.count, 2);
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
    test('alle Übungen sind vorhanden, Titel sind eindeutig', () {
      final known = {for (final e in builtinExercises) e.key};
      expect(heroWorkouts.map((w) => w.title).toSet(),
          hasLength(heroWorkouts.length));
      for (final w in heroWorkouts) {
        for (final b in w.blocks) {
          if (b.exerciseKey != null) {
            expect(known, contains(b.exerciseKey), reason: w.name);
          }
          if (b.isRun || b.isRest || b.isMax) continue;
          expect(b.reps, greaterThan(0));
        }
      }
    });

    test('zu jedem skalierten WOD gibt es das Original', () {
      final names = {
        for (final w in heroWorkouts)
          if (w.isOriginal) w.name,
      };
      for (final w in heroWorkouts.where((w) => !w.isOriginal)) {
        final base = w.name.split(',').first;
        expect(names, contains(base), reason: w.name);
        expect(w.deviations, isNotEmpty);
      }
      // Skaliert heißt nie Original, und umgekehrt.
      for (final w in heroWorkouts) {
        expect(w.name.contains(','), !w.isOriginal, reason: w.name);
      }
    });

    test('die Originale haben die richtigen Mengen', () {
      int sum(String name, String label) => heroWorkouts
          .firstWhere((w) => w.name == name)
          .blocks
          .where((b) => b.label == label)
          .fold(0, (a, b) => a + b.reps);
      expect(sum('Ryan', 'Muscle-ups'), 35);
      expect(sum('Jason', 'Muscle-ups'), 50);
      expect(sum('JT', 'Ring-Dips'), 45);
      expect(sum('Barbara', 'Kniebeugen'), 250);
      expect(sum('Angie', 'Sit-ups'), 100);
      expect(sum('Annie', 'Double-Unders'), 150);
      expect(sum('Fran', 'Thruster 43 kg'), 45);
      expect(sum('Linda', 'Bankdrücken 1 × Körpergewicht'), 55);
    });

    test('der volle Murph hat zwei Läufe und alle Wiederholungen', () {
      final m = heroWorkouts.firstWhere((w) => w.name == 'Murph');
      expect(m.blocks.first.isRun, isTrue);
      expect(m.blocks.last.isRun, isTrue);
      expect(m.runMeters, 3200);
      expect(m.totalReps, 600);
      expect(m.blocks.first.title, 'Lauf 1,6 km');
      expect(m.isOriginal, isTrue);
      expect(heroWorkouts.firstWhere((w) => w.name == 'Murph, ohne Weste')
          .deviations, ['Ohne 9-kg-Weste']);
    });

    test('Girls und Heros stehen unter eigenem Titel', () {
      final helen = heroWorkouts.firstWhere((w) => w.name.startsWith('Helen'));
      expect(helen.title, 'Girl: Helen');
      expect(heroWorkouts.first.title, 'Hero: Murph');
    });

    test('die Mengen stimmen', () {
      int sum(String name, String label) => heroWorkouts
          .firstWhere((w) => w.name == name)
          .blocks
          .where((b) => b.label == label)
          .fold(0, (a, b) => a + b.reps);
      expect(sum('Murph, halbiert', 'Klimmzüge'), 50);
      expect(sum('Murph, halbiert', 'Liegestütze'), 100);
      expect(sum('Murph, halbiert', 'Kniebeugen'), 150);
      expect(sum('JT, skaliert', 'Bank-Dips'), 45);
      expect(sum('Ryan, skaliert', 'Burpees'), 105);
      expect(sum('Jason, skaliert', 'Kniebeugen'), 250);
      expect(sum('Jason, skaliert', 'Klimmzüge'), 50);
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

    final withRun = HeroWorkout(
      name: 'Lauf',
      description: '',
      equipment: '',
      blocks: const [
        HeroBlock.run(800),
        HeroBlock('A', 'cali_05_klimmzug', 2, RepKind.pullUp),
        HeroBlock.run(800),
      ],
    );

    test('die erste Wiederholung beendet den Lauf davor', () {
      final run = HeroRun(withRun);
      expect(run.current!.isRun, isTrue);
      expect(run.countingKind, RepKind.pullUp);
      expect(run.addRep(200), HeroChange.blockDone);
      expect(run.splits.single.seconds, 200);
      expect(run.current!.label, 'A');
      // Die Wiederholung, die den Lauf beendet, zählt schon.
      expect(run.count, 1);
    });

    test('der Lauf am Ende läuft bis zum Stopp', () {
      final run = HeroRun(withRun);
      run.addRep(200);
      run.addRep(230);
      expect(run.current!.isRun, isTrue);
      expect(run.countingKind, isNull);
      expect(run.addRep(300), isNull);
      expect(run.skipBlock(500), HeroChange.finished);
      expect(run.splits.last.seconds, 270);
      expect(run.progressAt(0), 1);
    });

    test('Wiederholungen ganz am Anfang des Laufs zählen nicht', () {
      final run = HeroRun(withRun);
      expect(run.addRep(HeroRun.minRunS - 1), isNull);
      expect(run.current!.isRun, isTrue);
    });

    test('im Lauf gibt es kein Zählen von Hand', () {
      final run = HeroRun(withRun);
      expect(run.addManualRep(100), isNull);
      expect(run.count, 0);
    });

    test('eine Pause endet von selbst', () {
      final run = HeroRun(HeroWorkout(
        name: 'Pause',
        description: '',
        equipment: '',
        blocks: const [
          HeroBlock('A', null, 1, null),
          HeroBlock.rest(180),
          HeroBlock('B', null, 1, null),
        ],
      ));
      run.addManualRep(10);
      expect(run.current!.isRest, isTrue);
      expect(run.addManualRep(11), isNull);
      expect(run.tick(100), isNull);
      expect(run.tick(190), HeroChange.blockDone);
      expect(run.current!.label, 'B');
    });

    test('schaltet weiter und misst die Abschnitte', () {
      final run = HeroRun(workout);
      expect(run.addRep(5), HeroChange.counted);
      expect(run.addRep(12), HeroChange.blockDone);
      expect(run.current!.label, 'B');
      expect(run.count, 0);
      expect(run.addRep(20), HeroChange.finished);
      expect(run.finished, isTrue);
      expect(run.splits.map((s) => (s.reps, s.seconds)), [(2, 12), (1, 8)]);
      expect(run.progressAt(0), 1);
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

  group('Formate', () {
    HeroWorkout make(HeroFormat format, List<HeroBlock> blocks, {int? capS}) =>
        HeroWorkout(
          name: 'Test',
          description: '',
          equipment: '',
          format: format,
          capS: capS,
          blocks: blocks,
        );
    const a = HeroBlock('A', null, 2, null);
    const b = HeroBlock('B', null, 1, null);

    test('so viel wie möglich: Runden laufen bis zum Ablauf der Zeit', () {
      final run = HeroRun(make(HeroFormat.amrap, const [a, b], capS: 60));
      for (var i = 0; i < 4; i++) {
        run.addManualRep(i);
      }
      expect(run.rounds, 1);
      expect(run.current!.label, 'A');
      expect(run.count, 1);
      expect(run.tick(59), isNull);
      expect(run.tick(60), HeroChange.finished);
      expect(run.finished, isTrue);
      expect(run.score, '4 Wiederholungen (1 Runden + 1)');
      expect(run.progressAt(30), 0.5);
    });

    test('Minutentakt: wartet nach geschaffter Runde auf die nächste Minute',
        () {
      final run = HeroRun(make(HeroFormat.emom, const [a, b], capS: 180));
      run.addManualRep(5);
      run.addManualRep(10);
      expect(run.addManualRep(20), HeroChange.blockDone);
      expect(run.current!.isRest, isTrue);
      expect(run.restLeft(40), 20);
      expect(run.addManualRep(41), isNull);
      expect(run.tick(60), HeroChange.blockDone);
      expect(run.current!.label, 'A');
      expect(run.rounds, 1);
    });

    test('Minutentakt: endet mit der ersten nicht geschafften Minute', () {
      final run = HeroRun(make(HeroFormat.emom, const [a, b], capS: 180));
      run.addManualRep(5);
      expect(run.tick(60), HeroChange.finished);
      expect(run.score, '0 Runden');
    });

    test('Maximalwerte: Serien enden von Hand und zählen zusammen', () {
      final run = HeroRun(make(HeroFormat.maxReps, const [
        HeroBlock.max('A', null, null),
        HeroBlock.max('B', null, null),
      ]));
      for (var i = 0; i < 30; i++) {
        expect(run.addManualRep(i), HeroChange.counted);
      }
      expect(run.skipBlock(40), HeroChange.blockDone);
      run.addManualRep(41);
      expect(run.skipBlock(50), HeroChange.finished);
      expect(run.score, '31 Wiederholungen');
    });

    test('Nicole: die Klimmzüge beenden den Lauf, und die Runden wiederholen',
        () {
      final nicole = heroWorkouts.firstWhere((w) => w.name == 'Nicole');
      final run = HeroRun(nicole);
      expect(run.countingKind, RepKind.pullUp);
      expect(run.addRep(120), HeroChange.blockDone);
      expect(run.current!.isMax, isTrue);
      expect(run.count, 1);
      expect(run.skipBlock(140), HeroChange.blockDone);
      expect(run.current!.isRun, isTrue);
      expect(run.rounds, 1);
      expect(run.tick(1200), HeroChange.finished);
      expect(run.splits.last.block.isRun, isTrue);
      expect(run.score, '1 Wiederholungen');
    });

    test('das Original von Cindy und Chelsea stimmt', () {
      final cindy = heroWorkouts.firstWhere((w) => w.name == 'Cindy');
      expect(cindy.capS, 1200);
      expect(cindy.blocks.map((b) => b.reps), [5, 10, 15]);
      final chelsea = heroWorkouts.firstWhere((w) => w.name == 'Chelsea');
      expect(chelsea.format, HeroFormat.emom);
      expect(chelsea.capS, 1800);
    });

    test('der Bestwert steht in der Notiz und gilt nur für Beendetes', () {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final cindy = heroWorkouts.firstWhere((w) => w.name == 'Cindy');
      void save(String title, String notes) {
        final id = db.startWorkout(Sport.crossfit, DateTime(2026, 10, 30, 9));
        db.addSample(id, const Sample(t: 1));
        db.finishWorkout(id);
        db.updateWorkout(id, title: title, sport: Sport.crossfit, notes: notes);
      }

      expect(heroBestLabel(db, cindy), isNull);
      save(cindy.title, 'Ergebnis: 120 Wiederholungen (4 Runden + 0)');
      save(cindy.title, 'Ergebnis: 95 Wiederholungen (3 Runden + 5)');
      save(cindy.abortedTitle, 'Ergebnis: 500 Wiederholungen');
      expect(heroBestScore(db, cindy), 120);
      expect(heroBestLabel(db, cindy), 'Bestwert 120 Wiederholungen');
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
