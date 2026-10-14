import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/interval/interval_models.dart';
import 'package:fitapp/programs/program_models.dart';
import 'package:fitapp/stats/stats.dart';
import 'package:fitapp/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase phone;
  late AppDatabase tablet;
  late MemorySyncStore drive;

  setUp(() {
    phone = AppDatabase.inMemory();
    tablet = AppDatabase.inMemory();
    drive = MemorySyncStore();
  });
  tearDown(() {
    phone.close();
    tablet.close();
  });

  /// Zeichnet auf [db] ein Training mit Messpunkten und einer Runde auf.
  int record(AppDatabase db, {Sport sport = Sport.running, int seconds = 30}) {
    final id = db.startWorkout(sport, DateTime(2026, 10, 11, 8));
    for (var t = 1; t <= seconds; t++) {
      db.addSample(
          id,
          Sample(
              t: t,
              heartRate: 120 + t,
              distanceM: t * 3.0,
              latitude: 50 + t * 0.0001,
              longitude: 8));
    }
    db.addLap(id, const Lap(t: 10, distanceM: 30, auto: false));
    db.finishWorkout(id, ascentM: 12);
    return id;
  }

  /// Beide Geräte gleichen ab, bis nichts mehr zu tun ist.
  Future<void> syncBoth() async {
    await synchronize(phone, drive);
    await synchronize(tablet, drive);
    await synchronize(phone, drive);
  }

  /// Zwei Änderungen in derselben Millisekunde wären nicht zu unterscheiden.
  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 3));

  test('zwei frische Geräte haben nach dem Abgleich nichts doppelt', () async {
    await syncBoth();
    for (final db in [phone, tablet]) {
      expect(db.exercises(), hasLength(213));
      expect(db.programs(), hasLength(32));
      expect(db.intervalTemplates(), hasLength(2));
    }
    final again = await synchronize(tablet, drive);
    expect(again.message, 'Alles auf dem gleichen Stand.');
  });

  test('ein Training kommt mit Messpunkten, Runden und Kennzahlen an',
      () async {
    final id = record(phone);
    phone.updateWorkout(id,
        title: 'Morgenlauf', sport: Sport.running, notes: 'frisch');
    await syncBoth();

    final w = tablet.workouts().single;
    expect(w.uuid, phone.workout(id)!.uuid);
    expect(w.title, 'Morgenlauf');
    expect(w.notes, 'frisch');
    expect(w.startedAt, DateTime(2026, 10, 11, 8));
    expect(w.durationS, 30);
    expect(w.distanceM, 90);
    expect(w.maxHeartRate, 150);
    expect(w.ascentM, 12);
    expect(tablet.samples(w.id), hasLength(30));
    expect(tablet.samples(w.id).last.latitude, closeTo(50.003, 1e-9));
    expect(tablet.laps(w.id).single.distanceM, 30);

    // Das Training gilt auf dem Tablet nicht als geändert und pendelt nicht.
    final again = await synchronize(tablet, drive);
    expect(again.sent, 0);
    expect(again.received, 0);
  });

  test('die jüngere Änderung gewinnt', () async {
    final id = record(phone);
    await syncBoth();
    final onTablet = tablet.workouts().single;

    phone.updateWorkout(id, title: 'Vom Phone', sport: Sport.running, notes: '');
    await tick();
    tablet.updateWorkout(onTablet.id,
        title: 'Vom Tablet', sport: Sport.hiking, notes: '');
    await syncBoth();

    expect(phone.workout(id)!.title, 'Vom Tablet');
    expect(phone.workout(id)!.sport, Sport.hiking);
    expect(tablet.workouts().single.title, 'Vom Tablet');
  });

  test('ein gelöschtes Training verschwindet überall und kommt nicht zurück',
      () async {
    final id = record(phone);
    await syncBoth();
    expect(tablet.workouts(), hasLength(1));

    await tick();
    phone.deleteWorkout(id);
    await syncBoth();
    expect(tablet.workouts(), isEmpty);
    expect(tablet.samples(1), isEmpty);

    // Ein drittes Gerät, das neu dazukommt, bekommt es ebenfalls nicht.
    final third = AppDatabase.inMemory();
    addTearDown(third.close);
    await synchronize(third, drive);
    expect(third.workouts(), isEmpty);
  });

  test('eine Löschmarke setzt sich auch gegen ein Gerät durch, das das '
      'Training noch hat', () async {
    final id = record(phone);
    await syncBoth();
    await tick();
    tablet.deleteWorkout(tablet.workouts().single.id);
    await synchronize(tablet, drive);
    await synchronize(phone, drive);
    expect(phone.workouts(), isEmpty);
    expect(phone.workout(id), isNotNull); // als Löschmarke noch vorhanden
  });

  test('eigene Vorlagen, Übungen und Programme wandern mit', () async {
    phone.saveIntervalTemplate(const IntervalTemplate(
      name: 'Pyramide',
      targetKind: TargetKind.speed,
      blocks: [
        IntervalBlock(repeat: 3, steps: [
          IntervalStep(label: 'Schnell', durationS: 60, target: 12),
        ]),
      ],
    ));
    final exerciseUuid = phone.newExerciseUuid();
    phone.saveExercise(Exercise(
      uuid: exerciseUuid,
      category: ExerciseCategory.crossfit,
      name: 'Schlitten',
      imagePath: '/nur/auf/dem/phone.jpg',
      areas: const [BodyArea.legs],
    ));
    phone.saveProgram(Program(
      name: 'Mein Zirkel',
      category: ExerciseCategory.crossfit,
      rounds: 3,
      items: [ProgramItem(exerciseUuid: exerciseUuid, timed: true, amount: 40)],
    ));
    await syncBoth();

    final template =
        tablet.intervalTemplates().firstWhere((t) => t.name == 'Pyramide');
    expect(template.blocks.single.repeat, 3);
    expect(template.blocks.single.steps.single.target, 12);

    final exercise = tablet.exercises().firstWhere((e) => e.name == 'Schlitten');
    expect(exercise.uuid, exerciseUuid);
    expect(exercise.areas, [BodyArea.legs]);
    // Das eigene Bild ist eine Datei auf dem Phone und bleibt dort.
    expect(exercise.imagePath, isNull);

    final program = tablet.programs().firstWhere((p) => p.name == 'Mein Zirkel');
    expect(program.items.single.exerciseUuid, exerciseUuid);
    expect(tablet.programs(), hasLength(33));
  });

  test('eine geänderte mitgelieferte Übung setzt sich gegen die unveränderte '
      'durch, egal welches Gerät neuer ist', () async {
    final onPhone =
        phone.exercises().firstWhere((e) => e.builtinKey == 'yoga_11_baum');
    phone.saveExercise(onPhone.copyWith(description: 'Meine Notiz zum Baum'));
    await syncBoth();

    final onTablet =
        tablet.exercises().firstWhere((e) => e.builtinKey == 'yoga_11_baum');
    expect(onTablet.description, 'Meine Notiz zum Baum');
    expect(tablet.exercises(), hasLength(213));
  });

  test('eine gelöschte Vorlage verschwindet auch auf dem anderen Gerät',
      () async {
    await syncBoth();
    final tabata =
        phone.intervalTemplates().firstWhere((t) => t.name.startsWith('Tabata'));
    phone.deleteIntervalTemplate(tabata.id!);
    await syncBoth();
    expect(tablet.intervalTemplates().map((t) => t.name),
        isNot(contains(tabata.name)));
  });

  test('das Profil folgt der jüngeren Angabe', () async {
    const HeartProfile(birthYear: 1986).save(phone);
    await syncBoth();
    expect(HeartProfile.load(tablet).birthYear, 1986);

    await tick();
    const HeartProfile(birthYear: 1986, manualMaxHr: 190).save(tablet);
    await syncBoth();
    expect(HeartProfile.load(phone).manualMaxHr, 190);
  });

  group('Sicherung', () {
    test('lässt sich als eine Datei weitergeben und einspielen', () async {
      record(phone);
      record(phone, sport: Sport.indoorBike, seconds: 10);
      final backup = MemorySyncStore();
      await synchronize(phone, backup);

      final restored = MemorySyncStore.fromBackup(backup.toBackup());
      final result = await synchronize(tablet, restored);
      expect(result.received, greaterThanOrEqualTo(2));
      expect(tablet.workouts().map((w) => w.sport),
          containsAll([Sport.running, Sport.indoorBike]));
    });

    test('Einspielen überschreibt nichts Neueres', () async {
      final id = record(phone);
      final backup = MemorySyncStore();
      await synchronize(phone, backup);
      await tick();
      phone.updateWorkout(id, title: 'Danach', sport: Sport.running, notes: '');

      await synchronize(phone, MemorySyncStore.fromBackup(backup.toBackup()));
      expect(phone.workout(id)!.title, 'Danach');
    });

    test('eine fremde Datei wird abgelehnt', () {
      expect(() => MemorySyncStore.fromBackup([1, 2, 3]), throwsFormatException);
    });
  });
}
