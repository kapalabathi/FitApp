import 'package:flutter/material.dart';

import '../breath/breath_models.dart';
import '../data/database.dart';
import '../programs/courses.dart';
import '../programs/program_models.dart';
import '../vision/hero_workouts.dart';
import 'breath_pages.dart';
import 'format.dart';
import 'hero_pages.dart';
import 'program_start.dart';
import 'workout_actions.dart';

/// Ein aufbauender Kurs: die laufende Stufe, die nächste Einheit und der
/// Weg durch alle Stufen (I-049).
class CoursePage extends StatefulWidget {
  const CoursePage({
    super.key,
    required this.db,
    required this.course,
    required this.onWorkoutSaved,
  });

  final AppDatabase db;
  final Course course;
  final VoidCallback onWorkoutSaved;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  late CourseProgress _progress = CourseProgress.load(widget.db, _course);

  /// Die gewählte Einheit der Stufe; ohne Wahl die nächste der Reihe.
  int? _chosen;

  late final Map<String, Exercise> _exercises = {
    for (final e in widget.db.exercises()) e.uuid: e,
  };

  Course get _course => widget.course;

  void _save(CourseProgress progress) {
    progress.save(widget.db, _course);
    setState(() {
      _progress = CourseProgress.load(widget.db, _course);
      _chosen = null;
    });
  }

  Future<void> _start(int session) async {
    final stage = _progress.stage;
    final program = _course.program(stage, session);
    final workout = await playProgram(
      context,
      widget.db,
      program,
      devices: heartRateSensors(widget.db, program.category.sport),
      title: program.name,
    );
    if (!mounted || workout == null) return;
    widget.onWorkoutSaved();
    autoUploadIfEnabled(context, widget.db, workout);
    // Als geschafft zählt eine Einheit, wenn sie wenigstens zur Hälfte
    // durchlaufen ist; ein früher Abbruch zählt nicht.
    final counts = workout.durationS * 2 >= program.timedSeconds;
    if (counts) _save(_progress.sessionDone());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(counts
            ? 'Einheit gespeichert und abgehakt.'
            : 'Training gespeichert; zu früh beendet, um als Einheit zu '
                'zählen.')));
    final s = _course.stages[stage].sessions[session];
    final breath = s.breathKey == null ? null : breathExerciseByKey(s.breathKey!);
    if (breath == null || !counts) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jetzt noch die Atemübung?'),
        content: Text('${breath.name}, ${s.breathMinutes} Minuten. '
            '${breath.posture}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Heute nicht'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Starten'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final breathed = await playBreath(
      context,
      widget.db,
      breath,
      minutes: s.breathMinutes,
      devices: heartRateSensors(widget.db, program.category.sport),
    );
    if (!mounted || breathed == null) return;
    widget.onWorkoutSaved();
    autoUploadIfEnabled(context, widget.db, breathed);
  }

  Future<void> _chooseStage() async {
    final stage = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Stufe wählen'),
        children: [
          for (var i = 0; i < _course.stages.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text('${i + 1}. ${_course.stages[i].title}'),
            ),
        ],
      ),
    );
    if (stage != null) _save(_progress.toStage(_course, stage));
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kurs neu beginnen?'),
        content: const Text('Der Fortschritt beginnt wieder bei Stufe 1. '
            'Die gespeicherten Trainings bleiben erhalten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Neu beginnen'),
          ),
        ],
      ),
    );
    if (confirmed == true) _save(_progress.toStage(_course, 0));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = _progress;
    final stage = _course.stages[p.stage];
    final total = _course.sessionsIn(stage);
    final session = _chosen ?? p.nextSession(_course);
    final s = stage.sessions[session];
    final program = _course.program(p.stage, session);
    final breath =
        s.breathKey == null ? null : breathExerciseByKey(s.breathKey!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_course.name),
        actions: [
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: _chooseStage, child: const Text('Stufe wählen')),
              PopupMenuItem(
                  value: _reset, child: const Text('Kurs neu beginnen')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'start-course',
        onPressed: () => _start(session),
        icon: const Icon(Icons.play_arrow),
        label: Text('${s.title.split(' – ').first} starten'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(_course.description),
          const SizedBox(height: 16),
          Text('Stufe ${p.stage + 1} von ${_course.stages.length}: '
              '${stage.title}',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(stage.focus),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: (p.done / total).clamp(0, 1)),
          const SizedBox(height: 4),
          Text('${p.done.clamp(0, total)} von $total Einheiten '
              '(${stage.weeks} Wochen à ${_course.sessionsPerWeek})'
              '${p.done > total ? ', dazu ${p.done - total} Wiederholungen' : ''}'),
          if (p.stageComplete(_course))
            Card(
              color: scheme.primaryContainer,
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.isLastStage(_course)
                          ? 'Kurs geschafft! Die letzte Stufe lässt sich '
                              'beliebig weiter üben, oder du beginnst eine '
                              'frühere Stufe neu.'
                          : 'Alle Einheiten dieser Stufe sind geschafft. '
                              'Sitzen die Haltungen sicher und ruhig? Dann '
                              'weiter, sonst die Stufe noch einmal üben.',
                    ),
                    if (!p.isLastStage(_course))
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _save(_progress.toStage(_course, p.stage)),
                            child: const Text('Stufe wiederholen'),
                          ),
                          FilledButton(
                            onPressed: () => _save(
                                _progress.toStage(_course, p.stage + 1)),
                            child: Text('Weiter zu Stufe ${p.stage + 2}'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < stage.sessions.length; i++)
                ChoiceChip(
                  label: Text(stage.sessions[i].title.split(' – ').first),
                  selected: i == session,
                  onSelected: (_) => setState(() => _chosen = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.title, style: theme.textTheme.titleMedium),
          Text([
            '${program.items.length} Haltungen',
            formatDuration(program.timedSeconds),
            if (breath != null) 'danach ${breath.name} ${s.breathMinutes} min',
          ].join('  ·  ')),
          const SizedBox(height: 4),
          for (final item in s.items)
            if (_exercises[item.exerciseUuid] case final e?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(e.name)),
                    Text(item.amountLabel,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          if (breath != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BreathExercisePage(
                    db: widget.db,
                    exercise: breath,
                    minutes: s.breathMinutes,
                    onWorkoutSaved: widget.onWorkoutSaved,
                  ),
                )),
                icon: const Icon(Icons.air),
                label: Text('Nur die Atemübung: ${breath.name}'),
              ),
            ),
          const Divider(height: 32),
          Text('Alle Stufen', style: theme.textTheme.titleMedium),
          for (var i = 0; i < _course.stages.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(i < p.stage
                  ? Icons.check_circle
                  : i == p.stage
                      ? Icons.play_circle_outline
                      : Icons.circle_outlined),
              title: Text('${i + 1}. ${_course.stages[i].title}'),
              subtitle: Text(_course.stages[i].focus),
            ),
        ],
      ),
    );
  }
}

