import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../programs/program_models.dart';
import 'area_chips.dart';
import 'exercise_image.dart';

/// Eine Übung mit Grafik und Anleitung; von hier aus bearbeiten und löschen.
class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({super.key, required this.db, required this.exercise});

  final AppDatabase db;
  final Exercise exercise;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late Exercise _exercise = widget.exercise;

  Future<void> _edit() async {
    final edited = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => ExerciseEditorPage(exercise: _exercise)),
    );
    if (edited == null) return;
    widget.db.saveExercise(edited);
    setState(() => _exercise = edited);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${_exercise.name}" löschen?'),
        content: const Text(
            'Programme, die diese Übung enthalten, lassen sie künftig aus.'),
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
    widget.db.deleteExercise(_exercise.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_exercise.name),
        actions: [
          IconButton(
            tooltip: 'Bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ExerciseImage(exercise: _exercise),
            ),
          ),
          const SizedBox(height: 16),
          Text(_exercise.category.label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          AreaChips(areas: _exercise.areas),
          if (_exercise.areas.isNotEmpty) const SizedBox(height: 12),
          Text(
            _exercise.description.isEmpty
                ? 'Keine Beschreibung.'
                : _exercise.description,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Legt eine Übung an oder ändert sie. Schließt mit der Übung als Ergebnis.
class ExerciseEditorPage extends StatefulWidget {
  const ExerciseEditorPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseEditorPage> createState() => _ExerciseEditorPageState();
}

class _ExerciseEditorPageState extends State<ExerciseEditorPage> {
  late final _name = TextEditingController(text: widget.exercise.name);
  late final _description =
      TextEditingController(text: widget.exercise.description);
  late Exercise _draft = widget.exercise;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      // Die Auswahl liegt in einem Zwischenspeicher, den Android leeren darf;
      // die App behält deshalb eine eigene Kopie.
      final dir = Directory(
          p.join((await getApplicationSupportDirectory()).path, 'exercises'));
      await dir.create(recursive: true);
      final target = p.join(dir.path,
          '${_draft.uuid}-${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}');
      await File(picked.path).copy(target);
      if (mounted) setState(() => _draft = _draft.copyWith(imagePath: target));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bild konnte nicht übernommen werden: $e')));
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte einen Namen eingeben.')));
      return;
    }
    Navigator.of(context).pop(
        _draft.copyWith(name: name, description: _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.id == null ? 'Neue Übung' : 'Übung bearbeiten'),
        actions: [TextButton(onPressed: _save, child: const Text('Speichern'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseImage(exercise: _draft, size: 120),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Eigenes Bild wählen'),
                    ),
                    if (_draft.imagePath != null)
                      TextButton(
                        onPressed: () => setState(
                            () => _draft = _draft.copyWith(clearImage: true)),
                        child: const Text('Eigenes Bild entfernen'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ExerciseCategory>(
            initialValue: _draft.category,
            decoration: const InputDecoration(labelText: 'Bereich'),
            items: [
              for (final c in ExerciseCategory.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (c) =>
                setState(() => _draft = _draft.copyWith(category: c)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auf Zeit'),
            subtitle: const Text(
                'Vorgabe in Programmen: Sekunden statt Wiederholungen'),
            value: _draft.timed,
            onChanged: (v) => setState(() => _draft = _draft.copyWith(timed: v)),
          ),
          const SizedBox(height: 8),
          Text('Trainierte Bereiche',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final area in BodyArea.values)
                FilterChip(
                  label: Text(area.label),
                  selected: _draft.areas.contains(area),
                  onSelected: (on) => setState(() {
                    // In der festen Reihenfolge der Bereiche ablegen,
                    // nicht in der des Antippens.
                    _draft = _draft.copyWith(areas: [
                      for (final a in BodyArea.values)
                        if (a == area ? on : _draft.areas.contains(a)) a,
                    ]);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Beschreibung'),
          ),
        ],
      ),
    );
  }
}

/// Auswahl einer Übung für ein Programm. Schließt mit der gewählten Übung.
class ExercisePickerPage extends StatefulWidget {
  const ExercisePickerPage({super.key, required this.db, required this.category});

  final AppDatabase db;

  /// Der Bereich des Programms; seine Übungen sind vorausgewählt.
  final ExerciseCategory category;

  @override
  State<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends State<ExercisePickerPage> {
  late ExerciseCategory? _category = widget.category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final exercises = widget.db
        .exercises(category: _category)
        .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Übung wählen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Suchen'),
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final c in [null, ...ExerciseCategory.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c?.label ?? 'Alle'),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final e in exercises)
                  ListTile(
                    leading: ExerciseImage(exercise: e, size: 48),
                    title: Text(e.name),
                    subtitle: Text([
                      e.category.label,
                      ...e.areas.map((a) => a.label),
                    ].join('  ·  ')),
                    onTap: () => Navigator.of(context).pop(e),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
