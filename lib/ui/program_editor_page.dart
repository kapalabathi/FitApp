import 'package:flutter/material.dart';

import '../data/database.dart';
import '../programs/program_models.dart';
import 'exercise_image.dart';
import 'exercise_pages.dart';

/// Stellt ein Programm zusammen: Name, Bereich, Runden und die Übungen in
/// ihrer Reihenfolge. Schließt mit dem Programm als Ergebnis.
class ProgramEditorPage extends StatefulWidget {
  const ProgramEditorPage({super.key, required this.db, required this.program});

  final AppDatabase db;
  final Program program;

  @override
  State<ProgramEditorPage> createState() => _ProgramEditorPageState();
}

class _ProgramEditorPageState extends State<ProgramEditorPage> {
  static const _maxRounds = 50;
  static const _defaultSeconds = 30;
  static const _defaultRepetitions = 10;
  static const _defaultRestS = 15;

  late final _name = TextEditingController(text: widget.program.name);
  late Program _draft = widget.program;
  late final Map<String, Exercise> _exercises = {
    for (final e in widget.db.exercises()) e.uuid: e,
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setItems(List<ProgramItem> items) =>
      setState(() => _draft = _draft.copyWith(items: items));

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) =>
            ExercisePickerPage(db: widget.db, category: _draft.category),
      ),
    );
    if (exercise == null) return;
    _setItems([
      ..._draft.items,
      ProgramItem(
        exerciseUuid: exercise.uuid,
        timed: exercise.timed,
        amount: exercise.timed ? _defaultSeconds : _defaultRepetitions,
        restS: _defaultRestS,
        bothSides: exercise.bothSides,
      ),
    ]);
  }

  Future<void> _editItem(int index) async {
    final edited = await showDialog<ProgramItem>(
      context: context,
      builder: (_) => _ItemDialog(
        item: _draft.items[index],
        name: _exercises[_draft.items[index].exerciseUuid]?.name ?? 'Übung',
      ),
    );
    if (edited == null) return;
    _setItems([..._draft.items]..[index] = edited);
  }

  void _save() {
    final name = _name.text.trim();
    final problem = name.isEmpty
        ? 'Bitte einen Namen eingeben.'
        : _draft.items.isEmpty
            ? 'Das Programm braucht mindestens eine Übung.'
            : null;
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    Navigator.of(context).pop(_draft.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final items = _draft.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.program.id == null ? 'Neues Programm' : 'Programm bearbeiten'),
        actions: [TextButton(onPressed: _save, child: const Text('Speichern'))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-program-item',
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Übung'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ExerciseCategory>(
                        initialValue: _draft.category,
                        decoration: const InputDecoration(labelText: 'Bereich'),
                        items: [
                          for (final c in ExerciseCategory.values)
                            DropdownMenuItem(value: c, child: Text(c.label)),
                        ],
                        onChanged: (c) => setState(
                            () => _draft = _draft.copyWith(category: c)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      tooltip: 'Weniger Runden',
                      icon: const Icon(Icons.remove),
                      onPressed: _draft.rounds <= 1
                          ? null
                          : () => setState(() => _draft =
                              _draft.copyWith(rounds: _draft.rounds - 1)),
                    ),
                    Text(_draft.rounds == 1
                        ? '1 Runde'
                        : '${_draft.rounds} Runden'),
                    IconButton(
                      tooltip: 'Mehr Runden',
                      icon: const Icon(Icons.add),
                      onPressed: _draft.rounds >= _maxRounds
                          ? null
                          : () => setState(() => _draft =
                              _draft.copyWith(rounds: _draft.rounds + 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('Füge über „Übung" die erste Übung hinzu.'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: items.length,
                    onReorderItem: (from, to) {
                      final moved = [...items];
                      moved.insert(to, moved.removeAt(from));
                      _setItems(moved);
                    },
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final exercise = _exercises[item.exerciseUuid];
                      return ListTile(
                        // Dieselbe Übung kann mehrfach vorkommen; die Position
                        // macht den Schlüssel eindeutig.
                        key: ValueKey('$i-${item.exerciseUuid}'),
                        leading: exercise == null
                            ? const Icon(Icons.help_outline)
                            : ExerciseImage(exercise: exercise, size: 48),
                        title: Text(exercise?.name ?? 'Gelöschte Übung'),
                        subtitle: Text([
                          item.amountLabel,
                          if (item.restS > 0) '${item.restS} s Pause',
                        ].join('  ·  ')),
                        onTap: () => _editItem(i),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Entfernen',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  _setItems([...items]..removeAt(i)),
                            ),
                            // Platz für den Anfasser zum Verschieben
                            const SizedBox(width: 24),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Vorgabe einer Übung im Programm: Zeit oder Wiederholungen, Pause danach.
enum _Unit {
  seconds('Zeit', 'Sekunden'),
  breaths('Atemzüge', 'Atemzüge'),
  reps('Wdh.', 'Wiederholungen');

  const _Unit(this.short, this.label);

  final String short;
  final String label;
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.item, required this.name});

  final ProgramItem item;
  final String name;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late _Unit _unit = widget.item.breaths
      ? _Unit.breaths
      : widget.item.timed
          ? _Unit.seconds
          : _Unit.reps;
  late bool _bothSides = widget.item.bothSides;
  late final _amount = TextEditingController(text: '${widget.item.amount}');
  late final _rest = TextEditingController(text: '${widget.item.restS}');
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _rest.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final rest = int.tryParse(_rest.text.trim()) ?? 0;
    if (amount <= 0 || rest < 0) {
      setState(() => _error = 'Bitte eine Zahl größer als 0 eingeben.');
      return;
    }
    Navigator.of(context)
        .pop(widget.item.copyWith(
            timed: _unit != _Unit.reps,
            breaths: _unit == _Unit.breaths,
            amount: amount,
            restS: rest,
            bothSides: _bothSides));
  }

  /// Beim Wechsel zwischen Zeit und Atemzügen bleibt die Dauer gleich.
  void _setUnit(_Unit unit) {
    final amount = int.tryParse(_amount.text.trim());
    if (amount != null) {
      if (_unit == _Unit.seconds && unit == _Unit.breaths) {
        final breaths = (amount / ProgramItem.breathS).round();
        _amount.text = '${breaths < 1 ? 1 : breaths}';
      } else if (_unit == _Unit.breaths && unit == _Unit.seconds) {
        _amount.text = '${amount * ProgramItem.breathS}';
      }
    }
    setState(() => _unit = unit);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_Unit>(
              segments: [
                for (final u in _Unit.values)
                  ButtonSegment(value: u, label: Text(u.short)),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => _setUnit(s.first),
            ),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _unit.label,
                helperText: _unit == _Unit.breaths
                    ? 'Ein Atemzug zählt ${ProgramItem.breathS} Sekunden'
                    : null,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Beide Seiten'),
              subtitle: const Text('Erst rechts, dann links'),
              value: _bothSides,
              onChanged: (v) => setState(() => _bothSides = v),
            ),
            TextField(
              controller: _rest,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Pause danach (Sekunden)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Übernehmen')),
      ],
    );
  }
}
