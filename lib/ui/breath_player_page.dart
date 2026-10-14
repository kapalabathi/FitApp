import 'package:flutter/material.dart';

import '../breath/breath_models.dart';
import '../data/models.dart';
import '../session/workout_session.dart';
import 'format.dart';

/// Führt durch eine Atemübung: ein Kreis, der sich mit dem Atem weitet und
/// zusammenzieht, dazu Ansage, Nasenseite und verbleibende Zeit (I-048).
class BreathPlayerPage extends StatefulWidget {
  const BreathPlayerPage({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<BreathPlayerPage> createState() => _BreathPlayerPageState();
}

class _BreathPlayerPageState extends State<BreathPlayerPage> {
  bool _finishing = false;

  WorkoutSession get _session => widget.session;

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    Navigator.of(context).pop(_session.finish());
  }

  Future<void> _confirmStop() async {
    if (_finishing) return;
    if (_session.breath!.finished) return _finish();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atemübung beenden?'),
        content: const Text('Die bisherige Zeit wird gespeichert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weiter atmen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Beenden und speichern'),
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
          final run = _session.breath!;
          final r = _session.recorder;
          final step = run.current;
          final heartRate = r.value(Metric.heartRate)?.round();
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(r.paused
                  ? '${run.exercise.name} – pausiert'
                  : run.exercise.name),
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
                        for (final text in [
                          'noch ${formatDuration(run.remainingSeconds)}',
                          'Zyklus ${run.cycle}/${run.cycles}',
                          heartRate == null ? '♥ –' : '♥ $heartRate',
                        ])
                          Flexible(
                            child: Text(text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: step == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Atemübung beendet.\nBleib noch einen Moment '
                                'ruhig liegen oder sitzen.',
                                style: theme.textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _BreathCircle(
                            step: step,
                            remaining: run.remainingInStep,
                            paused: r.paused,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: step == null
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
                                tooltip: 'Atemübung beenden',
                                iconSize: 32,
                                onPressed: _confirmStop,
                                icon: const Icon(Icons.stop),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(64)),
                                  onPressed: _session.togglePause,
                                  icon: Icon(r.paused
                                      ? Icons.play_arrow
                                      : Icons.pause),
                                  label: Text(r.paused ? 'Weiter' : 'Pause'),
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

/// Der atmende Kreis: groß nach dem Einatmen, klein nach dem Ausatmen. Er
/// wächst und schrumpft über die ganze Dauer des Schritts.
class _BreathCircle extends StatelessWidget {
  const _BreathCircle({
    required this.step,
    required this.remaining,
    required this.paused,
  });

  final BreathStep step;
  final int remaining;
  final bool paused;

  static const _small = 0.42;

  double get _target => switch (step.action) {
        BreathAction.inhale || BreathAction.holdIn => 1,
        BreathAction.exhale || BreathAction.holdOut => _small,
        BreathAction.stroke => _small,
        BreathAction.rest => 0.7,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hold = step.action.isHold;
    return LayoutBuilder(
      builder: (context, box) {
        final edge = (box.biggest.shortestSide - 32).clamp(120.0, 420.0);
        return Center(
          child: SizedBox.square(
            dimension: edge,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: _target),
                  // Während der Pause steht der Kreis still.
                  duration: paused
                      ? Duration.zero
                      : Duration(
                          milliseconds: step.seconds <= 1
                              ? 300
                              : remaining * 1000),
                  curve: Curves.easeInOut,
                  builder: (context, scale, _) => Container(
                    width: edge * scale,
                    height: edge * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hold
                          ? scheme.tertiaryContainer
                          : scheme.primaryContainer,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.action.label,
                      style: theme.textTheme.headlineMedium,
                    ),
                    if (step.nostril != Nostril.both)
                      Text(step.nostril.label,
                          style: theme.textTheme.titleLarge),
                    if (step.seconds > 1)
                      Text('$remaining',
                          style: theme.textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
