import 'package:flutter/material.dart';

import '../ble/device_kind.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../gps/phone_gps.dart';
import '../interval/interval_models.dart';
import '../interval/signals.dart';
import '../programs/program_models.dart';
import '../session/auto_pause.dart';
import '../session/quick_start.dart';
import '../session/workout_session.dart';
import 'format.dart';
import 'live_page.dart';
import 'program_detail_page.dart';
import 'tile_settings_page.dart';
import 'workout_actions.dart';
import 'workout_detail_page.dart';

/// Auswahl von Sportart und Geräten vor dem Trainingsstart, dazu der
/// Schnellstart für zuletzt genutzte und als Favorit markierte Trainings.
class StartPage extends StatefulWidget {
  const StartPage({super.key, required this.db, required this.onWorkoutSaved});

  final AppDatabase db;
  final VoidCallback onWorkoutSaved;

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  // Yoga, Crossfit, Calisthenics und Dehnen laufen über den Bereich
  // „Programme".
  static final _sports = Sport.values.where((s) => s.freeRecording).toList();

  static const _autoPauseKey = 'training.autoPause';

  Sport _sport = Sport.treadmill;
  List<SavedDevice> _devices = [];
  Set<String> _selected = {};
  List<IntervalTemplate> _templates = [];
  List<Program> _programs = [];
  List<QuickStart> _quickStarts = [];
  IntervalTemplate? _template;
  bool _controlMachine = false;

  @override
  void initState() {
    super.initState();
    // Die Seite wird bei jedem Wechsel hierher neu aufgebaut; Vorlagen und
    // Programme bleiben danach unverändert, damit die Auswahl gültig bleibt.
    _templates = widget.db.intervalTemplates();
    _programs = widget.db.programs();
    _load();
  }

  void _load() {
    final devices = widget.db.devices();
    final ids = devices.map((d) => d.deviceId).toSet();
    var selected = widget.db.devicesForSport(_sport).intersection(ids);
    if (selected.isEmpty) {
      // Erstes Training in dieser Sportart: Pulssensoren sind immer sinnvoll.
      selected = {
        for (final d in devices)
          if (d.kind == DeviceKind.heartRate) d.deviceId,
      };
    }
    setState(() {
      _devices = devices;
      _selected = selected;
      _quickStarts = QuickStarts.load(widget.db);
    });
  }

  bool get _autoPause => widget.db.flag(_autoPauseKey, fallback: true);

  /// Steuern lässt sich nur, wenn die Vorlage Zielwerte hat und ein
  /// Fitnessgerät mitläuft.
  bool _controllable(IntervalTemplate? template, Set<String> selected) =>
      (template?.targetKind ?? TargetKind.none) != TargetKind.none &&
      _devices.any((d) =>
          d.kind == DeviceKind.fitnessMachine && selected.contains(d.deviceId));

  Future<void> _start() => _startWith(
        sport: _sport,
        selected: _selected,
        template: _template,
        controlMachine: _controlMachine,
      );

