import 'package:fitapp/ble/device_kind.dart';
import 'package:fitapp/ble/device_probe.dart';
import 'package:fitapp/ble/link_monitor.dart';
import 'package:fitapp/ble/uuids.dart';
import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/programs/program_models.dart';
import 'package:fitapp/programs/program_run.dart';
import 'package:fitapp/stats/compare.dart';
import 'package:fitapp/stats/stats.dart';
import 'package:fitapp/ui/compare_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  group('Geräteerkennung', () {
    test('der Name allein macht ein Gerät zum vermuteten Fitnessgerät', () {
      expect(DeviceKind.detect('Technogym Run', const []),
          DeviceKind.likelyMachine);
      expect(DeviceKind.detect('MATRIX T50', const []),
          DeviceKind.likelyMachine);
      expect(DeviceKind.detect('Spin Bike 3', const []),
          DeviceKind.likelyMachine);
      expect(DeviceKind.detect("Peters Kopfhörer", const []),
          DeviceKind.unknown);
    });

    test('ein bekannter Dienst schlägt den Namen', () {
      expect(DeviceKind.detect('Technogym', [Uuids.full(Uuids.ftmsService)]),
          DeviceKind.fitnessMachine);
    });

    test('die Prüfung ordnet ein Gerät über seine Dienste ein', () {
      final ftms = ProbeResult(services: [Uuids.full(Uuids.ftmsService)]);
      expect(ftms.supported, isTrue);
      expect(ftms.kind('Gym 7'), DeviceKind.fitnessMachine);
      const other = ProbeResult(services: ['1234']);
      expect(other.supported, isFalse);
      const failed = ProbeResult(error: 'Zeitüberschreitung');
      expect(failed.connected, isFalse);
      expect(failed.supported, isFalse);
    });
  });

  group('Verbindung', () {
    test('sucht erst nach drei Fehlversuchen', () {
      expect(scanBeforeReconnect(0), isFalse);
      expect(scanBeforeReconnect(1), isFalse);
      expect(scanBeforeReconnect(2), isFalse);
      expect(scanBeforeReconnect(3), isTrue);
      expect(scanBeforeReconnect(4), isFalse);
      expect(scanBeforeReconnect(6), isTrue);
    });

    test('nach einem Abbruch wird nur kurz gewartet', () {
      expect(reconnectDelay(0), lessThan(const Duration(seconds: 1)));
      expect(reconnectDelay(1), const Duration(seconds: 3));
    });

    test('verstummt gilt nur ohne Antworten und ohne Daten', () {
      var now = DateTime(2026, 11, 1, 12);
      final watch = LinkWatch(now: () => now);
      watch.answered(false);
      watch.answered(false);
      expect(watch.stale, isFalse, reason: 'erst seit eben still');
      now = now.add(LinkWatch.silence);
      expect(watch.stale, isTrue);
      watch.sawData();
      expect(watch.stale, isFalse, reason: 'Messwerte kommen an');
      now = now.add(LinkWatch.silence);
      watch.answered(true);
      expect(watch.stale, isFalse, reason: 'das Gerät hat geantwortet');
    });

    test('der Grund der App ist übersetzt', () {
      expect(linkReasonLabel(linkSilentReason), contains('keine Daten'));
    });
  });

  group('Atemzüge', () {
    const item = ProgramItem(
      exerciseUuid: 'a',
      timed: true,
      amount: 5,
      breaths: true,
      bothSides: true,
      restS: 10,
    );

    test('zählen als Dauer und in der Beschriftung', () {
      expect(item.holdSeconds, 5 * ProgramItem.breathS);
      expect(item.amountLabel, '5 Atemzüge je Seite');
      expect(item.timedSeconds,
          2 * 5 * ProgramItem.breathS + ProgramItem.sideSwitchS + 10);
    });

    test('bleiben beim Speichern erhalten', () {
      expect(ProgramItem.fromJson(item.toJson()).breaths, isTrue);
      const old = ProgramItem(exerciseUuid: 'a', timed: true, amount: 30);
      expect(old.toJson().containsKey('breaths'), isFalse);
    });

    test('die Phase endet nach der Dauer und zählt abwärts', () {
      const exercise = Exercise(
          uuid: 'a', category: ExerciseCategory.yoga, name: 'Baum');
      final run = ProgramRun(
        const Program(
          name: 'Test',
          category: ExerciseCategory.yoga,
          items: [
            ProgramItem(
                exerciseUuid: 'a', timed: true, amount: 2, breaths: true),
          ],
        ),
        const {'a': exercise},
      )..start();
      final phase = run.current!;
      expect(phase.durationS, 2 * ProgramItem.breathS);
      expect(phase.breathsLeft(run.remainingInPhase!), 2);
      for (var i = 0; i < ProgramItem.breathS; i++) {
        run.tick();
      }
      expect(phase.breathsLeft(run.remainingInPhase!), 1);
      for (var i = 0; i < ProgramItem.breathS; i++) {
        run.tick();
      }
      expect(run.finished, isTrue);
    });
  });

  group('Belastung', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    test('gewichtet die Minuten nach Pulsbereich', () {
      final id = db.startWorkout(Sport.treadmill, DateTime(2026, 10, 20, 8));
      for (var t = 1; t <= 600; t++) {
        // Bei Maximalpuls 200: 5 Minuten zu 110 (Gewicht 1), 5 zu 185 (5),
        // dazu Puls 90 unter 50 %, der nicht zählt.
        db.addSample(id, Sample(t: t, heartRate: t <= 300 ? 110 : 185));
      }
      for (var t = 601; t <= 660; t++) {
        db.addSample(id, Sample(t: t, heartRate: 90));
      }
      final loads = db.workoutLoads(200, workoutId: id);
      expect(loads.single.load, 5 * 1 + 5 * 5);
    });

    test('Trainings ohne Puls fehlen', () {
      final id = db.startWorkout(Sport.treadmill, DateTime(2026, 10, 20));
      db.addSample(id, const Sample(t: 1, speedKmh: 8));
      expect(db.workoutLoads(200), isEmpty);
    });

    test('verteilt sich auf Wochen und vergleicht mit dem Üblichen', () {
      final now = DateTime(2026, 11, 1, 12); // ein Sonntag
      WorkoutLoad at(int daysAgo, int load) => WorkoutLoad(
          workoutId: daysAgo,
          startedAt: now.subtract(Duration(days: daysAgo)),
          load: load);
      final loads = [at(1, 300), at(10, 100), at(17, 100), at(24, 100), at(31, 100)];
      final weeks = buildLoadWeeks(loads, now: now);
      expect(weeks, hasLength(12));
      expect(weeks.last.load, 300);
      expect(weeks.last.count, 1);
      expect(weeks[weeks.length - 2].load, 100);
      final trend = loadTrend(loads, now);
      expect(trend.recent, 300);
      expect(trend.usual, 100);
      expect(trend.label, 'Deutlich mehr als sonst');
      expect(loadTrend(const [], now).ratio, isNull);
    });
  });

  group('Vergleich', () {
    List<Sample> ramp(int seconds) => [
          for (var t = 1; t <= seconds; t++)
            Sample(
              t: t,
              heartRate: 100 + t,
              speedKmh: 10,
              distanceM: t * 10 / 3.6,
            ),
        ];

    test('die Kurve folgt der Zeit und dünnt lange Trainings aus', () {
      final short = compareCurve(
          ramp(100), CompareMetric.heartRate, CompareAxis.time);
      expect(short.values, hasLength(100));
      expect(short.at(49.5), 150);
      final long = compareCurve(
          ramp(3600), CompareMetric.heartRate, CompareAxis.time);
      expect(long.values.length, lessThanOrEqualTo(comparePoints));
      expect(long.end, closeTo(3600, long.step));
    });

    test('über die Strecke liegt die Pace auf derselben Stelle', () {
      final curve =
          compareCurve(ramp(360), CompareMetric.pace, CompareAxis.distance);
      expect(curve.at(500), closeTo(360, 0.01));
      expect(curve.end, closeTo(1000, compareMetersStep * 2));
    });

    test('im Stand gibt es keine Pace', () {
      final curve = compareCurve(const [Sample(t: 1, speedKmh: 0.5)],
          CompareMetric.pace, CompareAxis.time);
      expect(curve.isEmpty, isTrue);
    });

    test('gleiche Workouts: Sportart und Titel, auch abgebrochene', () {
      Workout w(int id, String? title, Sport sport) => Workout(
            id: id,
            uuid: '$id',
            sport: sport,
            startedAt: DateTime(2026, 10, id),
            status: WorkoutStatus.finished,
            title: title,
          );
      final all = [
        w(1, 'Hero: Cindy', Sport.crossfit),
        w(2, 'Hero: Cindy (abgebrochen)', Sport.crossfit),
        w(3, 'Hero: Mary', Sport.crossfit),
        w(4, 'Hero: Cindy', Sport.calisthenics),
      ];
      expect(sameWorkouts(all, all.first).map((x) => x.id), [2, 1]);
    });

    testWidgets('die Seite legt die Durchgänge übereinander', (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final ids = [
        for (var d = 1; d <= 3; d++)
          db.startWorkout(Sport.treadmill, DateTime(2026, 10, d, 8)),
      ];
      for (final id in ids) {
        for (final s in ramp(120)) {
          db.addSample(id, s);
        }
        db.finishWorkout(id);
      }
      final runs = db.workouts();
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ComparePage(db: db, workouts: runs, title: 'Lauf'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('3 Durchgänge'), findsOneWidget);
      expect(find.text('Puls'), findsOneWidget);
      expect(find.text('Strecke'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      await tester.tap(find.text('Pace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alle aus'));
      await tester.pumpAndSettle();
      expect(find.text('Keine Kurve ausgewählt.'), findsOneWidget);
    });
  });
}
