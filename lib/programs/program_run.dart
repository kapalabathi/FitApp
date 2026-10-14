import 'program_models.dart';

/// Die Seite einer Übung, die auf beiden Seiten geübt wird.
enum Side {
  right('Rechte Seite'),
  left('Linke Seite');

  const Side(this.label);

  final String label;
}

/// Ein Schritt beim Abspielen eines Programms: eine Übung oder eine Pause.
class ProgramPhase {
  const ProgramPhase({
    required this.exercise,
    required this.item,
    required this.isRest,
    required this.round,
    this.side,
  });

  /// Bei einer Übung die Übung selbst, bei einer Pause die folgende.
  final Exercise exercise;
  final ProgramItem item;
  final bool isRest;
  final int round;

  /// Bei Übungen auf beiden Seiten die Seite, sonst `null`. Eine Pause mit
  /// [Side.left] ist der Seitenwechsel.
  final Side? side;

  /// Der kurze Wechsel von der rechten zur linken Seite.
  bool get isSideSwitch => isRest && side == Side.left;

  /// Sekunden, nach denen die Phase von selbst endet; `null` bei Übungen
  /// mit Wiederholungen, die der Nutzer selbst abschließt.
  int? get durationS => isSideSwitch
      ? ProgramItem.sideSwitchS
      : isRest
          ? item.restS
          : item.timed
              ? item.amount
              : null;
}

sealed class ProgramEvent {
  const ProgramEvent();
}

class PhaseStarted extends ProgramEvent {
  const PhaseStarted(this.phase);

  final ProgramPhase phase;
}

/// Die laufende Phase endet in [secondsLeft] Sekunden.
class PhaseEnding extends ProgramEvent {
  const PhaseEnding(this.secondsLeft);

  final int secondsLeft;
}

/// Eine Übung ist abgeschlossen, nach [elapsedS] Sekunden. Pausen melden
/// das nicht.
class PhaseCompleted extends ProgramEvent {
  const PhaseCompleted(this.phase, this.elapsedS);

  final ProgramPhase phase;
  final int elapsedS;
}

class ProgramFinished extends ProgramEvent {
  const ProgramFinished();
}

/// Spielt ein Programm ab: Übung, Pause, nächste Übung, über alle Runden.
///
/// Kennt weder Uhr noch Töne: [tick] wird je aktiver Sekunde aufgerufen,
/// [advance] wenn der Nutzer eine Übung abschließt oder überspringt.
class ProgramRun {
  ProgramRun(this.program, Map<String, Exercise> exercisesByUuid)
      : phases = _phases(program, exercisesByUuid);

  /// So viele Sekunden vor dem Ende einer Phase beginnt die Vorwarnung.
  static const warningFromS = 3;

  final Program program;
  final List<ProgramPhase> phases;
  int _index = 0;
  int _elapsedInPhase = 0;
  bool _started = false;

  static List<ProgramPhase> _phases(
      Program program, Map<String, Exercise> exercises) {
    // Übungen, die es nicht mehr gibt, werden ausgelassen.
    final items = [
      for (final i in program.items)
        if (exercises.containsKey(i.exerciseUuid) && i.amount > 0) i,
    ];
    final phases = <ProgramPhase>[];
    for (var round = 1; round <= program.rounds; round++) {
      for (var n = 0; n < items.length; n++) {
        final item = items[n];
        final exercise = exercises[item.exerciseUuid]!;
        if (item.bothSides) {
          for (final side in Side.values) {
            if (side == Side.left) {
              phases.add(ProgramPhase(
                exercise: exercise,
                item: item,
                isRest: true,
                round: round,
                side: side,
              ));
            }
            phases.add(ProgramPhase(
              exercise: exercise,
              item: item,
              isRest: false,
              round: round,
              side: side,
            ));
          }
        } else {
          phases.add(ProgramPhase(
            exercise: exercise,
            item: item,
            isRest: false,
            round: round,
          ));
        }
        final last = round == program.rounds && n == items.length - 1;
        if (item.restS > 0 && !last) {
          // Die Pause zeigt schon, was als Nächstes kommt.
          final upcoming = items[(n + 1) % items.length];
          phases.add(ProgramPhase(
            exercise: exercises[upcoming.exerciseUuid]!,
            item: item,
            isRest: true,
            round: round,
          ));
        }
      }
    }
    return phases;
  }

  bool get finished => _index >= phases.length;
  ProgramPhase? get current => finished ? null : phases[_index];

  /// Die nächste Übung nach der laufenden Phase, Pausen übersprungen.
  ProgramPhase? get nextExercise {
    for (var i = _index + 1; i < phases.length; i++) {
      if (!phases[i].isRest) return phases[i];
    }
    return null;
  }

  /// Sekunden bis zum Ende der Phase; `null`, wenn sie kein Zeitlimit hat.
  int? get remainingInPhase {
    final duration = current?.durationS;
    return duration == null ? null : duration - _elapsedInPhase;
  }

  /// Anteil der abgeschlossenen Übungen, 0 bis 1.
  double get progress {
    final total = phases.where((p) => !p.isRest).length;
    if (total == 0) return 1;
    final done =
        phases.take(_index.clamp(0, phases.length)).where((p) => !p.isRest).length;
    return done / total;
  }

  List<ProgramEvent> start() {
    if (_started) return const [];
    _started = true;
    return finished ? const [ProgramFinished()] : [PhaseStarted(phases[0])];
  }

  /// Eine aktive Sekunde ist vergangen.
  List<ProgramEvent> tick() {
    if (!_started || finished) return const [];
    _elapsedInPhase++;
    final left = remainingInPhase;
    if (left == null) return const [];
    if (left > 0) {
      return left <= warningFromS ? [PhaseEnding(left)] : const [];
    }
    return advance();
  }

  /// Schließt die laufende Phase sofort ab.
  List<ProgramEvent> advance() {
    if (!_started || finished) return const [];
    final done = phases[_index];
    final elapsed = _elapsedInPhase;
    _index++;
    _elapsedInPhase = 0;
    return [
      if (!done.isRest) PhaseCompleted(done, elapsed),
      finished ? const ProgramFinished() : PhaseStarted(phases[_index]),
    ];
  }
}
