import 'package:flutter/material.dart';

import '../breath/breath_models.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../programs/program_models.dart';
import 'exercise_image.dart';
import 'program_start.dart';

/// Hinweis zur sicheren Ausführung, deutlich abgesetzt (I-052).
class CautionNote extends StatelessWidget {
  const CautionNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Atemübung mit Anleitung; von hier aus mit gewählter Dauer starten.
class BreathExercisePage extends StatefulWidget {
  const BreathExercisePage({
    super.key,
    required this.db,
    required this.exercise,
    required this.onWorkoutSaved,
    this.minutes,
  });

  final AppDatabase db;
  final BreathExercise exercise;
  final VoidCallback onWorkoutSaved;

  /// Vorgegebene Dauer, etwa aus einem Kurs; sonst die zuletzt gewählte.
  final int? minutes;

  @override
  State<BreathExercisePage> createState() => _BreathExercisePageState();
}

class _BreathExercisePageState extends State<BreathExercisePage> {
  late final String _minutesKey = 'breath.minutes.${widget.exercise.key}';
  late int _minutes = widget.minutes ??
      int.tryParse(widget.db.setting(_minutesKey) ?? '') ??
      widget.exercise.defaultMinutes;

  bool get _holds => widget.db.flag(breathHoldsKey, fallback: false);

  late final Exercise? _postureImage = widget.db
      .exercises()
      .where((x) => x.builtinKey == widget.exercise.postureImageKey)
      .firstOrNull;

  Future<void> _setHolds(bool on) async {
    if (on) {
      await confirmBreathHolds(context, widget.db);
    } else {
      widget.db.setFlag(breathHoldsKey, false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    widget.db.setSetting(_minutesKey, '$_minutes');
    final workout = await playBreath(
      context,
      widget.db,
      widget.exercise,
      minutes: _minutes,
      devices: heartRateSensors(widget.db, Sport.yoga),
    );
    if (!mounted || workout == null) return;
    await showSavedWorkout(context, widget.db, workout, widget.onWorkoutSaved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'start-breath',
        onPressed: _start,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (_postureImage case final image?)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExerciseImage(exercise: image, size: 180),
              ),
            ),
          if (e.sanskrit.isNotEmpty)
            Text(e.sanskrit,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontStyle: FontStyle.italic)),
          Text('${levelLabel(e.level)}  ·  ${e.posture}',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: 12),
          Text(e.description, style: theme.textTheme.bodyLarge),
          if (e.caution.isNotEmpty) CautionNote(e.caution),
          const SizedBox(height: 12),
          Text('Rhythmus', style: theme.textTheme.titleSmall),
          Text(e.rhythm(holdsAllowed: _holds)),
          if (e.hasLongHolds)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Atemanhalten freigeschaltet'),
              subtitle: Text(_holds
                  ? 'Gilt für alle Atemübungen'
                  : 'Ohne Freischaltung lässt die App das Anhalten weg'),
              value: _holds,
              onChanged: _setHolds,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child:
                    Text('Dauer', style: theme.textTheme.titleSmall),
              ),
              IconButton.outlined(
                tooltip: 'Eine Minute weniger',
                onPressed:
                    _minutes <= 1 ? null : () => setState(() => _minutes--),
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 72,
                child: Text('$_minutes min',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
              ),
              IconButton.outlined(
                tooltip: 'Eine Minute mehr',
                onPressed:
                    _minutes >= 30 ? null : () => setState(() => _minutes++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
