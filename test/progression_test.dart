import 'package:fitapp/ble/sensor_connection.dart';
import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/main.dart';
import 'package:fitapp/programs/progression.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  group('Progressionsregel', () {
    final today = DateTime(2026, 11, 7);
    final before = DateTime(2026, 11, 1);
    SetLog set(int reps, {DateTime? at, double? kg}) => SetLog(
      exerciseUuid: 'a',
      t: 1,
      reps: reps,
      weightKg: kg,
      performedAt: at ?? today,
    );

    test('drei Sätze mit je 12 führen zur schwereren Variante', () {
      expect(
        progressionAfter([set(12), set(13), set(15)], hasHarder: true),
        Progression.harder,
      );
    });

    test('es zählt nur das letzte Training', () {
      expect(
        progressionAfter([
          set(12),
          set(11),
          set(12, at: before),
          set(15),
        ], hasHarder: true),
        Progression.none,
      );
    });

    test('mit Gewicht ist mehr Gewicht dran, auch ohne Variante', () {
      expect(
        progressionAfter([
          set(12, kg: 4),
          set(12, kg: 4),
          set(14, kg: 4),
        ], hasHarder: false),
        Progression.moreWeight,
      );
    });

    test('ohne schwerere Variante und ohne Gewicht kein Vorschlag', () {
      expect(
        progressionAfter([set(12), set(12), set(12)], hasHarder: false),
        Progression.none,
      );
      expect(progressionAfter(const [], hasHarder: true), Progression.none);
    });
  });

  test('das Lebenszeichen ist wählbar, Vorgabe ist die Steuererlaubnis', () {
    expect(KeepAliveMode.fromId(null), KeepAliveMode.control);
    expect(KeepAliveMode.fromId('read'), KeepAliveMode.read);
    expect(KeepAliveMode.fromId('off'), KeepAliveMode.off);
  });

  group('leere App', () {
    testWidgets('bietet an, eine Sicherung einzuspielen', (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      await tester.pumpWidget(FitApp(db: db));
      await tester.pumpAndSettle();
      expect(find.textContaining('Noch keine Trainings'), findsOneWidget);
      await tester.tap(find.text('Nicht mehr zeigen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Noch keine Trainings'), findsNothing);
      expect(db.flag('hint.restoreDismissed', fallback: false), isTrue);
    });

    testWidgets('mit Trainings bleibt der Hinweis weg', (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final id = db.startWorkout(Sport.treadmill, DateTime(2026, 11, 1));
      db.addSample(id, const Sample(t: 1, speedKmh: 8));
      db.finishWorkout(id);
      await tester.pumpWidget(FitApp(db: db));
      await tester.pumpAndSettle();
      expect(find.textContaining('Noch keine Trainings'), findsNothing);
    });
  });
}
