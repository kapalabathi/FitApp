import 'package:fitapp/ble/device_kind.dart';
import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase db;

  setUpAll(() => initializeDateFormatting('de'));
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  int recordWorkout() {
    final id = db.startWorkout(Sport.indoorBike, DateTime(2026, 10, 1, 18, 30));
    for (var t = 1; t <= 120; t++) {
      db.addSample(
        id,
        Sample(
          t: t,
          // Lücke im Puls, wie nach einem Verbindungsabbruch
          heartRate: t > 40 && t < 60 ? null : 110 + t ~/ 4,
          speedKmh: 25,
          cadence: 85,
          power: 150 + t % 7,
          distanceM: t * 7.0,
        ),
      );
    }
    db.finishWorkout(id, energyKcal: 21);
    return id;
  }

  for (final size in const [Size(400, 800), Size(1280, 800)]) {
    testWidgets('Rundgang durch alle Bereiche bei ${size.width.round()} px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      db.saveDevice(const SavedDevice(
          deviceId: 'AA:BB', name: 'Brustgurt', kind: DeviceKind.heartRate));
      recordWorkout();

      await tester.pumpWidget(FitApp(db: db, recoveredWorkouts: 1));
      await tester.pumpAndSettle();

      // Start: Sportarten und das gemerkte Gerät, als Pulssensor vorgewählt
      expect(find.text('Laufband'), findsOneWidget);
      expect(find.text('SkiErg'), findsOneWidget);
      expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue);
      expect(find.textContaining('gerettet'), findsOneWidget);

      // Intervalle: die mitgelieferten Beispielvorlagen
      await tester.tap(find.text('Intervalle'));
      await tester.pumpAndSettle();
      expect(find.text('Tabata 8 × 20/10'), findsOneWidget);
      expect(find.textContaining('16 Abschnitte'), findsOneWidget);

      // Verlauf: das Training mit seinen Eckdaten
      await tester.tap(find.text('Verlauf'));
      await tester.pumpAndSettle();
      expect(find.textContaining('02:00'), findsOneWidget);
      expect(find.textContaining('0,84 km'), findsOneWidget);

      // Detailansicht mit Kennzahlen und Kurven
      await tester.tap(find.textContaining('02:00'));
      await tester.pumpAndSettle();
      expect(find.text('Ø Leistung'), findsOneWidget);
      expect(find.text('21 kcal'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Trittfrequenz /min'), 200);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Geräte
      await tester.tap(find.text('Geräte'));
      await tester.pumpAndSettle();
      expect(find.text('Gerät hinzufügen'), findsOneWidget);
      expect(find.text('Pulssensor'), findsWidgets);

      expect(tester.takeException(), isNull);

      // Den Hinweis auf das gerettete Training ablaufen lassen.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('eine Vorlage lässt sich anlegen und erscheint in der Liste',
      (tester) async {
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intervalle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neue Vorlage'));
    await tester.pumpAndSettle();

    // Ohne Namen und Abschnitte wird nicht gespeichert.
    await tester.tap(find.text('Speichern'));
    await tester.pump();
    expect(find.text('Bitte einen Namen eingeben.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Pyramide');
    await tester.tap(find.text('Gruppe hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abschnitt'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Bezeichnung'), 'Hart');
    await tester.enterText(find.widgetWithText(TextField, 'Minuten'), '1');
    await tester.enterText(find.widgetWithText(TextField, 'Sekunden'), '30');
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gesamtdauer 01:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Mehr Wiederholungen'));
    await tester.pump();
    expect(find.textContaining('Gesamtdauer 03:00'), findsOneWidget);

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Pyramide'), findsOneWidget);
    final saved =
        db.intervalTemplates().firstWhere((t) => t.name == 'Pyramide');
    expect(saved.blocks.single.repeat, 2);
    expect(saved.blocks.single.steps.single.durationS, 90);

    // Die Fehlermeldung vom ersten Speicherversuch ablaufen lassen.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  group('Training ohne Geräte', () {
    Future<void> startWorkout(WidgetTester tester) async {
      await tester.pumpWidget(FitApp(db: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sonstiges'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('pausieren und danach beenden speichert und zeigt das Training',
        (tester) async {
      await startWorkout(tester);

      await tester.tap(find.text('Pause'));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Sonstiges – pausiert'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Beenden'));
      await tester.pumpAndSettle();
      expect(find.text('Training beenden?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Beenden').last);
      await tester.pumpAndSettle();

      // Die Pause zählt nicht mit; die Detailansicht des Trainings ist offen.
      expect(find.text('Training beenden?'), findsNothing);
      expect(find.text('Dauer'), findsOneWidget);
      expect(db.workouts().single.durationS, 3);
    });

    testWidgets('„Weiter trainieren" schließt die Rückfrage und zählt weiter',
        (tester) async {
      await startWorkout(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Beenden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter trainieren'));
      await tester.pumpAndSettle();
      expect(find.text('Training beenden?'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.widgetWithText(FilledButton, 'Beenden'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Beenden').last);
      await tester.pumpAndSettle();
      expect(db.workouts().single.durationS, greaterThanOrEqualTo(5));
    });
  });

  testWidgets('Löschen in der Detailansicht leert den Verlauf', (tester) async {
    recordWorkout();
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('02:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Training löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Keine Trainings in dieser Auswahl.'), findsOneWidget);
    expect(db.workouts(), isEmpty);
  });
}
