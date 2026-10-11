import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ble/device_kind.dart';
import '../ble/sensor_connection.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../interval/interval_models.dart';
import '../interval/interval_run.dart';
import '../interval/signals.dart';
import 'workout_recorder.dart';

/// Ob und wie der Intervall-Timer das Fitnessgerät steuert.
enum ControlState {
  /// Nicht gewünscht oder vom Nutzer gestoppt.
  off,

  /// Zielwerte werden an das Gerät gesendet.
  active,

  /// Nach einem Verbindungsabbruch angehalten, bis der Nutzer bestätigt
  /// (Lastenheft A-010).
  suspended,
}

/// Ein laufendes Training: verbindet die gewählten Geräte, treibt die
/// Aufzeichnung und den Intervall-Timer im Sekundentakt und hält den
/// Bildschirm an.
class WorkoutSession extends ChangeNotifier {
  WorkoutSession({
    required AppDatabase db,
    required Sport sport,
    required List<SavedDevice> devices,
    this.template,
    bool controlMachine = false,
    this.signals = const SilentSignals(),
  })  : recorder = WorkoutRecorder(db: db, sport: sport),
        _control = controlMachine ? ControlState.active : ControlState.off {
    for (final device in devices) {
      recorder.addSource(
        device.deviceId,
        dedicatedHeartRate: device.kind == DeviceKind.heartRate,
      );
      final connection = SensorConnection(device, onData: _onData)
        ..addListener(_onLinkChanged);
      connections.add(connection);
      connection.start();
    }
    final template = this.template;
    if (template != null) {
      interval = IntervalRun([
        // Vor dem ersten Zielwert bleibt Zeit, sich bereit zu machen; das
        // Gerät ändert sich nie ohne Ankündigung.
        if (controlMachine)
          const PlannedStep(label: 'Bereit machen', durationS: _leadInS),
        ...template.flatten(),
      ]);
      _handle(interval!.start());
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _keepScreenOn(true);
  }

  static const _leadInS = 10;

  final WorkoutRecorder recorder;
  final List<SensorConnection> connections = [];
  final IntervalTemplate? template;
  final Signals signals;
  late final Timer _timer;

  /// Der Ablauf der Intervalle, wenn eine Vorlage gewählt wurde.
  IntervalRun? interval;

  ControlState _control;
  ControlState get control => _control;

  /// Rückmeldung zum letzten Steuerbefehl, zur Anzeige.
  String? controlMessage;

  final Map<SensorConnection, int> _seenConnects = {};

  Sport get sport => recorder.sport;
  TargetKind get targetKind => template?.targetKind ?? TargetKind.none;

  void _onData(SavedDevice device, Map<Metric, double> values) {
    recorder.onData(device.deviceId, values);
  }

  void _tick() {
    if (!recorder.paused) {
      recorder.tick();
      final run = interval;
      if (run != null) _handle(run.tick());
    }
    notifyListeners();
  }

  void _handle(List<IntervalEvent> events) {
    for (final event in events) {
      signals.handle(event, targetKind);
      if (event is StepStarted) _applyTarget(event.step);
    }
  }

  /// Das Gerät, das sich gerade steuern lässt.
  SensorConnection? get _machine {
    for (final c in connections) {
      if (c.control != null) return c;
    }
    return null;
  }

  Future<void> _applyTarget(PlannedStep step) async {
    final target = step.target;
    if (_control != ControlState.active || target == null) return;
    final machine = _machine?.control;
    if (machine == null) {
      controlMessage = 'Kein steuerbares Gerät verbunden';
      notifyListeners();
      return;
    }
    final error = await machine.setTarget(targetKind, target);
    controlMessage = error == null
        ? '${targetKind.format(target)} gesetzt'
        : '${targetKind.format(target)} nicht gesetzt: $error';
    notifyListeners();
  }

  void _onLinkChanged() {
    for (final c in connections) {
      final seen = _seenConnects[c] ?? 0;
      if (c.connectCount > seen) {
        _seenConnects[c] = c.connectCount;
        // Ein wiederverbundenes Gerät bekommt erst nach Bestätigung wieder
        // Befehle; in der Zwischenzeit kann jemand von Hand eingegriffen haben.
        if (seen > 0 && c.control != null && _control == ControlState.active) {
          _control = ControlState.suspended;
          controlMessage = 'Verbindung war unterbrochen';
        } else if (seen == 0 && c.control != null) {
          // Das Gerät war beim Beginn des Abschnitts noch nicht verbunden.
          final step = interval?.current;
          if (step != null) _applyTarget(step);
        }
      }
    }
    notifyListeners();
  }

  /// Stoppt die Steuerung mit einem Tipp. Das Gerät behält seinen letzten
  /// Wert und wird ab jetzt nur noch von Hand bedient.
  void stopControl() {
    _control = ControlState.off;
    controlMessage = 'Steuerung gestoppt';
    notifyListeners();
  }

  /// Nimmt die Steuerung wieder auf und setzt den Zielwert des laufenden
  /// Abschnitts.
  void resumeControl() {
    _control = ControlState.active;
    final step = interval?.current;
    if (step != null) _applyTarget(step);
    notifyListeners();
  }

  void skipStep() {
    final run = interval;
    if (run == null || recorder.paused) return;
    _handle(run.skip());
    notifyListeners();
  }

  void togglePause() {
    recorder.paused ? recorder.resume() : recorder.pause();
    notifyListeners();
  }

  void preferHeartRateFrom(String deviceId) {
    recorder.preferredHeartRateSource = deviceId;
    notifyListeners();
  }

  /// Beendet das Training. Gibt das gespeicherte Training zurück oder
  /// `null`, wenn nichts aufgezeichnet wurde.
  ///
  /// Das Speichern ist beim Zurückkehren abgeschlossen. Das Trennen der
  /// Geräte läuft danach im Hintergrund weiter: Es kann bei einem Gerät, das
  /// gerade nicht erreichbar ist, lange dauern und darf das Beenden nicht
  /// aufhalten.
  Workout? finish() {
    _timer.cancel();
    _control = ControlState.off;
    final workout = recorder.finish();
    signals.dispose();
    _keepScreenOn(false);
    for (final c in connections) {
      c.removeListener(_onLinkChanged);
      unawaited(c.stop());
    }
    return workout;
  }

  /// Ein Fehler beim Wachhalten des Bildschirms darf das Training nicht
  /// stören.
  static void _keepScreenOn(bool on) {
    (on ? WakelockPlus.enable() : WakelockPlus.disable())
        .catchError((Object _) {});
  }
}
