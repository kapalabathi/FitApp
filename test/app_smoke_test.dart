import 'package:fitapp/ble/device_kind.dart';
import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/interval/signals.dart';
import 'package:fitapp/programs/program_models.dart';
import 'package:fitapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase db;

  setUpAll(() {
    // In Tests gibt es weder Lautsprecher noch Sprachausgabe.
    createSignals = (_) => const SilentSignals();
    return initializeDateFormatting('de');
  });
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

      // Programme: mitgelieferte Programme und die Übungsbibliothek
      await tester.tap(find.text('Programme').first);
      await tester.pumpAndSettle();
      expect(find.text('Calisthenics: Grundlagen'), findsOneWidget);
      await tester.tap(find.text('Übungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Crossfit'));
      await tester.pumpAndSettle();
      expect(find.text('Bear Crawl'), findsOneWidget);
      expect(find.text('Baum'), findsNothing);

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
      // Kurven mit Achsenwerten samt Einheit
      await tester.scrollUntilVisible(find.text('Geschwindigkeit'), 200);
      expect(find.text('25,0 km/h'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Trittfrequenz'), 200);
      expect(find.text('85,0 /min'), findsWidgets);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Auswertungen im Verlauf
      await tester.tap(find.text('Umfang'));
      await tester.pumpAndSettle();
      expect(find.text('Wochen'), findsOneWidget);
      await tester.tap(find.text('Pulszonen'));
      await tester.pumpAndSettle();
      expect(find.text('Geburtsjahr eingeben'), findsOneWidget);
      await tester.tap(find.text('Bestwerte'));
      await tester.pumpAndSettle();
      expect(find.text('Längstes Training'), findsOneWidget);
      expect(find.text('Leistung 1 min'), findsOneWidget);

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

  testWidgets('ein Programm wird geführt abgespielt und als Training gespeichert',
      (tester) async {
    // Hochformat wie auf einem Phone, damit die ganze Übung sichtbar ist.
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ids = {for (final e in db.exercises()) e.builtinKey: e.uuid};
    db.saveProgram(Program(
      name: 'Aaa Testprogramm',
      category: ExerciseCategory.yoga,
      items: [
        ProgramItem(
            exerciseUuid: ids['yoga_01_berghaltung']!,
            timed: true,
            amount: 5,
            restS: 3),
        ProgramItem(
            exerciseUuid: ids['cali_01_liegestuetz']!, timed: false, amount: 10),
      ],
    ));
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programme').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aaa Testprogramm'));
    await tester.pumpAndSettle();
    expect(find.text('10 Wiederholungen'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    // Erste Übung auf Zeit
    expect(find.text('Berghaltung (Tadasana)'), findsOneWidget);
    expect(find.text('Danach: Liegestütz'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    // Pause mit Vorschau
    expect(find.text('Pause – danach:'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // Übung mit Wiederholungen wartet auf „Fertig"
    expect(find.text('10 ×'), findsOneWidget);
    expect(find.text('Letzte Übung'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Fertig'));
    await tester.pump();
    expect(find.text('Programm beendet'), findsOneWidget);

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final workout = db.workouts().single;
    expect(workout.sport, Sport.yoga);
    expect(workout.durationS, 12);
    expect(find.text('Dauer'), findsOneWidget);
  });

  testWidgets('Maximalpuls eingeben zeigt die Pulszonen', (tester) async {
    recordWorkout();
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulszonen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geburtsjahr eingeben'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Speichern'));
    await tester.pump();
    expect(find.text('Bitte Geburtsjahr oder Maximalpuls eingeben.'),
        findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Eigener Maximalpuls (optional)'), '180');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Maximalpuls 180'), findsOneWidget);
    expect(find.text('Zone 5'), findsOneWidget);
    await tester.tap(find.text('Gesamt'));
    await tester.pumpAndSettle();
    // Puls 110 bis 140 bei Maximalpuls 180: Zonen 2 und 3
    expect(find.textContaining('0 %'), findsWidgets);
  });

  testWidgets('ein Training lässt sich umbenennen und mit Notiz versehen',
      (tester) async {
    final id = recordWorkout();
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('02:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Training bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Titel'), 'Feierabend');
    await tester.enterText(find.widgetWithText(TextField, 'Notiz'), 'Gute Beine');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Feierabend'), findsOneWidget);
    expect(find.text('Gute Beine'), findsOneWidget);
    expect(db.workout(id)!.title, 'Feierabend');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Feierabend'), findsOneWidget);
  });

  testWidgets('im Verlauf lassen sich mehrere Trainings auswählen und löschen',
      (tester) async {
    final keep = recordWorkout();
    final first = recordWorkout();
    final second = recordWorkout();
    db.updateWorkout(keep, title: 'Bleibt', sport: Sport.indoorBike, notes: '');
    db.updateWorkout(first, title: 'Eins', sport: Sport.indoorBike, notes: '');
    db.updateWorkout(second, title: 'Zwei', sport: Sport.indoorBike, notes: '');

    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();

    // Langes Drücken beginnt die Auswahl, danach wählt einfaches Tippen.
    await tester.longPress(find.text('Eins'));
    await tester.pumpAndSettle();
    expect(find.text('1 ausgewählt'), findsOneWidget);
    await tester.tap(find.text('Zwei'));
    await tester.pumpAndSettle();
    expect(find.text('2 ausgewählt'), findsOneWidget);
    expect(find.text('Dauer'), findsNothing); // keine Detailansicht geöffnet

    // Erneutes Tippen nimmt ein Training wieder aus der Auswahl.
    await tester.tap(find.text('Zwei'));
    await tester.pumpAndSettle();
    expect(find.text('1 ausgewählt'), findsOneWidget);
    await tester.tap(find.text('Zwei'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Exportieren'));
    await tester.pumpAndSettle();
    expect(find.text('Als FIT exportieren'), findsOneWidget);
    expect(find.text('Als GPX exportieren'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // Menü schließen
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ausgewählte löschen'));
    await tester.pumpAndSettle();
    expect(find.text('2 Trainings löschen?'), findsOneWidget);
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(db.workouts().map((w) => w.id), [keep]);
    expect(find.text('Bleibt'), findsOneWidget);
    expect(find.text('Eins'), findsNothing);
    // Die Auswahl ist beendet, die normale Kopfzeile zurück.
    expect(find.byTooltip('Strava'), findsOneWidget);
  });

  testWidgets('„Alle auswählen" und das Aufheben der Auswahl', (tester) async {
    recordWorkout();
    recordWorkout();
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('02:00').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Alle auswählen'));
    await tester.pumpAndSettle();
    expect(find.text('2 ausgewählt'), findsOneWidget);

    await tester.tap(find.byTooltip('Auswahl aufheben'));
    await tester.pumpAndSettle();
    expect(find.text('2 ausgewählt'), findsNothing);
    expect(db.workouts(), hasLength(2));
  });

  testWidgets('Löschen in der Detailansicht leert den Verlauf', (tester) async {
    recordWorkout();
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('02:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    expect(find.text('Zu Strava hochladen'), findsOneWidget);
    expect(find.text('Als FIT exportieren'), findsOneWidget);
    await tester.tap(find.text('Training löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Keine Trainings in dieser Auswahl.'), findsOneWidget);
    expect(db.workouts(), isEmpty);
  });
}
