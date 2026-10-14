import 'package:fit_tool/fit_tool.dart' as fit;
import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/export/fit_writer.dart';
import 'package:fitapp/sync/sync_engine.dart';
import 'package:fitapp/ui/workout_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase db;
  setUpAll(() => initializeDateFormatting('de'));
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  int workout() {
    final id = db.startWorkout(Sport.treadmill, DateTime(2026, 10, 14, 13));
    for (var t = 1; t <= 300; t++) {
      db.addSample(id, Sample(t: t, speedKmh: 5, distanceM: t * 1.39));
    }
    db.finishWorkout(id);
    return id;
  }

  test('die Gründe von Android werden übersetzt', () {
    expect(linkReasonLabel('Connection Timeout'),
        'Funkverbindung abgerissen (Zeitüberschreitung)');
    expect(linkReasonLabel('Remote User Terminated Connection'),
        'vom Gerät beendet');
    expect(linkReasonLabel(null), 'ohne Angabe von Android');
    // Unbekannte Gründe bleiben lesbar stehen.
    expect(linkReasonLabel('Controller Busy'), 'Controller Busy');
    expect(const LinkLoss(t: 1, device: 'x', reason: 'Connection Timeout')
        .isTimeout, isTrue);
    expect(const LinkLoss(t: 1, device: 'x', reason: 'Remote User Terminated '
            'Connection').isTimeout, isFalse);
  });

  test('Abbrüche werden je Training gespeichert, mit nachgetragener Dauer', () {
    final id = workout();
    final first = db.addLinkLoss(id,
        const LinkLoss(t: 120, device: 'Laufband', reason: 'Connection Timeout'));
    db.addLinkLoss(id, const LinkLoss(t: 30, device: 'Laufband'));
    db.setLinkLossDuration(first, 9);
    final losses = db.linkLosses(id);
    expect(losses.map((l) => (l.t, l.downS)), [(30, null), (120, 9)]);
    expect(losses.last.reason, 'Connection Timeout');

    db.deleteWorkout(id);
    expect(db.linkLosses(id), isEmpty);
  });

  test('Abbrüche wandern bei der Synchronisation mit', () async {
    final other = AppDatabase.inMemory();
    addTearDown(other.close);
    final store = MemorySyncStore();
    final id = workout();
    final loss = db.addLinkLoss(id,
        const LinkLoss(t: 60, device: 'Laufband', reason: 'Connection Timeout'));
    db.setLinkLossDuration(loss, 10);
    await synchronize(db, store);
    await synchronize(other, store);
    final there = other.workouts().single;
    final losses = other.linkLosses(there.id);
    expect(losses.single.reason, 'Connection Timeout');
    expect(losses.single.downS, 10);
  });

  test('in der FIT-Datei steht jeder Abbruch als Ereignis', () {
    final id = workout();
    db.addLinkLoss(id,
        const LinkLoss(t: 100, device: 'Laufband', reason: 'Connection Timeout'));
    db.addLinkLoss(id, const LinkLoss(t: 200, device: 'Laufband',
        reason: 'Remote User Terminated Connection'));
    final w = db.workout(id)!;
    final bytes = buildFit(w, db.samples(id), db.laps(id),
        linkLosses: db.linkLosses(id));
    final file = fit.FitFile.fromBytes(bytes);
    final events = file.records
        .map((r) => r.message)
        .whereType<fit.EventMessage>()
        .where((e) => e.event == fit.Event.commTimeout)
        .toList();
    expect(events, hasLength(2));
    final start = w.startedAt.millisecondsSinceEpoch ~/ 1000;
    expect(events.map((e) => e.timestamp! ~/ 1000 - start), [100, 200]);
    // 3: Funkstrecke abgerissen, 2: Verbindung beendet
    expect(events.map((e) => e.data), [3, 2]);
    expect(events.first.eventType, fit.EventType.marker);
    // Die Messpunkte bleiben vollständig.
    expect(file.records.map((r) => r.message).whereType<fit.RecordMessage>(),
        hasLength(300));
  });

  testWidgets('die Detailansicht fasst die Abbrüche zusammen', (tester) async {
    final id = workout();
    for (final (t, reason, down) in [
      (100, 'Connection Timeout', 9),
      (250, 'Connection Timeout', 11),
      (280, 'Remote User Terminated Connection', 4),
    ]) {
      final loss = db.addLinkLoss(
          id, LinkLoss(t: t, device: 'Laufband', reason: reason));
      db.setLinkLossDuration(loss, down);
    }
    await tester.pumpWidget(
        MaterialApp(home: WorkoutDetailPage(db: db, workoutId: id)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Alle Abbrüche'), 300);
    expect(find.text('3 Abbrüche, im Mittel 8 s getrennt'), findsOneWidget);
    expect(find.text('2 × Funkverbindung abgerissen (Zeitüberschreitung)'),
        findsOneWidget);
    await tester.tap(find.text('Alle Abbrüche'));
    await tester.pumpAndSettle();
    expect(find.text('Laufband: vom Gerät beendet, 4 s'), findsOneWidget);
  });
}
