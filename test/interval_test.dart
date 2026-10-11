import 'package:fitapp/ble/ftms_control.dart';
import 'package:fitapp/data/database.dart';
import 'package:fitapp/interval/interval_models.dart';
import 'package:fitapp/interval/interval_run.dart';
import 'package:fitapp/interval/signals.dart';
import 'package:flutter_test/flutter_test.dart';

const _template = IntervalTemplate(
  name: 'Test',
  targetKind: TargetKind.speed,
  blocks: [
    IntervalBlock(steps: [
      IntervalStep(label: 'Einlaufen', durationS: 10, target: 7),
    ]),
    IntervalBlock(repeat: 2, steps: [
      IntervalStep(label: 'Schnell', durationS: 8, target: 12.5),
      IntervalStep(label: 'Locker', durationS: 4, target: 7),
      IntervalStep(label: 'Leer', durationS: 0, target: 7),
    ]),
  ],
);

/// Kurzform eines Ereignisses für lesbare Erwartungen.
String short(IntervalEvent e) => switch (e) {
      StepStarted(:final step) => 'start ${step.label}',
      StepEnding(:final secondsLeft) => 'noch $secondsLeft',
      IntervalFinished() => 'ende',
    };

void main() {
  group('IntervalTemplate', () {
    test('rollt Gruppen aus und lässt Abschnitte ohne Dauer weg', () {
      final steps = _template.flatten();
      expect(steps.map((s) => s.label),
          ['Einlaufen', 'Schnell', 'Locker', 'Schnell', 'Locker']);
      expect(steps[0].round, isNull);
      expect([steps[1].round, steps[1].rounds], [1, 2]);
      expect([steps[4].round, steps[4].rounds], [2, 2]);
      expect(_template.totalSeconds, 34);
    });

    test('ohne Zielwert-Art tragen die Abschnitte keinen Zielwert', () {
      final plain = _template.copyWith(targetKind: TargetKind.none);
      expect(plain.flatten().every((s) => s.target == null), isTrue);
    });

    test('Zielwerte werden mit Einheit und deutschem Komma angezeigt', () {
      expect(TargetKind.speed.format(12), '12 km/h');
      expect(TargetKind.speed.format(12.5), '12,5 km/h');
      expect(TargetKind.resistance.format(8), 'Stufe 8');
      expect(TargetKind.power.format(150), '150 W');
    });
  });

  group('IntervalRun', () {
    test('spielt alle Abschnitte mit Vorwarnung bis zum Ende ab', () {
      final run = IntervalRun(_template.flatten());
      final log = <String>[...run.start().map(short)];
      for (var i = 0; i < 40; i++) {
        log.addAll(run.tick().map(short));
      }
      expect(log, [
        'start Einlaufen',
        'noch 5', 'noch 4', 'noch 3', 'noch 2', 'noch 1',
        'start Schnell',
        'noch 5', 'noch 4', 'noch 3', 'noch 2', 'noch 1',
        'start Locker',
        'noch 3', 'noch 2', 'noch 1',
        'start Schnell',
        'noch 5', 'noch 4', 'noch 3', 'noch 2', 'noch 1',
        'start Locker',
        'noch 3', 'noch 2', 'noch 1',
        'ende',
      ]);
      expect(run.finished, isTrue);
      expect(run.remainingTotal, 0);
    });

    test('kennt Position, Restzeiten und den nächsten Abschnitt', () {
      final run = IntervalRun(_template.flatten())..start();
      for (var i = 0; i < 12; i++) {
        run.tick();
      }
      expect(run.position, 2);
      expect(run.current!.label, 'Schnell');
      expect(run.remainingInStep, 6);
      expect(run.remainingTotal, 22);
      expect(run.next!.label, 'Locker');
    });

    test('Überspringen beginnt sofort den nächsten Abschnitt', () {
      final run = IntervalRun(_template.flatten())..start();
      run.tick();
      expect(run.skip().map(short), ['start Schnell']);
      expect(run.remainingInStep, 8);
    });

    test('Überspringen des letzten Abschnitts beendet das Intervall', () {
      final run = IntervalRun(
          const [PlannedStep(label: 'Einzig', durationS: 30)])
        ..start();
      expect(run.skip().map(short), ['ende']);
      expect(run.tick(), isEmpty);
      expect(run.skip(), isEmpty);
    });

    test('vor dem Start passiert nichts', () {
      final run = IntervalRun(_template.flatten());
      expect(run.tick(), isEmpty);
      expect(run.remainingInStep, 10);
    });
  });

  group('Ansagen', () {
    const next = PlannedStep(label: 'Schnell', durationS: 60, target: 12.5);

    test('fünf Sekunden vor dem Wechsel wird der nächste Abschnitt angesagt',
        () {
      expect(announcement(const StepEnding(5, next), TargetKind.speed),
          'Gleich: Schnell, 12,5 km/h');
      expect(announcement(const StepEnding(3, next), TargetKind.speed), isNull);
    });

    test('vor dem Ende des letzten Abschnitts gibt es nichts anzusagen', () {
      expect(
          announcement(const StepEnding(5, null), TargetKind.speed), isNull);
      expect(announcement(const IntervalFinished(), TargetKind.none),
          'Intervall beendet');
    });
  });

  group('FTMS-Steuerbefehle', () {
    test('Geschwindigkeit in Hundertstel km/h', () {
      expect(ftmsSetTarget(TargetKind.speed, 12.5), [0x02, 0xE2, 0x04]);
    });

    test('Widerstand in Zehntelstufen, ein Byte', () {
      expect(ftmsSetTarget(TargetKind.resistance, 8), [0x04, 80]);
      expect(ftmsSetTarget(TargetKind.resistance, 99), [0x04, 255]);
    });

    test('Leistung in Watt', () {
      expect(ftmsSetTarget(TargetKind.power, 150), [0x05, 0x96, 0x00]);
    });

    test('ohne Zielwert-Art gibt es keinen Befehl', () {
      expect(ftmsSetTarget(TargetKind.none, 1), isNull);
    });

    test('Antworten des Geräts werden verstanden', () {
      final ok = FtmsResponse.parse([0x80, 0x02, 0x01])!;
      expect(ok.success, isTrue);
      final refused = FtmsResponse.parse([0x80, 0x02, 0x03])!;
      expect(refused.success, isFalse);
      expect(refused.message, contains('außerhalb'));
      expect(FtmsResponse.parse([0x01, 0x02]), isNull);
    });
  });

  group('Vorlagen in der Datenbank', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    test('eine neue Datenbank bringt Beispielvorlagen mit', () {
      final names = db.intervalTemplates().map((t) => t.name);
      expect(names, hasLength(2));
      expect(names, contains('Tabata 8 × 20/10'));
    });

    test('speichern, ändern und löschen', () {
      final id = db.saveIntervalTemplate(_template);
      var stored = db.intervalTemplates().firstWhere((t) => t.id == id);
      expect(stored.targetKind, TargetKind.speed);
      expect(stored.blocks[1].repeat, 2);
      expect(stored.blocks[1].steps.first.target, 12.5);

      db.saveIntervalTemplate(stored.copyWith(name: 'Umbenannt'));
      stored = db.intervalTemplates().firstWhere((t) => t.id == id);
      expect(stored.name, 'Umbenannt');
      expect(db.intervalTemplates(), hasLength(3));

      db.deleteIntervalTemplate(id);
      expect(db.intervalTemplates().any((t) => t.id == id), isFalse);
    });

    test('Signal-Einstellungen werden gemerkt', () {
      expect(SignalSettings.load(db).voice, isTrue);
      const SignalSettings(tone: true, vibration: false, voice: false).save(db);
      final loaded = SignalSettings.load(db);
      expect([loaded.tone, loaded.vibration, loaded.voice],
          [true, false, false]);
    });
  });
}
