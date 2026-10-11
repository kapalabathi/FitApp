import 'package:flutter/material.dart';

import '../interval/interval_models.dart';
import 'format.dart';

/// Bearbeitet eine Intervall-Vorlage. Schließt mit der geänderten Vorlage als
/// Ergebnis oder ohne Ergebnis, wenn verworfen wurde.
class IntervalEditorPage extends StatefulWidget {
  const IntervalEditorPage({super.key, required this.template});

  final IntervalTemplate template;

  @override
  State<IntervalEditorPage> createState() => _IntervalEditorPageState();
}

class _IntervalEditorPageState extends State<IntervalEditorPage> {
  static const _maxRepeat = 99;

  late final TextEditingController _name =
      TextEditingController(text: widget.template.name);
  late TargetKind _kind = widget.template.targetKind;
  late List<IntervalBlock> _blocks = [...widget.template.blocks];
  bool _changed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  IntervalTemplate get _draft => widget.template.copyWith(
        name: _name.text.trim(),
        targetKind: _kind,
        blocks: _blocks,
      );

  void _setBlocks(List<IntervalBlock> blocks) => setState(() {
        _blocks = blocks;
        _changed = true;
      });

  void _replaceBlock(int i, IntervalBlock block) =>
      _setBlocks([..._blocks]..[i] = block);

  Future<void> _editStep(int blockIndex, [int? stepIndex]) async {
    final block = _blocks[blockIndex];
    final step = await showDialog<IntervalStep>(
      context: context,
      builder: (_) => _StepDialog(
        kind: _kind,
        step: stepIndex == null ? null : block.steps[stepIndex],
      ),
    );
    if (step == null) return;
    final steps = [...block.steps];
    stepIndex == null ? steps.add(step) : steps[stepIndex] = step;
    _replaceBlock(blockIndex, IntervalBlock(repeat: block.repeat, steps: steps));
  }

  void _removeStep(int blockIndex, int stepIndex) {
    final block = _blocks[blockIndex];
    _replaceBlock(
      blockIndex,
      IntervalBlock(
        repeat: block.repeat,
        steps: [...block.steps]..removeAt(stepIndex),
      ),
    );
  }

  void _save() {
    final draft = _draft;
    String? problem;
    if (draft.name.isEmpty) {
      problem = 'Bitte einen Namen eingeben.';
    } else if (draft.flatten().isEmpty) {
      problem = 'Die Vorlage braucht mindestens einen Abschnitt.';
    } else if (_kind != TargetKind.none &&
        _blocks.any((b) => b.steps.any((s) => s.target == null))) {
      problem =
          'Jeder Abschnitt braucht einen Zielwert für ${_kind.label}.';
    }
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    Navigator.of(context).pop(draft);
  }

  Future<bool> _confirmDiscard() async {
    if (!_changed) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weiter bearbeiten'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.template.id == null
              ? 'Neue Vorlage'
              : 'Vorlage bearbeiten'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Speichern')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (!_changed) setState(() => _changed = true);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TargetKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Zielwert'),
              items: [
                for (final k in TargetKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) => setState(() {
                _kind = k ?? TargetKind.none;
                _changed = true;
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Gesamtdauer ${formatDuration(_draft.totalSeconds)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (var b = 0; b < _blocks.length; b++)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _blocks[b].repeat == 1
                                  ? 'Einmal'
                                  : '${_blocks[b].repeat} × wiederholen',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Weniger Wiederholungen',
                            icon: const Icon(Icons.remove),
                            onPressed: _blocks[b].repeat <= 1
                                ? null
                                : () => _replaceBlock(
                                    b,
                                    IntervalBlock(
                                        repeat: _blocks[b].repeat - 1,
                                        steps: _blocks[b].steps)),
                          ),
                          IconButton(
                            tooltip: 'Mehr Wiederholungen',
                            icon: const Icon(Icons.add),
                            onPressed: _blocks[b].repeat >= _maxRepeat
                                ? null
                                : () => _replaceBlock(
                                    b,
                                    IntervalBlock(
                                        repeat: _blocks[b].repeat + 1,
                                        steps: _blocks[b].steps)),
                          ),
                          IconButton(
                            tooltip: 'Gruppe löschen',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _setBlocks([..._blocks]..removeAt(b)),
                          ),
                        ],
                      ),
                      for (var s = 0; s < _blocks[b].steps.length; s++)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_blocks[b].steps[s].label.isEmpty
                              ? 'Abschnitt'
                              : _blocks[b].steps[s].label),
                          subtitle: Text([
                            formatDuration(_blocks[b].steps[s].durationS),
                            if (_kind != TargetKind.none)
                              _blocks[b].steps[s].target == null
                                  ? 'Zielwert fehlt'
                                  : _kind.format(_blocks[b].steps[s].target!),
                          ].join('  ·  ')),
                          onTap: () => _editStep(b, s),
                          trailing: IconButton(
                            tooltip: 'Abschnitt löschen',
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeStep(b, s),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () => _editStep(b),
                        icon: const Icon(Icons.add),
                        label: const Text('Abschnitt'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _setBlocks([..._blocks, const IntervalBlock(steps: [])]),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Gruppe hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eingabe eines Abschnitts: Bezeichnung, Dauer, Zielwert.
class _StepDialog extends StatefulWidget {
  const _StepDialog({required this.kind, this.step});

  final TargetKind kind;
  final IntervalStep? step;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late final _label = TextEditingController(text: widget.step?.label ?? '');
  late final _minutes = TextEditingController(
      text: widget.step == null ? '' : '${widget.step!.durationS ~/ 60}');
  late final _seconds = TextEditingController(
      text: widget.step == null ? '' : '${widget.step!.durationS % 60}');
  late final _target = TextEditingController(text: _number(widget.step?.target));
  String? _error;

  @override
  void dispose() {
    for (final c in [_label, _minutes, _seconds, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ganze Zahlen ohne Nachkommastelle, sonst mit Komma.
  static String _number(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble()
        ? v.round().toString()
        : v.toString().replaceAll('.', ',');
  }

  void _submit() {
    final duration = (int.tryParse(_minutes.text.trim()) ?? 0) * 60 +
        (int.tryParse(_seconds.text.trim()) ?? 0);
    final target = double.tryParse(_target.text.trim().replaceAll(',', '.'));
    if (duration <= 0) {
      setState(() => _error = 'Bitte eine Dauer eingeben.');
      return;
    }
    if (widget.kind != TargetKind.none && (target == null || target < 0)) {
      setState(() => _error = 'Bitte einen Zielwert eingeben.');
      return;
    }
    Navigator.of(context).pop(IntervalStep(
      label: _label.text.trim(),
      durationS: duration,
      target: widget.kind == TargetKind.none ? null : target,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    return AlertDialog(
      title: Text(widget.step == null ? 'Neuer Abschnitt' : 'Abschnitt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _label,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Bezeichnung', hintText: 'z. B. Schnell'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minuten'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _seconds,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sekunden'),
                  ),
                ),
              ],
            ),
            if (kind != TargetKind.none)
              TextField(
                controller: _target,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: '${kind.label} (${kind.unit})'),
                onSubmitted: (_) => _submit(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
