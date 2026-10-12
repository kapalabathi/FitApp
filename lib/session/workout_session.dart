import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ble/device_kind.dart';
import '../ble/ftms_control.dart';
import '../ble/sensor_connection.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../gps/geo.dart';
import '../interval/interval_models.dart';
import '../interval/interval_run.dart';
import '../interval/signals.dart';
import '../programs/program_run.dart';
import '../stats/stats.dart';
import 'auto_pause.dart';
import 'background_keeper.dart';
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
    bool autoPause = false,
    this.signals = const SilentSignals(),
  })  : recorder = WorkoutRecorder(
          db: db,
          sport: sport,
          kcalPerMinute: _energyEstimator(db),
        ),
        _autoPause = autoPause ? AutoPause.forSport(sport) : null,
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
    // Mit Bluetooth-Geräten soll das Training auch bei gesperrtem Display
    // weiterlaufen. Im Freien hält schon der Dienst des GPS die App wach.
    if (devices.isNotEmpty && positions == null) {
      _keepsAlive = true;
      BackgroundKeeper.start(sport.label);
    }
    _lastTickAt = clock.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTimer());
    _keepScreenOn(true);
  }

  static const _leadInS = 10;

  /// Die Schätzung des Energieverbrauchs aus dem Puls, oder `null`, wenn
  /// im Profil Gewicht oder Geburtsjahr fehlen.
  static double? Function(int)? _energyEstimator(AppDatabase db) {
    final profile = HeartProfile.load(db);
    if (!profile.canEstimateEnergy) return null;
    final now = DateTime.now();
    return (heartRate) => profile.kcalPerMinute(heartRate, now);
  }
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
  final AutoPause? _autoPause;

  /// Ob die laufende Pause von der App selbst kommt, weil keine Bewegung
  /// mehr gemessen wurde.
  bool autoPaused = false;

  // Vom Nutzer für den nächsten abgeschlossenen Satz eingetragene Werte.
  int? _pendingReps;
  double? _pendingWeightKg;
  bool _keepsAlive = false;
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
      _checkAutoPause();
      _tick();
    }
    notifyListeners();
  }

  /// Pausiert, wenn keine Bewegung mehr gemessen wird, und läuft weiter,
  /// sobald es wieder welche gibt. Eine Pause, die der Nutzer selbst
  /// gesetzt hat, rührt die Automatik nicht an.
  void _checkAutoPause() {
    final auto = _autoPause;
    if (auto == null || (recorder.paused && !autoPaused)) return;
    if (!auto.update(recorder.value(Metric.speed))) return;
    autoPaused = auto.paused;
    autoPaused ? recorder.pause() : recorder.resume();
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
        case PhaseCompleted(:final phase, :final elapsedS):
          _logSet(phase, elapsedS);
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
  ///
  /// [reps] und [weightKg] sind die tatsächlich geschafften Wiederholungen
  /// und das Gewicht, falls der Nutzer sie eingetragen hat.
  void advanceProgram({int? reps, double? weightKg}) {
    final program = this.program;
    if (program == null || recorder.paused) return;
    _pendingReps = reps;
    _pendingWeightKg = weightKg;
    _handleProgram(program.advance());
    _pendingReps = null;
    _pendingWeightKg = null;
    notifyListeners();
  }

  /// Hält eine abgeschlossene Übung als Satz fest (Kraft-Protokoll).
  void _logSet(ProgramPhase phase, int elapsedS) {
    final timed = phase.item.timed;
    // Eine sofort übersprungene Übung auf Zeit ist kein Satz.
    if (timed && elapsedS == 0) return;
    recorder.db.addSetLog(
      recorder.workoutId,
      SetLog(
        exerciseUuid: phase.exercise.uuid,
        t: recorder.elapsedS,
        reps: timed ? null : _pendingReps ?? phase.item.amount,
        weightKg: _pendingWeightKg,
        seconds: timed ? elapsedS : null,
      ),
    );
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
    if (error == null && targetKind == manualKind) manualTarget = target;
    controlMessage = error == null
        ? '${targetKind.format(target)} gesetzt'
        : '${targetKind.format(target)} nicht gesetzt: $error';
    notifyListeners();
  }

  // --- Steuerung von Hand ---

  /// Was sich bei dieser Sportart von Hand einstellen lässt: am Laufband
  /// die Geschwindigkeit, am Bike die Widerstandsstufe.
  TargetKind? get manualKind => switch (sport) {
        Sport.treadmill => TargetKind.speed,
        Sport.indoorBike => TargetKind.resistance,
        _ => null,
      };

  MachineControl? get _manualMachine {
    final kind = manualKind;
    if (kind == null) return null;
    for (final c in connections) {
      final control = c.control;
      if (control != null && control.supports(kind)) return control;
    }
    return null;
  }

  /// Ob gerade ein Gerät verbunden ist, das den Zielwert annimmt.
  bool get canControlManually => _manualMachine != null;

  /// Der zuletzt gesetzte Zielwert, von Hand oder durch den Timer.
  double? manualTarget;

  // Grenzen, falls das Gerät keine nennt.
  static const _defaultSpeedRange = (min: 1.0, max: 16.0);
  static const _defaultResistanceRange = (min: 1.0, max: 32.0);
  static const _speedStep = 0.5;

  /// Kleinster und größter einstellbarer Wert.
  ({double min, double max}) get manualLimits {
    final kind = manualKind;
    final range = kind == null ? null : _manualMachine?.range(kind);
    if (range != null && range.max > range.min) {
      return (min: range.min, max: range.max);
    }
    return kind == TargetKind.speed
        ? _defaultSpeedRange
        : _defaultResistanceRange;
  }

  /// Um so viel ändert ein Tastendruck den Zielwert.
  double get manualStep {
    final kind = manualKind;
    if (kind == TargetKind.speed) return _speedStep;
    final step = kind == null ? null : _manualMachine?.range(kind)?.step;
    return step != null && step >= 1 ? step : 1;
  }

  /// Der Wert, von dem die Tasten ausgehen: der zuletzt gesetzte, sonst
  /// der gerade gemessene.
  double get _manualBase =>
      manualTarget ??
      recorder.value(manualKind == TargetKind.speed
          ? Metric.speed
          : Metric.resistance) ??
      manualLimits.min;

  /// Ändert den Zielwert um [steps] Schritte, negativ für weniger.
  Future<void> adjustManual(int steps) {
    final limits = manualLimits;
    return setManual(steppedTarget(_manualBase, steps,
        step: manualStep, min: limits.min, max: limits.max));
  }

  /// Setzt den Zielwert am Gerät. Ein Tipp des Nutzers gilt zugleich als
  /// Bestätigung nach einem Verbindungsabbruch.
  Future<void> setManual(double value) async {
    final kind = manualKind;
    final machine = _manualMachine;
    if (kind == null || machine == null) return;
    final limits = manualLimits;
    final target = value.clamp(limits.min, limits.max).toDouble();
    manualTarget = target;
    notifyListeners();
    final error = await machine.setTarget(kind, target);
    controlMessage = error == null
        ? '${kind.format(target)} gesetzt'
        : '${kind.format(target)} nicht gesetzt: $error';
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
    if (autoPaused) {
      // Der Nutzer will trotz Stillstand weitermachen.
      autoPaused = false;
      _autoPause?.overrideByUser();
      recorder.resume();
    } else {
      recorder.paused ? recorder.resume() : recorder.pause();
      _autoPause?.reset();
    }
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
    if (_keepsAlive) BackgroundKeeper.stop();
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
