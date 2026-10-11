import 'interval_models.dart';

/// Was beim Abspielen eines Intervalls passiert.
sealed class IntervalEvent {
  const IntervalEvent();
}

/// Ein neuer Abschnitt hat begonnen.
class StepStarted extends IntervalEvent {
  const StepStarted(this.step);

  final PlannedStep step;
}

/// Der laufende Abschnitt endet in [secondsLeft] Sekunden; [next] folgt,
/// oder das Intervall ist danach zu Ende.
class StepEnding extends IntervalEvent {
  const StepEnding(this.secondsLeft, this.next);

  final int secondsLeft;
  final PlannedStep? next;
}

/// Der letzte Abschnitt ist abgelaufen.
class IntervalFinished extends IntervalEvent {
  const IntervalFinished();
}

/// Spielt die Abschnitte einer Vorlage im Sekundentakt ab.
///
/// Kennt weder Uhr noch Töne: [tick] wird je aktiver Sekunde aufgerufen und
/// meldet, was dabei passiert ist.
class IntervalRun {
  IntervalRun(this.steps);

  /// So viele Sekunden vor einem Wechsel beginnt die Vorwarnung.
  static const warningFromS = 5;

  final List<PlannedStep> steps;
  int _index = 0;
  int _elapsedInStep = 0;
  bool _started = false;

  bool get finished => _index >= steps.length;
  PlannedStep? get current => finished ? null : steps[_index];
  PlannedStep? get next => _index + 1 < steps.length ? steps[_index + 1] : null;

  /// Nummer des laufenden Abschnitts ab 1.
  int get position => finished ? steps.length : _index + 1;

  int get remainingInStep =>
      finished ? 0 : steps[_index].durationS - _elapsedInStep;

  int get remainingTotal {
    if (finished) return 0;
    var rest = remainingInStep;
    for (var i = _index + 1; i < steps.length; i++) {
      rest += steps[i].durationS;
    }
    return rest;
  }

  /// Beginnt den ersten Abschnitt.
  List<IntervalEvent> start() {
    if (_started) return const [];
    _started = true;
    return finished ? const [IntervalFinished()] : [StepStarted(steps[0])];
  }

  /// Eine aktive Sekunde ist vergangen.
  List<IntervalEvent> tick() {
    if (!_started || finished) return const [];
    _elapsedInStep++;
    final left = remainingInStep;
    if (left > 0) {
      return left <= warningFromS ? [StepEnding(left, next)] : const [];
    }
    return _advance();
  }

  /// Springt sofort zum nächsten Abschnitt.
  List<IntervalEvent> skip() {
    if (!_started || finished) return const [];
    return _advance();
  }

  List<IntervalEvent> _advance() {
    _index++;
    _elapsedInStep = 0;
    return finished ? const [IntervalFinished()] : [StepStarted(steps[_index])];
  }
}