/// Kurse und Atemübungen als Liste, für den Bereich „Programme".
class CoursesAndBreathList extends StatelessWidget {
  const CoursesAndBreathList({
    super.key,
    required this.db,
    required this.onWorkoutSaved,
    required this.onChanged,
  });

  final AppDatabase db;
  final VoidCallback onWorkoutSaved;

  /// Nach der Rückkehr von einer Unterseite; der Fortschritt kann sich
  /// geändert haben.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Kurse', style: theme.textTheme.titleMedium),
        ),
        for (final course in builtinCourses)
          Builder(builder: (context) {
            final p = CourseProgress.load(db, course);
            return ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(course.name),
              subtitle: Text(p.started
                  ? 'Stufe ${p.stage + 1} von ${course.stages.length}: '
                      '${course.stages[p.stage].title}'
                  : '${course.totalWeeks} Wochen, '
                      '${course.sessionsPerWeek} Einheiten je Woche'),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CoursePage(
                    db: db,
                    course: course,
                    onWorkoutSaved: onWorkoutSaved,
                  ),
                ));
                onChanged();
              },
            );
          }),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Hero-WODs mit Kamera',
              style: theme.textTheme.titleMedium),
        ),
        for (final w in heroWorkouts)
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text(w.name),
            subtitle: Text([
              '${w.totalReps} Wiederholungen',
              if (heroBestTime(db, w) case final best?)
                'Bestzeit ${formatDuration(best)}',
            ].join('  ·  ')),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HeroWorkoutPage(
                  db: db,
                  workout: w,
                  onWorkoutSaved: onWorkoutSaved,
                ),
              ));
              onChanged();
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Atemübungen', style: theme.textTheme.titleMedium),
        ),
        for (final b in builtinBreathExercises)
          ListTile(
            leading: const Icon(Icons.air),
            title: Text(b.name),
            subtitle: Text([
              if (b.sanskrit.isNotEmpty) b.sanskrit,
              levelLabel(b.level),
            ].join('  ·  ')),
            trailing: b.caution.isEmpty
                ? null
                : const Icon(Icons.warning_amber_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BreathExercisePage(
                db: db,
                exercise: b,
                onWorkoutSaved: onWorkoutSaved,
              ),
            )),
          ),
      ],
    );
  }
}
