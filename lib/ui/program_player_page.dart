import 'package:flutter/material.dart';

import '../data/models.dart';
import '../programs/program_models.dart';
import '../programs/program_run.dart';
import '../session/workout_session.dart';
import 'area_chips.dart';
import 'breath_pages.dart';
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

  // Die Eingaben zum laufenden Satz. Sie gelten für eine Übung und werden
  // beim Wechsel zur nächsten neu vorbelegt.
  ProgramPhase? _inputFor;
  int _reps = 0;
  String _weight = '';

  WorkoutSession get _session => widget.session;

  late final Map<String, Exercise> _exercises = {
    for (final e in _session.recorder.db.exercises()) e.uuid: e,
  };

  /// Belegt die Eingaben für [phase] vor: die geplanten Wiederholungen und
  /// das zuletzt bei dieser Übung verwendete Gewicht.
  void _prepareInput(ProgramPhase phase) {
    if (identical(_inputFor, phase)) return;
    _inputFor = phase;
    _reps = phase.item.amount;
    final last = _session.recorder.db.lastWeight(phase.exercise.uuid);
    _weight = last == null
        ? ''
        : last == last.roundToDouble()
            ? last.round().toString()
            : formatDecimal(last);
  }

  void _advance(ProgramPhase phase) {
    if (phase.isRest || phase.item.timed) {
      _session.advanceProgram();
      return;
    }
    _session.advanceProgram(
      reps: _reps,
      weightKg: double.tryParse(_weight.trim().replaceAll(',', '.')),
    );
  }

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
          final counted =
              phase != null && !phase.isRest && !phase.item.timed;
          if (counted) _prepareInput(phase);
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
                        : _PhaseView(
                            run: run,
                            phase: phase,
                            easier: _exercises[phase.exercise.easierUuid],
                            harder: _exercises[phase.exercise.harderUuid],
                            onSwap: _session.swapExercise,
                          ),
                  ),
                  if (counted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Row(
                        children: [
                          IconButton.outlined(
                            tooltip: 'Eine Wiederholung weniger',
                            onPressed: _reps <= 0
                                ? null
                                : () => setState(() => _reps--),
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 72,
                            child: Text(
                              '$_reps ×',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          IconButton.outlined(
                            tooltip: 'Eine Wiederholung mehr',
                            onPressed: () => setState(() => _reps++),
                            icon: const Icon(Icons.add),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              // Je Übung ein eigenes Feld, damit die
                              // Vorbelegung der nächsten Übung greift.
                              key: ValueKey(phase),
                              initialValue: _weight,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Gewicht kg',
                                isDense: true,
                              ),
                              onChanged: (v) => _weight = v,
                            ),
                          ),
                        ],
                      ),
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
                                  onPressed:
                                      r.paused ? null : () => _advance(phase),
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
  const _PhaseView({
    required this.run,
    required this.phase,
    this.easier,
    this.harder,
    required this.onSwap,
  });

  final ProgramRun run;
  final ProgramPhase phase;

  /// Die leichtere und schwerere Variante der Übung, falls es sie gibt.
  final Exercise? easier;
  final Exercise? harder;
  final void Function(Exercise) onSwap;

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

    final side = phase.side;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Text(
          phase.isSideSwitch
              ? 'Seite wechseln'
              : phase.isRest
                  ? 'Pause – danach:'
                  : phase.exercise.name,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (phase.isRest)
          Text(
              phase.isSideSwitch
                  ? '${phase.exercise.name}, linke Seite'
                  : phase.exercise.name,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center),
        if (!phase.isRest && side != null)
          Text(side.label,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: scheme.primary),
              textAlign: TextAlign.center),
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
        if (!phase.isRest)
          AreaChips(areas: phase.exercise.areas, centered: true),
        if (!phase.isRest && (easier != null || harder != null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (easier case final e?)
                  OutlinedButton.icon(
                    onPressed: () => onSwap(e),
                    icon: const Icon(Icons.south, size: 18),
                    label: Text('Leichter: ${e.name}'),
                  ),
                if (harder case final e?)
                  OutlinedButton.icon(
                    onPressed: () => onSwap(e),
                    icon: const Icon(Icons.north, size: 18),
                    label: Text('Schwerer: ${e.name}'),
                  ),
              ],
            ),
          ),
        if (!phase.isRest && phase.exercise.caution.isNotEmpty)
          CautionNote(phase.exercise.caution),
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
              next == null
                  ? 'Letzte Übung'
                  : identical(next.item, phase.item) &&
                          next.round == phase.round
                      ? 'Danach: linke Seite'
                      : 'Danach: ${next.exercise.name}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
