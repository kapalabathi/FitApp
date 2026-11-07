import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../programs/progression.dart';
import '../programs/program_models.dart';
import 'area_chips.dart';
import 'breath_pages.dart';
import 'exercise_image.dart';
import 'format.dart';

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
      MaterialPageRoute(
          builder: (_) =>
              ExerciseEditorPage(db: widget.db, exercise: _exercise)),
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

  Exercise? _byUuid(String? uuid) => uuid == null
      ? null
      : widget.db.exercises().where((e) => e.uuid == uuid).firstOrNull;

  Widget _variant(String label, Exercise? other) {
    if (other == null) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExerciseImage(exercise: other, size: 48),
      title: Text(other.name),
      subtitle: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExerciseDetailPage(db: widget.db, exercise: other),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = _exercise;
    final facts = [
      e.category.label,
      if (e.poseGroup != null) e.poseGroup!.label,
      if (e.level > 0) levelLabel(e.level),
      if (e.bothSides) 'beide Seiten',
    ];
    final easier = _byUuid(e.easierUuid);
    final harder = _byUuid(e.harderUuid);
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
          if (e.sanskritExtra case final sanskrit?)
            Text(sanskrit,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontStyle: FontStyle.italic)),
          Text(facts.join('  ·  '), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          AreaChips(areas: _exercise.areas),
          if (_exercise.areas.isNotEmpty) const SizedBox(height: 12),
          Text(
            _exercise.description.isEmpty
                ? 'Keine Beschreibung.'
                : _exercise.description,
            style: theme.textTheme.bodyLarge,
          ),
          if (e.caution.isNotEmpty) CautionNote(e.caution),
          if (easier != null || harder != null) ...[
            const SizedBox(height: 12),
            Text('Varianten', style: theme.textTheme.titleMedium),
            _variant('Leichter', easier),
            _variant('Schwerer', harder),
          ],
          _SetHistory(
              db: widget.db, exercise: _exercise, hasHarder: harder != null),
        ],
      ),
    );
  }
}

/// Was mit dieser Übung bisher trainiert wurde: Bestwerte und die Sätze der
/// letzten Trainings (Kraft-Protokoll).
class _SetHistory extends StatelessWidget {
  const _SetHistory({
    required this.db,
    required this.exercise,
    required this.hasHarder,
  });

  final AppDatabase db;
  final Exercise exercise;
  final bool hasHarder;

  /// So viele Trainings zeigt der Verlauf.
  static const _shownDays = 8;

  @override
  Widget build(BuildContext context) {
    final history = db.exerciseHistory(exercise.uuid);
    if (history.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    // Die Sätze je Training, neuestes zuerst.
    final byWorkout = <DateTime, List<SetLog>>{};
    for (final s in history) {
      byWorkout.putIfAbsent(s.performedAt!, () => []).add(s);
    }
    num best(num? Function(SetLog) of) => history
        .map(of)
        .whereType<num>()
        .fold<num>(0, (a, b) => a > b ? a : b);
    final maxWeight = best((s) => s.weightKg);
    final maxReps = best((s) => s.reps);
    final maxSeconds = best((s) => s.seconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        Text('Verlauf', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          [
            '${history.length} Sätze in ${byWorkout.length} Trainings',
            if (maxReps > 0) 'meiste Wiederholungen: $maxReps',
            if (maxWeight > 0)
              'höchstes Gewicht: ${formatDecimal(maxWeight.toDouble())} kg',
            if (maxSeconds > 0) 'längste Dauer: $maxSeconds s',
          ].join('  ·  '),
          style: theme.textTheme.bodySmall,
        ),
        if (progressionAfter(history, hasHarder: hasHarder)
            case final p when p != Progression.none)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(p.label,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
        const SizedBox(height: 8),
        for (final entry in byWorkout.entries.take(_shownDays))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(formatDate(entry.key),
                      style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: Text(entry.value.map(formatSet).join(',  ')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Legt eine Übung an oder ändert sie. Schließt mit der Übung als Ergebnis.
class ExerciseEditorPage extends StatefulWidget {
  const ExerciseEditorPage(
      {super.key, required this.db, required this.exercise});

  /// Für die Auswahl der Varianten.
  final AppDatabase db;

  final Exercise exercise;

  @override
  State<ExerciseEditorPage> createState() => _ExerciseEditorPageState();
}

class _ExerciseEditorPageState extends State<ExerciseEditorPage> {
  late final _name = TextEditingController(text: widget.exercise.name);
  late final _description =
      TextEditingController(text: widget.exercise.description);
  late final _sanskrit = TextEditingController(text: widget.exercise.sanskrit);
  late final _caution = TextEditingController(text: widget.exercise.caution);
  late Exercise _draft = widget.exercise;
  late final Map<String, Exercise> _others = {
    for (final e in widget.db.exercises()) e.uuid: e,
  };

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sanskrit.dispose();
    _caution.dispose();
    super.dispose();
  }

  /// Wählt die leichtere oder schwerere Variante.
  Future<void> _pickVariant({required bool harder}) async {
    final picked = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) =>
            ExercisePickerPage(db: widget.db, category: _draft.category),
      ),
    );
    if (picked == null || picked.uuid == _draft.uuid) return;
    setState(() => _draft = harder
        ? _draft.copyWith(harderUuid: picked.uuid)
        : _draft.copyWith(easierUuid: picked.uuid));
  }

  Widget _variantTile({required bool harder}) {
    final uuid = harder ? _draft.harderUuid : _draft.easierUuid;
    final other = uuid == null ? null : _others[uuid];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(harder ? 'Schwerere Variante' : 'Leichtere Variante'),
      subtitle: Text(other?.name ?? 'Keine'),
      onTap: () => _pickVariant(harder: harder),
      trailing: uuid == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: 'Variante entfernen',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _draft = harder
                  ? _draft.copyWith(clearHarder: true)
                  : _draft.copyWith(clearEasier: true)),
            ),
    );
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
    Navigator.of(context).pop(_draft.copyWith(
      name: name,
      description: _description.text.trim(),
      sanskrit: _sanskrit.text.trim(),
      caution: _caution.text.trim(),
    ));
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
          TextField(
            controller: _sanskrit,
            decoration:
                const InputDecoration(labelText: 'Sanskrit-Name (optional)'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PoseGroup?>(
            initialValue: _draft.poseGroup,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Art der Haltung'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Keine Angabe')),
              for (final g in PoseGroup.values)
                DropdownMenuItem(value: g, child: Text(g.label)),
            ],
            onChanged: (g) => setState(() => _draft = g == null
                ? _draft.copyWith(clearPoseGroup: true)
                : _draft.copyWith(poseGroup: g)),
          ),
          const SizedBox(height: 16),
          Text('Schwierigkeit', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: [
              for (final level in [0, 1, 2, 3])
                ButtonSegment(
                    value: level,
                    label: Text(level == 0 ? '–' : levelLabel(level))),
            ],
            selected: {_draft.level},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                setState(() => _draft = _draft.copyWith(level: s.first)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Beide Seiten'),
            subtitle: const Text(
                'Vorgabe in Programmen: erst rechts, dann links'),
            value: _draft.bothSides,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(bothSides: v)),
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
          const SizedBox(height: 16),
          TextField(
            controller: _caution,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Hinweis zur sicheren Ausführung (optional)'),
          ),
          const SizedBox(height: 8),
          _variantTile(harder: false),
          _variantTile(harder: true),
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
