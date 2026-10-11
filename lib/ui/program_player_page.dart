import 'package:flutter/material.dart';

import '../data/models.dart';
import '../programs/program_run.dart';
import '../session/workout_session.dart';
import 'exercise_image.dart';
import 'format.dart';

/// Führt durch ein Programm: aktuelle Übung mit Grafik, Countdown oder
/// Wiederholungszahl, Vorschau der nächsten Übung (Lastenheft A-043).
class ProgramPlayerPage extends StatefulWidget {
  const ProgramPlayerPage({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<ProgramPlayerPage> createState() => _ProgramPlayerPageState();
}

class _ProgramPlayerPageState extends State<ProgramPlayerPage> {
  bool _finishing = false;

  WorkoutSession get _session => widget.session;

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    Navigator.of(context).pop(_session.finish());
  }

  Future<void> _confirmStop() async {
    if (_finishing) return;
    if (_session.program!.finished) return _finish();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Programm abbrechen?'),
        content: const Text('Das bisherige Training wird gespeichert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weitermachen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abbrechen und speichern'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop();
      },
      child: ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          final run = _session.program!;
          final r = _session.recorder;
          final phase = run.current;
          final heartRate = r.value(Metric.heartRate)?.round();
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(r.paused
                  ? '${run.program.name} – pausiert'
                  : run.program.name),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: run.progress),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(r.elapsedS),
                            style: theme.textTheme.titleMedium),
                        if (phase != null && run.program.rounds > 1)
                          Text(
                              'Runde ${phase.round} von ${run.program.rounds}',
                              style: theme.textTheme.titleMedium),
                        Text(heartRate == null ? '♥ –' : '♥ $heartRate',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                  Expanded(
                    child: phase == null
                        ? Center(
                            child: Text('Programm beendet',
                                style: theme.textTheme.headlineMedium),
                          )
                        : _PhaseView(run: run, phase: phase),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: phase == null
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(64)),
                            onPressed: _finish,
                            icon: const Icon(Icons.check),
                            label: const Text('Speichern'),
                          )
                        : Row(
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Programm abbrechen',
                                iconSize: 32,
                                onPressed: _confirmStop,
                                icon: const Icon(Icons.stop),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                tooltip: r.paused ? 'Weiter' : 'Pause',
                                iconSize: 32,
                                onPressed: _session.togglePause,
                                icon: Icon(
                                    r.paused ? Icons.play_arrow : Icons.pause),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(64)),
                                  onPressed: r.paused
                                      ? null
                                      : _session.advanceProgram,
                                  icon: Icon(phase.durationS == null
                                      ? Icons.check
                                      : Icons.skip_next),
                                  label: Text(phase.durationS == null
                                      ? 'Fertig'
                                      : phase.isRest
                                          ? 'Pause überspringen'
                                          : 'Überspringen'),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhaseView extends StatelessWidget {
  const _PhaseView({required this.run, required this.phase});

  final ProgramRun run;
  final ProgramPhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = run.remainingInPhase;
    final next = run.nextExercise;
    final counter = Text(
      remaining != null ? formatDuration(remaining) : '${phase.item.amount} ×',
      style: theme.textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: remaining != null && remaining <= ProgramRun.warningFromS
            ? scheme.error
            : null,
      ),
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Text(
          phase.isRest ? 'Pause – danach:' : phase.exercise.name,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (phase.isRest)
          Text(phase.exercise.name,
              style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: phase.isRest ? 200 : 360),
            child: Opacity(
              opacity: phase.isRest ? 0.6 : 1,
              child: ExerciseImage(exercise: phase.exercise),
            ),
          ),
        ),
        Center(child: counter),
        if (!phase.isRest && phase.exercise.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(phase.exercise.description,
                style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          ),
        if (!phase.isRest)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              next == null ? 'Letzte Übung' : 'Danach: ${next.exercise.name}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
