import 'package:flutter/material.dart';

import '../data/database.dart';
import '../interval/interval_models.dart';
import '../interval/signals.dart';
import 'format.dart';
import 'interval_editor_page.dart';

/// Die gespeicherten Intervall-Vorlagen: anlegen, bearbeiten, duplizieren,
/// löschen.
class IntervalsPage extends StatefulWidget {
  const IntervalsPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<IntervalsPage> createState() => _IntervalsPageState();
}

class _IntervalsPageState extends State<IntervalsPage> {
  List<IntervalTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _templates = widget.db.intervalTemplates());

  Future<void> _edit(IntervalTemplate template) async {
    final edited = await Navigator.of(context).push<IntervalTemplate>(
      MaterialPageRoute(
          builder: (_) => IntervalEditorPage(template: template)),
    );
    if (edited == null) return;
    widget.db.saveIntervalTemplate(edited);
    _load();
  }

  void _duplicate(IntervalTemplate t) {
    widget.db.saveIntervalTemplate(IntervalTemplate(
      name: '${t.name} (Kopie)',
      targetKind: t.targetKind,
      blocks: t.blocks,
    ));
    _load();
  }

  Future<void> _delete(IntervalTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${t.name}" löschen?'),
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
    widget.db.deleteIntervalTemplate(t.id!);
    _load();
  }

  Future<void> _signalSettings() async {
    var settings = SignalSettings.load(widget.db);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void change(SignalSettings next) {
            next.save(widget.db);
            setDialogState(() => settings = next);
          }

          return AlertDialog(
            title: const Text('Signale beim Abschnittswechsel'),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Ton'),
                  value: settings.tone,
                  onChanged: (v) => change(SignalSettings(
                      tone: v,
                      vibration: settings.vibration,
                      voice: settings.voice)),
                ),
                SwitchListTile(
                  title: const Text('Vibration'),
                  value: settings.vibration,
                  onChanged: (v) => change(SignalSettings(
                      tone: settings.tone,
                      vibration: v,
                      voice: settings.voice)),
                ),
                SwitchListTile(
                  title: const Text('Sprachansage'),
                  subtitle: const Text('Sagt den nächsten Abschnitt an'),
                  value: settings.voice,
                  onChanged: (v) => change(SignalSettings(
                      tone: settings.tone,
                      vibration: settings.vibration,
                      voice: v)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fertig'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intervalle'),
        actions: [
          IconButton(
            tooltip: 'Signale einstellen',
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: _signalSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-interval',
        onPressed: () => _edit(const IntervalTemplate(name: '', blocks: [])),
        icon: const Icon(Icons.add),
        label: const Text('Neue Vorlage'),
      ),
      body: _templates.isEmpty
          ? const Center(child: Text('Noch keine Vorlagen.'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final t in _templates)
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(t.name),
                    subtitle: Text([
                      formatDuration(t.totalSeconds),
                      '${t.flatten().length} Abschnitte',
                      if (t.targetKind != TargetKind.none) t.targetKind.label,
                    ].join('  ·  ')),
                    onTap: () => _edit(t),
                    trailing: PopupMenuButton<VoidCallback>(
                      onSelected: (action) => action(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: () => _duplicate(t),
                          child: const Text('Duplizieren'),
                        ),
                        PopupMenuItem(
                          value: () => _delete(t),
                          child: const Text('Löschen'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
