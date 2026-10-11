import 'package:flutter/material.dart';

import '../ble/device_kind.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../interval/signals.dart';
import '../programs/program_models.dart';
import '../programs/program_run.dart';
import '../session/workout_session.dart';
import 'exercise_image.dart';
import 'program_editor_page.dart';
import 'program_player_page.dart';
import 'programs_page.dart';
import 'workout_actions.dart';
import 'workout_detail_page.dart';

/// Ein Programm mit seinen Übungen; von hier aus starten, bearbeiten,
/// duplizieren und löschen.
class ProgramDetailPage extends StatefulWidget {
  const ProgramDetailPage({
    super.key,
    required this.db,
    required this.programId,
    required this.onWorkoutSaved,
  });

  final AppDatabase db;
  final int programId;
  final VoidCallback onWorkoutSaved;

  @override
  State<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends State<ProgramDetailPage> {
  Program? _program;
  Map<String, Exercise> _exercises = {};
  List<SavedDevice> _sensors = [];
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final program = widget.db
        .programs()
        .where((p) => p.id == widget.programId)
        .firstOrNull;
    final sensors = widget.db
        .devices()
        .where((d) => d.kind == DeviceKind.heartRate)
        .toList();
    final ids = sensors.map((d) => d.deviceId).toSet();
    var selected = program == null
        ? <String>{}
        : widget.db.devicesForSport(program.category.sport).intersection(ids);
    if (selected.isEmpty) selected = ids;
    setState(() {
      _program = program;
      _exercises = {for (final e in widget.db.exercises()) e.uuid: e};
      _sensors = sensors;
      _selected = selected;
    });
  }

  Future<void> _start(Program program) async {
    final sport = program.category.sport;
    widget.db.setDevicesForSport(sport, _selected);
    final session = WorkoutSession(
      db: widget.db,
      sport: sport,
      devices: _sensors.where((d) => _selected.contains(d.deviceId)).toList(),
      program: ProgramRun(program, _exercises),
      signals: createSignals(SignalSettings.load(widget.db)),
    );
    final workout = await Navigator.of(context).push<Workout?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProgramPlayerPage(session: session),
      ),
    );
    if (!mounted || workout == null) return;
    widget.onWorkoutSaved();
    autoUploadIfEnabled(context, widget.db, workout);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutDetailPage(db: widget.db, workoutId: workout.id),
    ));
  }

  Future<void> _edit(Program program) async {
    final edited = await Navigator.of(context).push<Program>(
      MaterialPageRoute(
        builder: (_) => ProgramEditorPage(db: widget.db, program: program),
      ),
    );
    if (edited == null) return;
    widget.db.saveProgram(edited);
    _load();
  }

  void _duplicate(Program program) {
    widget.db.saveProgram(Program(
      name: '${program.name} (Kopie)',
      category: program.category,
      rounds: program.rounds,
      items: program.items,
    ));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Kopie angelegt.')));
  }

  Future<void> _delete(Program program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${program.name}" löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.db.deleteProgram(program.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Programm nicht gefunden.')),
      );
    }
    final theme = Theme.of(context);
    final playable =
        program.items.any((i) => _exercises.containsKey(i.exerciseUuid));
    return Scaffold(
      appBar: AppBar(
        title: Text(program.name),
        actions: [
          IconButton(
            tooltip: 'Bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(program),
          ),
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: () => _duplicate(program),
                child: const Text('Duplizieren'),
              ),
              PopupMenuItem(
                value: () => _delete(program),
                child: const Text('Löschen'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: playable
          ? FloatingActionButton.extended(
              heroTag: 'start-program',
              onPressed: () => _start(program),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(programSummary(program)),
          ),
          for (final item in program.items)
            if (_exercises[item.exerciseUuid] case final exercise?)
              ListTile(
                leading: ExerciseImage(exercise: exercise, size: 56),
                title: Text(exercise.name),
                subtitle: Text([
                  item.timed
                      ? '${item.amount} Sekunden'
                      : '${item.amount} Wiederholungen',
                  if (item.restS > 0) '${item.restS} s Pause',
                ].join('  ·  ')),
              )
            else
              const ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Gelöschte Übung'),
                subtitle: Text('Wird beim Abspielen ausgelassen'),
              ),
          if (_sensors.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Text('Puls aufzeichnen mit',
                  style: theme.textTheme.titleSmall),
            ),
            for (final d in _sensors)
              CheckboxListTile(
                secondary: Icon(d.kind.icon),
                title: Text(d.name),
                value: _selected.contains(d.deviceId),
                onChanged: (on) => setState(() {
                  on == true
                      ? _selected.add(d.deviceId)
                      : _selected.remove(d.deviceId);
                }),
              ),
          ],
        ],
      ),
    );
  }
}