  Future<void> _startWith({
    required Sport sport,
    required Set<String> selected,
    required IntervalTemplate? template,
    required bool controlMachine,
  }) async {
    if (sport.usesGps) {
      final problem = await PhoneGps.prepare();
      if (!mounted) return;
      if (problem != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problem)));
        return;
      }
    }
    final control = controlMachine && _controllable(template, selected);
    widget.db.setDevicesForSport(sport, selected);
    QuickStarts.remember(
      widget.db,
      QuickStart(
        sport: sport,
        deviceIds: selected,
        templateId: template?.id,
        controlMachine: control,
      ),
    );
    final session = WorkoutSession(
      db: widget.db,
      sport: sport,
      devices: _devices.where((d) => selected.contains(d.deviceId)).toList(),
      template: template,
      positions: sport.usesGps ? PhoneGps.positions() : null,
      controlMachine: control,
      autoPause: _autoPause,
      // Im Freien sagt die App auch ohne Intervall jeden Kilometer an.
      signals: template == null && !sport.usesGps
          ? const SilentSignals()
          : createSignals(SignalSettings.load(widget.db)),
    );
    if (!mounted) return;
    final workout = await Navigator.of(context).push<Workout?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LivePage(session: session),
      ),
    );
    if (!mounted) return;
    _load();
    if (workout == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nichts aufgezeichnet, Training verworfen.')));
      return;
    }
    widget.onWorkoutSaved();
    autoUploadIfEnabled(context, widget.db, workout);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutDetailPage(db: widget.db, workoutId: workout.id),
    ));
  }

  /// Startet einen Schnellstart-Eintrag: ein freies Training sofort, ein
  /// Programm über dessen Seite.
  Future<void> _runQuickStart(QuickStart q) async {
    final programId = q.programId;
    if (programId != null) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProgramDetailPage(
          db: widget.db,
          programId: programId,
          onWorkoutSaved: widget.onWorkoutSaved,
        ),
      ));
      if (mounted) _load();
      return;
    }
    final known = _devices.map((d) => d.deviceId).toSet();
    await _startWith(
      sport: q.sport,
      selected: q.deviceIds.intersection(known),
      template: _templates.where((t) => t.id == q.templateId).firstOrNull,
      controlMachine: q.controlMachine,
    );
  }

  /// Titel und Untertitel eines Schnellstart-Eintrags, oder `null`, wenn
  /// sein Programm oder seine Vorlage nicht mehr existiert.
  ({String title, String subtitle})? _describe(QuickStart q) {
    if (q.programId != null) {
      final program = _programs.where((p) => p.id == q.programId).firstOrNull;
      return program == null
          ? null
          : (title: program.name, subtitle: 'Programm');
    }
    IntervalTemplate? template;
    if (q.templateId != null) {
      template = _templates.where((t) => t.id == q.templateId).firstOrNull;
      if (template == null) return null;
    }
    final names = [
      for (final d in _devices)
        if (q.deviceIds.contains(d.deviceId)) d.name,
    ];
    return (
      title: template == null
          ? q.sport.label
          : '${q.sport.label} · ${template.name}',
      subtitle: names.isEmpty ? 'Ohne Geräte' : names.join(', '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canControl = _controllable(_template, _selected);
    final quick = [
      for (final q in _quickStarts)
        if (_describe(q) case final text?) (entry: q, text: text),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Training starten')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'start-workout',
        onPressed: _start,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (quick.isNotEmpty) ...[
            Text('Schnellstart', style: theme.textTheme.titleMedium),
            for (final q in quick)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(q.entry.sport.icon),
                title: Text(q.text.title),
                subtitle: Text(q.text.subtitle),
                onTap: () => _runQuickStart(q.entry),
                onLongPress: () {
                  QuickStarts.remove(widget.db, q.entry);
                  _load();
                },
                trailing: IconButton(
                  tooltip: q.entry.pinned
                      ? 'Aus den Favoriten nehmen'
                      : 'Als Favorit merken',
                  icon: Icon(q.entry.pinned ? Icons.star : Icons.star_border),
                  onPressed: () {
                    QuickStarts.setPinned(
                        widget.db, q.entry, !q.entry.pinned);
                    _load();
                  },
                ),
              ),
            const Divider(height: 32),
          ],
          Row(
            children: [
              Expanded(
                child: Text('Sportart', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      TileSettingsPage(db: widget.db, sport: _sport),
                )),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Anzeige'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _sports)
                ChoiceChip(
                  avatar: Icon(s.icon, size: 18),
                  label: Text(s.label),
                  selected: s == _sport,
                  onSelected: (_) {
                    _sport = s;
                    _load();
                  },
                ),
            ],
          ),
          if (_sport.usesGps)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Die Strecke wird mit dem GPS dieses Geräts aufgezeichnet, '
                'auch bei ausgeschaltetem Display.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 24),
          DropdownButtonFormField<IntervalTemplate?>(
            initialValue: _template,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Intervall'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Ohne Intervall')),
              for (final t in _templates)
                DropdownMenuItem(
                  value: t,
                  child: Text('${t.name} (${formatDuration(t.totalSeconds)})'),
                ),
            ],
            onChanged: (t) => setState(() => _template = t),
          ),
          if (canControl)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Timer steuert das Gerät'),
              subtitle: Text(
                'Setzt ${_template!.targetKind.label} je Abschnitt selbst.',
              ),
              value: _controlMachine,
              onChanged: (v) => setState(() => _controlMachine = v),
            ),
          if (AutoPause.forSport(_sport) != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatische Pause'),
              subtitle: const Text(
                  'Hält die Zeit an, solange keine Bewegung gemessen wird'),
              value: _autoPause,
              onChanged: (v) =>
                  setState(() => widget.db.setFlag(_autoPauseKey, v)),
            ),
          const SizedBox(height: 24),
          Text('Geräte', style: theme.textTheme.titleMedium),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Noch keine Geräte gemerkt. Füge sie im Bereich „Geräte" hinzu.',
              ),
            ),
          for (final d in _devices)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(d.kind.icon),
              title: Text(d.name),
              subtitle: Text(d.kind.label),
              value: _selected.contains(d.deviceId),
              onChanged: (on) => setState(() {
                on == true
                    ? _selected.add(d.deviceId)
                    : _selected.remove(d.deviceId);
              }),
            ),
        ],
      ),
    );
  }
}
