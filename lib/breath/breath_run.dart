import 'breath_models.dart';

sealed class BreathEvent {
  const BreathEvent();
}

/// Ein Schritt beginnt, im Zyklus [cycle] (ab 1).
class BreathStepStarted extends BreathEvent {
  const BreathStepStarted(this.step, this.cycle,
      {required this.rapid, this.startsRapid = false});

  final BreathStep step;
  final int cycle;

  /// Teil einer schnellen Folge: nur ein Ton, keine Ansage.
  final bool rapid;

  /// Der erste Schritt einer schnellen Folge; er wird angekündigt.
  final bool startsRapid;
}

class BreathFinished extends BreathEvent {
  const BreathFinished();
}

/// Spielt eine Atemübung ab: Schritt für Schritt, Zyklus für Zyklus, bis
/// die gewählte Zahl an Zyklen erreicht ist.
///
/// Kennt weder Uhr noch Töne: [tick] wird je aktiver Sekunde aufgerufen.
class BreathRun {
  BreathRun(this.exercise, {required int minutes, bool holdsAllowed = false})
      : steps = exercise.cycleWithHolds(holdsAllowed) {
    final cycleS = steps.fold(0, (sum, s) => sum + s.seconds);
    cycles = cycleS == 0 ? 0 : (minutes * 60 / cycleS).round().clamp(1, 9999);
  }

  final BreathExercise exercise;

  /// Ein Zyklus, ohne langes Anhalten, wenn das nicht freigeschaltet ist.
  final List<BreathStep> steps;
  late final int cycles;

  int _cycle = 1;
  int _index = 0;
  int _elapsedInStep = 0;
  int _elapsed = 0;
  bool _started = false;
  bool _finished = false;

  bool get finished => _finished;
  int get cycle => _cycle;
  BreathStep? get current => _finished ? null : steps[_index];

  /// Sekunden bis zum Ende des laufenden Schritts.
  int get remainingInStep =>
      _finished ? 0 : steps[_index].seconds - _elapsedInStep;

  int get totalSeconds => cycles * steps.fold(0, (sum, s) => sum + s.seconds);
  int get remainingSeconds => totalSeconds - _elapsed;

  double get progress => totalSeconds == 0 ? 1 : _elapsed / totalSeconds;

  List<BreathEvent> start() {
    if (_started) return const [];
    _started = true;
    if (cycles == 0 || steps.isEmpty) {
      _finished = true;
      return const [BreathFinished()];
    }
    return [_stepEvent(steps[0])];
  }

  BreathStepStarted _stepEvent(BreathStep step) {
    final rapid = step.seconds <= 1;
    final previous = steps[(_index - 1) % steps.length];
    return BreathStepStarted(step, _cycle,
        rapid: rapid,
        startsRapid: rapid && (steps.length == 1 || previous.seconds > 1));
  }

  /// Eine aktive Sekunde ist vergangen.
  List<BreathEvent> tick() {
    if (!_started || _finished) return const [];
    _elapsed++;
    _elapsedInStep++;
    if (_elapsedInStep < steps[_index].seconds) return const [];
    _elapsedInStep = 0;
    _index++;
    if (_index == steps.length) {
      _index = 0;
      _cycle++;
      if (_cycle > cycles) {
        _finished = true;
        _cycle = cycles;
        return const [BreathFinished()];
      }
    }
    return [_stepEvent(steps[_index])];
  }

  /// Beendet die Übung vorzeitig.
  List<BreathEvent> stop() {
    if (_finished) return const [];
    _finished = true;
    return const [BreathFinished()];
  }
}
