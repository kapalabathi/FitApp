import 'package:fitapp/breath/breath_models.dart';
import 'package:fitapp/breath/breath_run.dart';
import 'package:fitapp/data/database.dart';
import 'package:fitapp/programs/builtin_exercises.dart';
import 'package:fitapp/programs/builtin_programs.dart';
import 'package:fitapp/programs/courses.dart';
import 'package:fitapp/programs/program_models.dart';
import 'package:fitapp/programs/program_run.dart';
import 'package:fitapp/session/workout_session.dart';
import 'package:fitapp/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Exercise exercise(String key) =>
      db.exercises().firstWhere((e) => e.builtinKey == key);

  group('Mitgelieferte Übungen', () {
    final byKey = {for (final e in builtinExercises) e.key: e};

    test('Varianten verweisen gegenseitig aufeinander', () {
      for (final e in builtinExercises) {
        if (e.harderKey case final harder?) {
          expect(byKey[harder]?.easierKey, e.key, reason: e.key);
        }
        if (e.easierKey case final easier?) {
          expect(byKey[easier]?.harderKey, e.key, reason: e.key);
        }
      }
    });

    test('jede Übung hat eine Schwierigkeit, jede Yoga-Haltung eine Gruppe',
        () {
      for (final e in builtinExercises) {
        expect(e.level, inInclusiveRange(1, 3), reason: e.key);
        if (e.category == ExerciseCategory.yoga) {
          expect(e.poseGroup, isNotNull, reason: e.key);
          expect(e.sanskrit, isNotEmpty, reason: e.key);
        }
      }
    });

    test('die Angaben kommen in der Datenbank an', () {
      final dreieck = exercise('yoga_10_dreieck');
      expect(dreieck.sanskrit, 'Trikonasana');
      expect(dreieck.sanskritExtra, isNull, reason: 'steht schon im Namen');
      expect(dreieck.poseGroup, PoseGroup.standing);
      expect(dreieck.level, 2);
      expect(dreieck.bothSides, isTrue);
      expect(dreieck.harderUuid, 'builtin-yoga_28_halbmond');
      final kamel = exercise('yoga_33_kamel');
      expect(kamel.sanskritExtra, 'Ustrasana');
      expect(kamel.caution, isNotEmpty);
    });

    test('eigene Angaben werden gespeichert', () {
      final id = db.saveExercise(Exercise(
        uuid: db.newExerciseUuid(),
        category: ExerciseCategory.yoga,
        name: 'Seitstütz am Knie',
        sanskrit: 'Vasisthasana (Vorstufe)',
        poseGroup: PoseGroup.armSupport,
        level: 1,
        bothSides: true,
        caution: 'Handgelenke aufwärmen.',
        harderUuid: 'builtin-cali_11_seitstuetz',
      ));
      final saved = db.exercises().firstWhere((e) => e.id == id);
      expect(saved.sanskrit, 'Vasisthasana (Vorstufe)');
      expect(saved.poseGroup, PoseGroup.armSupport);
      expect(saved.level, 1);
      expect(saved.bothSides, isTrue);
      expect(saved.caution, 'Handgelenke aufwärmen.');
      expect(saved.harderUuid, 'builtin-cali_11_seitstuetz');
      expect(saved.easierUuid, isNull);
    });

    test('die Angaben wandern bei der Synchronisation mit', () async {
      final other = AppDatabase.inMemory();
      addTearDown(other.close);
      final store = MemorySyncStore();
      db.saveExercise(exercise('yoga_11_baum')
          .copyWith(level: 3, caution: 'Wand in der Nähe.'));
      await synchronize(db, store);
      await synchronize(other, store);
      final there =
          other.exercises().firstWhere((e) => e.builtinKey == 'yoga_11_baum');
      expect(there.level, 3);
      expect(there.caution, 'Wand in der Nähe.');
      expect(there.bothSides, isTrue);
    });

    test('eine Sicherung aus einer älteren Fassung lässt sich einspielen', () {
      // Ohne die neuen Spalten, wie in einer Sicherung von Version 0.10
      final applied = db.applySyncRow('exercises', {
        'uuid': 'alt-1',
        'updated_at': 5,
        'deleted': 0,
        'category': 'yoga',
        'name': 'Alte Übung',
        'description': '',
        'builtin_key': null,
        'timed': 1,
        'areas': '',
      });
      expect(applied, isTrue);
      final e = db.exercises().firstWhere((e) => e.uuid == 'alt-1');
      expect(e.level, 0);
      expect(e.bothSides, isFalse);
      expect(e.sanskrit, isEmpty);
    });
  });

  group('Datenbank-Fassung 10', () {
    test('ältere Installationen bekommen Angaben und neue Programme', () {
      final raw = sqlite3.openInMemory();
      AppDatabase(raw);
      // Zustand vor Fassung 10 nachstellen
      for (final c in [
        'sanskrit',
        'pose_group',
        'level',
        'both_sides',
        'caution',
        'easier_uuid',
        'harder_uuid',
      ]) {
        raw.execute('ALTER TABLE exercises DROP COLUMN $c');
      }
      const oldItems = '[{"exercise":"builtin-yoga_11_baum","timed":true,'
          '"amount":30,"rest":5}]';
      raw.execute(
          "UPDATE programs SET rounds = 2, items = ? "
          "WHERE uuid = 'builtin-program:Yoga: Balance'",
          [oldItems]);
      // Ein vom Nutzer geändertes Programm bleibt, wie es ist.
      raw.execute(
          "UPDATE programs SET rounds = 2, items = ?, updated_at = 99 "
          "WHERE uuid = 'builtin-program:Yoga: Hüftöffner'",
          [oldItems]);
      raw.execute('PRAGMA user_version = 9');

      final upgraded = AppDatabase(raw);
      addTearDown(upgraded.close);
      expect(
          upgraded
              .exercises()
              .firstWhere((e) => e.builtinKey == 'yoga_10_dreieck')
              .poseGroup,
          PoseGroup.standing);
      final balance =
          upgraded.programs().firstWhere((p) => p.name == 'Yoga: Balance');
      expect(balance.rounds, 1);
      expect(balance.items.first.bothSides, isTrue);
      final hips =
          upgraded.programs().firstWhere((p) => p.name == 'Yoga: Hüftöffner');
      expect(hips.rounds, 2);
      expect(hips.items.single.bothSides, isFalse);
    });

    test('Fassung 11 bringt die Umkehrhaltungen nachträglich', () {
      final raw = sqlite3.openInMemory();
      AppDatabase(raw);
      raw.execute("DELETE FROM exercises WHERE builtin_key LIKE 'yoga_4%' "
          "AND builtin_key > 'yoga_40'");
      raw.execute("UPDATE exercises SET harder_uuid = NULL "
          "WHERE uuid = 'builtin-yoga_35_delfin'");
      raw.execute('PRAGMA user_version = 10');

      final upgraded = AppDatabase(raw);
      addTearDown(upgraded.close);
      final byKey = {
        for (final e in upgraded.exercises()) e.builtinKey: e,
      };
      for (final key in [
        'yoga_41_pflug',
        'yoga_42_schulterstand',
        'yoga_43_unterarmstand_wand',
        'yoga_44_kopfstand',
      ]) {
        expect(byKey[key]?.poseGroup, PoseGroup.inversion, reason: key);
        expect(byKey[key]!.caution, isNotEmpty);
        expect(byKey[key]!.areas, isNotEmpty);
      }
      expect(byKey['yoga_35_delfin']!.harderUuid, 'builtin-yoga_44_kopfstand');
      expect(byKey['yoga_44_kopfstand']!.easierUuid, 'builtin-yoga_35_delfin');
    });

    test('Fassung 12 bringt 48 Übungen, Varianten und sechs Programme', () {
      final raw = sqlite3.openInMemory();
      AppDatabase(raw);
      // Zustand von Fassung 11 nachstellen
      raw.execute("DELETE FROM exercises WHERE builtin_key IN "
          "('yoga_45_fisch', 'yoga_54_welpe', 'cali_47_negativer_klimmzug')");
      raw.execute("UPDATE exercises SET harder_uuid = NULL "
          "WHERE uuid = 'builtin-yoga_05_kindhaltung'");
      // Eine eigene Variante des Nutzers bleibt erhalten.
      raw.execute("UPDATE exercises SET harder_uuid = 'eigene', "
          "updated_at = 99 WHERE uuid = 'builtin-yoga_16_boot'");
      raw.execute("DELETE FROM programs WHERE uuid LIKE "
          "'builtin-program:Calisthenics: Weg%'");
      raw.execute('PRAGMA user_version = 11');

      final upgraded = AppDatabase(raw);
      addTearDown(upgraded.close);
      final byKey = {
        for (final e in upgraded.exercises()) e.builtinKey: e,
      };
      expect(byKey, hasLength(213));
      expect(byKey['yoga_45_fisch']!.poseGroup, PoseGroup.backbend);
      expect(byKey['yoga_45_fisch']!.areas, isNotEmpty);
      expect(byKey['yoga_05_kindhaltung']!.harderUuid,
          'builtin-yoga_54_welpe');
      expect(byKey['yoga_16_boot']!.harderUuid, 'eigene');
      expect(
          upgraded.programs().map((p) => p.name),
          containsAll([
            'Calisthenics: Weg zum Klimmzug',
            'Calisthenics: Weg zu Liegestütz und Dip',
            'Yoga: Nach dem Laufen',
          ]));
    });

    test('Fassung 14 bringt das Glühwürmchen', () {
      final raw = sqlite3.openInMemory();
      AppDatabase(raw);
      raw.execute(
          "DELETE FROM exercises WHERE builtin_key = 'yoga_70_gluehwuermchen'");
      raw.execute("UPDATE exercises SET harder_uuid = NULL "
          "WHERE uuid = 'builtin-cali_20_kraehe'");
      raw.execute('PRAGMA user_version = 13');
      final upgraded = AppDatabase(raw);
      addTearDown(upgraded.close);
      final byKey = {for (final e in upgraded.exercises()) e.builtinKey: e};
      expect(byKey['yoga_70_gluehwuermchen']!.poseGroup, PoseGroup.armSupport);
      expect(byKey['yoga_70_gluehwuermchen']!.areas, isNotEmpty);
      expect(byKey['cali_20_kraehe']!.harderUuid,
          'builtin-yoga_70_gluehwuermchen');
    });

    test('mitgelieferte Programme üben einseitige Haltungen beidseitig', () {
      final kopfKnie = db
          .programs()
          .firstWhere((p) => p.name == 'Yoga: Abendruhe')
          .items
          .where((i) => i.exerciseUuid == 'builtin-yoga_37_kopf_zu_knie');
      expect(kopfKnie.single.bothSides, isTrue);
    });
  });

  group('Beide Seiten', () {
    test('rechts, Seitenwechsel, links, dann die Pause', () {
      final baum = exercise('yoga_11_baum');
      final berg = exercise('yoga_01_berghaltung');
      final run = ProgramRun(
        Program(name: 'Test', category: ExerciseCategory.yoga, items: [
          ProgramItem(
              exerciseUuid: baum.uuid,
              timed: true,
              amount: 20,
              restS: 10,
              bothSides: true),
          ProgramItem(exerciseUuid: berg.uuid, timed: true, amount: 30),
        ]),
        {baum.uuid: baum, berg.uuid: berg},
      );
      expect(
        run.phases.map((p) => (
              p.exercise.name,
              p.isRest,
              p.side,
              p.durationS,
            )),
        [
          ('Baum', false, Side.right, 20),
          ('Baum', true, Side.left, ProgramItem.sideSwitchS),
          ('Baum', false, Side.left, 20),
          ('Berghaltung (Tadasana)', true, null, 10),
          ('Berghaltung (Tadasana)', false, null, 30),
        ],
      );
      expect(run.phases.map(programAnnouncement).take(3), [
        'Baum, rechte Seite, 20 Sekunden',
        'Seite wechseln',
        'Linke Seite, 20 Sekunden',
      ]);
    });

    test('Dauer und Anzeige zählen beide Seiten', () {
      const item = ProgramItem(
          exerciseUuid: 'x', timed: true, amount: 30, restS: 5, bothSides: true);
      expect(item.timedSeconds, 30 + ProgramItem.sideSwitchS + 30 + 5);
      expect(item.amountLabel, '30 s je Seite');
    });

    test('ältere Programme ohne Angabe gelten als einseitig', () {
      final item = ProgramItem.fromJson(
          {'exercise': 'x', 'timed': true, 'amount': 30, 'rest': 5});
      expect(item.bothSides, isFalse);
      final again = ProgramItem.fromJson(
          const ProgramItem(
                  exerciseUuid: 'x', timed: true, amount: 3, bothSides: true)
              .toJson());
      expect(again.bothSides, isTrue);
    });
  });

  group('Atemübungen', () {
    final box = breathExerciseByKey('kastenatmung')!;

    List<String> play(BreathRun run) {
      final out = <String>[];
      void note(List<BreathEvent> events) {
        for (final e in events) {
          out.add(switch (e) {
            BreathStepStarted(:final step, :final cycle) =>
              '$cycle ${step.label} ${step.seconds}',
            BreathFinished() => 'Ende',
          });
        }
      }

      note(run.start());
      while (!run.finished) {
        note(run.tick());
      }
      return out;
    }

    test('ohne Freischaltung entfällt das Anhalten', () {
      final run = BreathRun(box, minutes: 1);
      expect(run.steps.map((s) => s.action),
          [BreathAction.inhale, BreathAction.exhale]);
      // 60 s zu je 8 s ergeben 7,5 Zyklen, gerundet 8
      expect(run.cycles, 8);
      expect(play(run).take(3), ['1 Einatmen 4', '1 Ausatmen 4', '2 Einatmen 4']);
    });

    test('freigeschaltet mit Halten, bis die Zeit um ist', () {
      final run = BreathRun(box, minutes: 1, holdsAllowed: true);
      final events = play(run);
      expect(run.cycles, 4);
      expect(events.take(4), [
        '1 Einatmen 4',
        '1 Halten 4',
        '1 Ausatmen 4',
        '1 Leer halten 4',
      ]);
      expect(events.last, 'Ende');
      expect(events, hasLength(4 * 4 + 1));
      expect(run.remainingSeconds, 0);
    });

    test('kurze Pausen der gestuften Atmung bleiben immer erhalten', () {
      final viloma = breathExerciseByKey('gestuft')!;
      expect(viloma.hasLongHolds, isFalse);
      expect(viloma.cycleWithHolds(false), viloma.cycle);
    });

    test('die Wechselatmung nennt die Nasenseite', () {
      final run = BreathRun(breathExerciseByKey('wechselatmung')!, minutes: 1);
      expect(play(run).take(4), [
        '1 Einatmen links 4',
        '1 Ausatmen rechts 6',
        '1 Einatmen rechts 4',
        '1 Ausatmen links 6',
      ]);
    });

    test('schnelle Atmung: Ton je Stoß, nur der Beginn wird angesagt', () {
      final run = BreathRun(breathExerciseByKey('feueratem')!, minutes: 2);
      final events = <BreathStepStarted>[];
      for (final e in [...run.start(), for (var i = 0; i < 50; i++) ...run.tick()]) {
        if (e is BreathStepStarted) events.add(e);
      }
      expect(events.first.rapid, isTrue);
      expect(events.first.startsRapid, isTrue);
      expect(events[1].startsRapid, isFalse);
      expect(events[20].step.action, BreathAction.rest);
      expect(events[20].rapid, isFalse);
      expect(events[21].startsRapid, isTrue);
    });

    test('jede Atemübung hat einen sinnvollen Rhythmus', () {
      for (final b in builtinBreathExercises) {
        expect(b.cycleSeconds, greaterThan(0), reason: b.key);
        expect(b.rhythm(), isNotEmpty, reason: b.key);
        if (b.level == 3) expect(b.caution, isNotEmpty, reason: b.key);
      }
      expect(breathExerciseByKey('ujjayi')!.rhythm(), 'Ein 5 s · Aus 5 s');
      expect(breathExerciseByKey('feueratem')!.rhythm(),
          '20 schnelle Atemzüge, dann 30 s ruhig atmen');
    });
  });

  group('Yoga-Grundkurs', () {
    final course = yogaBasicCourse;
    final builtinUuids = {for (final e in builtinExercises) e.uuid};

    test('alle Haltungen und Atemübungen gibt es', () {
      for (final stage in course.stages) {
        expect(stage.sessions, hasLength(course.sessionsPerWeek));
        for (final s in stage.sessions) {
          for (final item in s.items) {
            expect(builtinUuids, contains(item.exerciseUuid),
                reason: '${stage.title} ${s.title}');
            expect(item.amount, greaterThan(0));
          }
          expect(breathExerciseByKey(s.breathKey!), isNotNull);
          // Jede Einheit endet in der Totenstellung.
          expect(s.items.last.exerciseUuid, 'builtin-yoga_20_totenstellung');
        }
      }
      expect(course.totalWeeks, 12);
    });

    test('die Einheiten werden länger, bleiben aber unter einer Stunde', () {
      int minutes(int stage) =>
          course.program(stage, 0).timedSeconds ~/ 60;
      for (var stage = 0; stage < course.stages.length; stage++) {
        for (var s = 0; s < 3; s++) {
          final m = course.program(stage, s).timedSeconds ~/ 60;
          expect(m, inInclusiveRange(8, 60), reason: 'Stufe $stage, Tag $s');
        }
      }
      expect(minutes(5), greaterThan(minutes(0)));
    });

    test('der Fortschritt läuft reihum und schlägt die nächste Stufe vor', () {
      var p = CourseProgress.load(db, course);
      expect(p.started, isFalse);
      expect(p.nextSession(course), 0);
      for (var i = 0; i < 5; i++) {
        p = p.sessionDone();
      }
      expect(p.nextSession(course), 2);
      expect(p.stageComplete(course), isFalse);
      p = p.sessionDone();
      expect(p.stageComplete(course), isTrue);
      p.save(db, course);

      final loaded = CourseProgress.load(db, course);
      expect(loaded.done, 6);
      expect(loaded.updatedAt, greaterThan(0));
      final next = loaded.toStage(course, loaded.stage + 1);
      expect((next.stage, next.done), (1, 0));
      expect(loaded.toStage(course, 99).stage, course.stages.length - 1);
    });

    test('der Fortschritt wandert zwischen den Geräten', () async {
      final other = AppDatabase.inMemory();
      addTearDown(other.close);
      final store = MemorySyncStore();
      const CourseProgress(stage: 2, done: 4).save(db, course);
      await synchronize(db, store);
      await synchronize(other, store);
      final there = CourseProgress.load(other, course);
      expect((there.stage, there.done), (2, 4));

      // Der jüngere Stand setzt sich durch.
      const CourseProgress(stage: 2, done: 5)
          .save(other, course, updatedAt: there.updatedAt + 1000);
      await synchronize(other, store);
      await synchronize(db, store);
      expect(CourseProgress.load(db, course).done, 5);
    });

    test('ab Stufe 2 Schulterstand und Pflug vor der Entspannung', () {
      const stand = 'builtin-yoga_42_schulterstand';
      const plough = 'builtin-yoga_41_pflug';
      for (var stage = 0; stage < course.stages.length; stage++) {
        for (final s in course.stages[stage].sessions) {
          final uuids = s.items.map((i) => i.exerciseUuid).toList();
          if (stage == 0) {
            expect(uuids, isNot(contains(stand)));
            expect(uuids[uuids.length - 2], 'builtin-yoga_46_beine_an_der_wand');
            continue;
          }
          final i = uuids.indexOf(stand);
          expect(i, greaterThan(0), reason: 'Stufe ${stage + 1} ${s.title}');
          // Danach Pflug und Fisch als Ausgleich, dann die Entspannung
          final rest = uuids.sublist(i);
          expect(rest, contains(plough));
          expect(rest.indexOf('builtin-yoga_45_fisch'),
              greaterThan(rest.indexOf(plough)));
          expect(rest.length, lessThanOrEqualTo(7));
        }
      }
      // Kopf- und Unterarmstand gehören nicht zum Grundkurs.
      final all = [
        for (final st in course.stages)
          for (final s in st.sessions) ...s.items.map((i) => i.exerciseUuid),
      ];
      expect(all, isNot(contains('builtin-yoga_44_kopfstand')));
      expect(all, isNot(contains('builtin-yoga_43_unterarmstand_wand')));
    });

    test('der Sonnengruß des Kurses ist der mitgelieferte', () {
      final first = course.stages[2].sessions[0].items;
      expect(first.take(sunSalutation.length).map((i) => i.exerciseUuid),
          sunSalutation.map((i) => i.exerciseUuid));
    });
  });
}
