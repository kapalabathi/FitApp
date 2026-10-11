import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ble/device_kind.dart';
import '../ble/sensor_connection.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../gps/geo.dart';
import '../interval/interval_models.dart';
import '../interval/interval_run.dart';
import '../interval/signals.dart';
import '../programs/program_run.dart';
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

/// Ein laufendes Training: verbindet die gewählten Geräte, nimmt Standorte
/// entgegen, treibt Aufzeichnung, Intervall-Timer und Programm im
/// Sekundentakt und hält den Bildschirm an.
class WorkoutSession extends ChangeNotifier {
  WorkoutSession({
    required AppDatabase db,
    required Sport sport,
    required List<SavedDevice> devices,
    this.template,
    this.program,
    Stream<GpsFix>? positions,
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
    final program = this.program;
    if (program != null) _handleProgram(program.start());
    if (sport.usesGps || sport == Sport.treadmill) {
      recorder.enableAutoLap(_autoLapM);
    }
    _positions = positions?.listen(
      recorder.onPosition,
      onError: (Object e) {
        gpsError = '$e';
        notifyListeners();
      },
    );
    _lastTickAt = clock.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTimer());
    _keepScreenOn(true);
  }

  static const _leadInS = 10;
  static const _autoLapM = 1000.0;

  /// Mehr Sekunden holt die Aufzeichnung nach einer Zwangspause des Systems
  /// nicht nach; so lange Lücken sind keine Trainingszeit mehr.
  static const _maxCatchUpS = 600;

  final WorkoutRecorder recorder;
  final List<SensorConnection> connections = [];
  final IntervalTemplate? template;
  final Signals signals;
  late final Timer _timer;
  late DateTime _lastTickAt;
  StreamSubscription<GpsFix>? _positions;

  /// Der Ablauf des Trainingsprogramms, wenn eines gespielt wird.
  final ProgramRun? program;

  /// Die letzte Fehlermeldung des GPS, zur Anzeige.
  String? gpsError;

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

  /// Der Zeitgeber feuert im Hintergrund nicht immer pünktlich. Maßgeblich
  /// ist deshalb die Uhr: Jede seither vergangene Sekunde wird nachgeholt.
  void _onTimer() {
    final now = clock.now();
    final due = now.difference(_lastTickAt).inSeconds;
    if (due < 1) return;
    _lastTickAt = _lastTickAt.add(Duration(seconds: due));
    for (var i = 0; i < due.clamp(0, _maxCatchUpS); i++) {
      _tick();
    }
    notifyListeners();
  }

  void _tick() {
    if (recorder.paused) return;
    final lap = recorder.tick();
    if (lap != null) _announceLap(lap);
    final run = interval;
    if (run != null) _handle(run.tick());
    final program = this.program;
    if (program != null) _handleProgram(program.tick());
  }

  void _handle(List<IntervalEvent> events) {
    for (final event in events) {
      signalInterval(signals, event, targetKind);
      if (event is StepStarted) _applyTarget(event.step);
    }
  }

  void _handleProgram(List<ProgramEvent> events) {
    for (final event in events) {
      switch (event) {
        case PhaseEnding():
          signals.warn();
        case PhaseStarted(:final phase):
          signals.change();
          signals.say(phase.isRest
              ? 'Pause. Danach: ${phase.exercise.name}'
              : phase.item.timed
                  ? '${phase.exercise.name}, ${phase.item.amount} Sekunden'
                  : '${phase.exercise.name}, ${phase.item.amount} Wiederholungen');
        case ProgramFinished():
          signals.finish();
          signals.say('Programm beendet');
      }
    }
  }

  void _announceLap(Lap lap) {
    final laps = recorder.laps;
    final previous = laps.length > 1 ? laps[laps.length - 2].t : 0;
    final seconds = lap.t - previous;
    signals.change();
    signals.say('Kilometer ${(lap.distanceM / _autoLapM).floor()}. '
        '${seconds ~/ 60} Minuten ${seconds % 60}');
  }

  /// Setzt von Hand eine Rundenmarke.
  void markLap() {
    if (recorder.markLap() != null) notifyListeners();
  }

  /// Schließt die laufende Übung oder Pause des Programms ab.
  void advanceProgram() {
    final program = this.program;
    if (program == null || recorder.paused) return;
    _handleProgram(program.advance());
    notifyListeners();
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
    // Die Pause selbst wird nicht nachgeholt.
    _lastTickAt = clock.now();
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
    _positions?.cancel();
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
