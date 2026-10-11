import 'package:flutter/material.dart';

import '../data/database.dart';
import '../programs/program_models.dart';
import 'exercise_image.dart';
import 'exercise_pages.dart';
import 'format.dart';
import 'program_detail_page.dart';
import 'program_editor_page.dart';

/// Trainingsprogramme und Übungsbibliothek.
class ProgramsPage extends StatefulWidget {
  const ProgramsPage({
    super.key,
    required this.db,
    required this.onWorkoutSaved,
  });

  final AppDatabase db;
  final VoidCallback onWorkoutSaved;

  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  ExerciseCategory? _category;

  /// Nur Übungen für diesen Körperbereich; ohne Angabe alle.
  BodyArea? _area;
  List<Program> _programs = [];
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
    _programs = widget.db.programs();
    _exercises = widget.db.exercises();
  });

  Future<void> _openProgram(Program p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgramDetailPage(
          db: widget.db,
          programId: p.id!,
          onWorkoutSaved: widget.onWorkoutSaved,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _newProgram() async {
    final created = await Navigator.of(context).push<Program>(
      MaterialPageRoute(
        builder: (_) => ProgramEditorPage(
          db: widget.db,
          program: Program(
            name: '',
            category: _category ?? ExerciseCategory.yoga,
            items: const [],
          ),
        ),
      ),
    );
    if (created == null) return;
    widget.db.saveProgram(created);
    _load();
  }

  Future<void> _openExercise(Exercise e) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailPage(db: widget.db, exercise: e),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _newExercise() async {
    final created = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseEditorPage(
          exercise: Exercise(
            uuid: widget.db.newExerciseUuid(),
            category: _category ?? ExerciseCategory.yoga,
            name: '',
          ),
        ),
      ),
    );
    if (created == null) return;
    widget.db.saveExercise(created);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    bool shown(ExerciseCategory c) => _category == null || _category == c;
    final programs = _programs.where((p) => shown(p.category)).toList();
    final exercises = _exercises
        .where(
          (e) =>
              shown(e.category) && (_area == null || e.areas.contains(_area)),
        )
        .toList();

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Programme'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Programme'),
                Tab(text: 'Übungen'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add-program',
            onPressed: () => DefaultTabController.of(context).index == 0
                ? _newProgram()
                : _newExercise(),
            icon: const Icon(Icons.add),
            label: const Text('Neu'),
          ),
          body: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                child: TabBarView(
                  children: [
                    programs.isEmpty
                        ? const Center(child: Text('Keine Programme.'))
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 88),
                            children: [
                              for (final p in programs)
                                ListTile(
                                  leading: Icon(p.category.sport.icon),
                                  title: Text(p.name),
                                  subtitle: Text(_summary(p)),
                                  onTap: () => _openProgram(p),
                                ),
                            ],
                          ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonFormField<BodyArea?>(
                            initialValue: _area,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Körperbereich',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Alle'),
                              ),
                              for (final a in BodyArea.values)
                                DropdownMenuItem(
                                  value: a,
                                  child: Text(a.label),
                                ),
                            ],
                            onChanged: (a) => setState(() => _area = a),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: exercises.isEmpty
                              ? const Center(child: Text('Keine Übungen.'))
                              : _ExerciseGrid(
                                  exercises: exercises,
                                  onOpen: _openExercise,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _summary(Program p) => programSummary(p);
}

/// Eckdaten eines Programms in einer Zeile.
String programSummary(Program p) => [
  p.category.label,
  '${p.items.length} Übungen',
  if (p.rounds > 1) '${p.rounds} Runden',
  '${p.hasRepetitions ? 'mind. ' : ''}${formatDuration(p.timedSeconds)}',
].join('  ·  ');

/// Die Übungen als Raster aus Bild und Name.
class _ExerciseGrid extends StatelessWidget {
  const _ExerciseGrid({required this.exercises, required this.onOpen});

  final List<Exercise> exercises;
  final void Function(Exercise) onOpen;

  static const _maxTileWidth = 180.0;
  static const _spacing = 12.0;
  static const _gapBelowImage = 6.0;
  static const _nameLines = 2;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    // Höhe von zwei Textzeilen in der Schriftgröße, die der Nutzer im System
    // eingestellt hat; ein festes Seitenverhältnis würde den Namen bei
    // großer Schrift abschneiden.
    final nameHeight = MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1.43) *
        _nameLines;

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth - 2 * _spacing;
        final columns = (width / _maxTileWidth).ceil().clamp(2, 12);
        final tileWidth = (width - (columns - 1) * _spacing) / columns;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(_spacing, 0, _spacing, 88),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            // Das Bild ist quadratisch; darunter haben zwei Zeilen Platz.
            mainAxisExtent: tileWidth + _gapBelowImage + nameHeight + 2,
          ),
          itemCount: exercises.length,
          itemBuilder: (context, i) {
            final e = exercises[i];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpen(e),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExerciseImage(exercise: e),
                  const SizedBox(height: _gapBelowImage),
                  Text(
                    e.name,
                    style: style,
                    maxLines: _nameLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
