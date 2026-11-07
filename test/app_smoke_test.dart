import 'package:fitapp/ble/device_kind.dart';
import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/interval/signals.dart';
import 'package:fitapp/programs/program_models.dart';
import 'package:fitapp/main.dart';
import 'package:fitapp/ui/course_page.dart';
import 'package:fitapp/ui/format.dart';
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
  // Der Hinweis der leeren App auf eine Sicherung hat eigene Tests und
  // verschiebt hier nur die Seiten.
  setUp(
    () => db = AppDatabase.inMemory()..setFlag('hint.restoreDismissed', true),
  );
  tearDown(() => db.close());

  int recordWorkout() {
    final id = db.startWorkout(
      Sport.indoorBike,
      DateTime.now().subtract(const Duration(days: 2)),
    );
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
    testWidgets('Rundgang durch alle Bereiche bei ${size.width.round()} px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      db.saveDevice(
        const SavedDevice(
          deviceId: 'AA:BB',
          name: 'Brustgurt',
          kind: DeviceKind.heartRate,
        ),
      );
      recordWorkout();

      await tester.pumpWidget(FitApp(db: db, recoveredWorkouts: 1));
      await tester.pumpAndSettle();

      // Start: Sportarten und das gemerkte Gerät, als Pulssensor vorgewählt
      expect(find.text('Laufband'), findsOneWidget);
      expect(find.text('SkiErg'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
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
      expect(find.text('max 25,0 km/h'), findsOneWidget);
      expect(find.text('min 25,0 km/h'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Trittfrequenz'), 200);
      expect(find.text('max 85,0 /min'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Auswertungen im Verlauf
      await tester.tap(find.text('Umfang'));
      await tester.pumpAndSettle();
      expect(find.text('Wochen'), findsOneWidget);
      expect(find.textContaining('Zeit je Woche in h'), findsOneWidget);
      await tester.tap(find.text('Pulszonen'));
      await tester.pumpAndSettle();
      expect(find.text('Geburtsjahr eingeben'), findsOneWidget);
      await tester.ensureVisible(find.text('Bestwerte'));
      await tester.pumpAndSettle();
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

  testWidgets('eine Vorlage lässt sich anlegen und erscheint in der Liste', (
    tester,
  ) async {
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
      find.widgetWithText(TextField, 'Bezeichnung'),
      'Hart',
    );
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
    final saved = db.intervalTemplates().firstWhere(
      (t) => t.name == 'Pyramide',
    );
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

    testWidgets(
      'pausieren und danach beenden speichert und zeigt das Training',
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
      },
    );

    testWidgets('„Weiter trainieren" schließt die Rückfrage und zählt weiter', (
      tester,
    ) async {
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

  testWidgets(
    'ein Programm wird geführt abgespielt und als Training gespeichert',
    (tester) async {
      // Hochformat wie auf einem Phone, damit die ganze Übung sichtbar ist.
      tester.view.physicalSize = const Size(500, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final ids = {for (final e in db.exercises()) e.builtinKey: e.uuid};
      db.saveProgram(
        Program(
          name: 'Aaa Testprogramm',
          category: ExerciseCategory.yoga,
          items: [
            ProgramItem(
              exerciseUuid: ids['yoga_01_berghaltung']!,
              timed: true,
              amount: 5,
              restS: 3,
            ),
            ProgramItem(
              exerciseUuid: ids['cali_01_liegestuetz']!,
              timed: false,
              amount: 10,
            ),
          ],
        ),
      );
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
      // (große Anzeige und der Zähler zum Nachtragen)
      expect(find.text('10 ×'), findsNWidgets(2));
      expect(find.text('Letzte Übung'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      // Nur 8 geschafft, mit 5,5 kg Zusatzgewicht
      await tester.tap(find.byTooltip('Eine Wiederholung weniger'));
      await tester.tap(find.byTooltip('Eine Wiederholung weniger'));
      await tester.pump();
      expect(find.text('8 ×'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Gewicht kg'),
        '5,5',
      );
      await tester.tap(find.text('Fertig'));
      await tester.pump();
      expect(find.text('Programm beendet'), findsOneWidget);

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final workout = db.workouts().single;
      expect(workout.sport, Sport.yoga);
      expect(workout.durationS, 12);
      expect(db.setLogs(workout.id).map(formatSet), ['5 s', '8 × 5,5 kg']);
      expect(find.text('Dauer'), findsOneWidget);
    },
  );

  testWidgets('der Yoga-Grundkurs führt durch eine Einheit samt Atemübung', (
    tester,
  ) async {
    // Schmal wie ein kleines Phone
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programme').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurse & Atem'));
    await tester.pumpAndSettle();
    expect(find.text('Hero-WODs mit Kamera'), findsOneWidget);
    await tester.tap(find.text('Yoga-Grundkurs'));
    await tester.pumpAndSettle();
    expect(find.text('Stufe 1 von 6: Ankommen und Stehen'), findsOneWidget);
    expect(find.text('0 von 6 Einheiten (2 Wochen à 3)'), findsOneWidget);

    await tester.tap(find.text('Tag 1 starten'));
    await tester.pumpAndSettle();
    expect(find.text('Berghaltung (Tadasana)'), findsOneWidget);
    // 30 s Berghaltung, 5 s Pause, dann der Baum auf der rechten Seite
    await tester.pump(const Duration(seconds: 36));
    expect(find.text('Baum'), findsOneWidget);
    expect(find.text('Rechte Seite'), findsOneWidget);
    expect(find.text('Danach: linke Seite'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Seite wechseln'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Linke Seite'), findsOneWidget);

    await tester.pump(const Duration(minutes: 15));
    expect(find.text('Programm beendet'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Danach die Atemübung des Tages
    expect(find.text('Jetzt noch die Atemübung?'), findsOneWidget);
    await tester.tap(find.text('Starten'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Einatmen'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Ausatmen'), findsOneWidget);
    await tester.pump(const Duration(minutes: 4));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('1 von 6 Einheiten (2 Wochen à 3)'), findsOneWidget);
    expect(find.text('Tag 2 – Vorbeugen und Hüfte'), findsOneWidget);
    expect(db.workouts().map((w) => w.title).toSet(), {
      'Yoga-Grundkurs · Stufe 1 · Tag 1 – Stehhaltungen',
      'Atemübung: Bauchatmung',
    });
  });

  testWidgets('eine Übung zeigt Gruppe, Hinweis und Varianten', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programme').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yoga'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<PoseGroup?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rückbeuge').last);
    await tester.pumpAndSettle();
    expect(find.text('Kamel'), findsOneWidget);
    expect(find.text('Baum'), findsNothing);

    await tester.tap(find.text('Kobra'));
    await tester.pumpAndSettle();
    expect(find.text('Bhujangasana'), findsOneWidget);
    expect(find.text('Yoga  ·  Rückbeuge  ·  Leicht'), findsOneWidget);
    expect(find.text('Varianten'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Heraufschauender Hund'), 200);
    await tester.tap(find.text('Heraufschauender Hund'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sphinx oder Kobra'), findsOneWidget);

    // Im Editor bleiben die Angaben erhalten.
    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schwer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final saved = db.exercises().firstWhere(
      (e) => e.builtinKey == 'yoga_03_heraufschauender_hund',
    );
    expect(saved.level, 3);
    expect(saved.sanskrit, 'Urdhva Mukha Svanasana');
    expect(saved.easierUuid, 'builtin-yoga_04_kobra');
  });

  testWidgets('Atemanhalten erst nach Rückfrage', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programme').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurse & Atem'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kastenatmung'),
      200,
      scrollable: find.descendant(
        of: find.byType(CoursesAndBreathList),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('Kastenatmung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kastenatmung'));
    await tester.pumpAndSettle();
    expect(find.text('Ein 4 s · Aus 4 s'), findsOneWidget);

    await tester.tap(find.text('Atemanhalten freigeschaltet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nicht freischalten'));
    await tester.pumpAndSettle();
    expect(find.text('Ein 4 s · Aus 4 s'), findsOneWidget);

    await tester.tap(find.text('Atemanhalten freigeschaltet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verstanden, freischalten'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ein 4 s · Halten 4 s · Aus 4 s · Leer 4 s'),
      findsOneWidget,
    );
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
    expect(
      find.text('Bitte Geburtsjahr oder Maximalpuls eingeben.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Eigener Maximalpuls (optional)'),
      '180',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Maximalpuls 180'), findsOneWidget);
    expect(find.text('Zone 5'), findsOneWidget);
    await tester.tap(find.text('Gesamt'));
    await tester.pumpAndSettle();
    // Puls 110 bis 140 bei Maximalpuls 180: Zonen 2 und 3
    expect(find.textContaining('0 %'), findsWidgets);
  });

  testWidgets('ein Training lässt sich umbenennen und mit Notiz versehen', (
    tester,
  ) async {
    final id = recordWorkout();
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('02:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Training bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Titel'),
      'Feierabend',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Notiz'),
      'Gute Beine',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Feierabend'), findsOneWidget);
    expect(find.text('Gute Beine'), findsOneWidget);
    expect(db.workout(id)!.title, 'Feierabend');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Feierabend'), findsOneWidget);
  });

  testWidgets('die Zurück-Taste hebt die Auswahl im Verlauf auf', (
    tester,
  ) async {
    final id = recordWorkout();
    db.updateWorkout(id, title: 'Eins', sport: Sport.indoorBike, notes: '');
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Eins'));
    await tester.pumpAndSettle();
    expect(find.text('1 ausgewählt'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 ausgewählt'), findsNothing);
    expect(find.text('Eins'), findsOneWidget);
  });

  testWidgets('Zielpuls erscheint nur mit Gerät und Pulssensor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db.saveDevice(
      const SavedDevice(
        deviceId: 'GURT',
        name: 'Brustgurt',
        kind: DeviceKind.heartRate,
      ),
    );
    db.saveDevice(
      const SavedDevice(
        deviceId: 'BAND',
        name: 'Laufband',
        kind: DeviceKind.fitnessMachine,
      ),
    );
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    expect(find.text('Zielpuls halten'), findsNothing);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Laufband'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zielpuls halten'));
    await tester.pumpAndSettle();
    expect(find.text('Höchstens km/h'), findsOneWidget);
  });

  testWidgets(
    'im Verlauf lassen sich mehrere Trainings auswählen und löschen',
    (tester) async {
      final keep = recordWorkout();
      final first = recordWorkout();
      final second = recordWorkout();
      db.updateWorkout(
        keep,
        title: 'Bleibt',
        sport: Sport.indoorBike,
        notes: '',
      );
      db.updateWorkout(
        first,
        title: 'Eins',
        sport: Sport.indoorBike,
        notes: '',
      );
      db.updateWorkout(
        second,
        title: 'Zwei',
        sport: Sport.indoorBike,
        notes: '',
      );

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
      expect(find.text('Als FIT mit Trainingsort exportieren'), findsOneWidget);
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
    },
  );

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

  for (final scale in const [1.0, 1.6]) {
    testWidgets('lange Übungsnamen haben im Raster Platz für zwei Zeilen '
        '(Schriftgröße ×$scale)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(FitApp(db: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Programme').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Übungen'));
      await tester.pumpAndSettle();
      // Ein Name, der bei dieser Breite umbricht, ist vollständig zu sehen:
      // Der Text ist höher als eine Zeile und läuft nicht über die Kachel.
      final name = find.text('Oberschenkel-Vorderseite in Seitlage');
      await tester.scrollUntilVisible(
        name,
        400,
        maxScrolls: 80,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      const oneLine = 14 * 1.43;
      expect(tester.getSize(name).height, greaterThan(oneLine * scale * 1.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('der Schieber unter einer Kurve zeigt Zeit und Wert der Stelle, '
      'in allen Kurven zugleich', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    recordWorkout();
    await tester.pumpWidget(FitApp(db: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('02:00'));
    await tester.pumpAndSettle();

    // Ohne Auswahl steht nirgends ein Wert zur Stelle.
    expect(find.textContaining('bei '), findsNothing);

    // Mitte des ersten Schiebers: Sekunde 61 von 120
    await tester.tap(find.byType(Slider).first);
    await tester.pumpAndSettle();
    expect(find.text('bei 01:01:  125,0 /min'), findsOneWidget); // Puls
    expect(find.text('bei 01:01:  25,0 km/h'), findsOneWidget);
    expect(find.text('bei 01:01:  85,0 /min'), findsOneWidget); // Trittfrequenz

    // Ein Tipp in eine andere Kurve verschiebt die Stelle überall. Bei
    // Sekunde 50 hat der Pulssensor ausgesetzt.
    final speedChart = find
        .byWidgetPredicate(
          (w) => w is GestureDetector && w.onHorizontalDragUpdate != null,
        )
        .at(1);
    final box = tester.getRect(speedChart);
    await tester.tapAt(Offset(box.left + box.width * 49 / 119, box.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('bei 00:50:  kein Wert'), findsOneWidget);
    expect(find.text('bei 00:50:  25,0 km/h'), findsOneWidget);
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
