import 'package:flutter/material.dart';

import '../ble/device_kind.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../gps/phone_gps.dart';
import '../interval/interval_models.dart';
import '../interval/signals.dart';
import '../session/workout_session.dart';
import 'format.dart';
import 'live_page.dart';
import 'workout_actions.dart';
import 'workout_detail_page.dart';

/// Auswahl von Sportart und Geräten vor dem Trainingsstart.
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

  Sport _sport = Sport.treadmill;
  List<SavedDevice> _devices = [];
  Set<String> _selected = {};
  List<IntervalTemplate> _templates = [];
  IntervalTemplate? _template;
  bool _controlMachine = false;

  @override
  void initState() {
    super.initState();
    // Die Seite wird bei jedem Wechsel hierher neu aufgebaut; die Vorlagen
    // bleiben danach unverändert, damit die Auswahl gültig bleibt.
    _templates = widget.db.intervalTemplates();
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
    });
  }

  Future<void> _start() async {
    if (_sport.usesGps) {
      final problem = await PhoneGps.prepare();
      if (!mounted) return;
      if (problem != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problem)));
        return;
      }
    }
    widget.db.setDevicesForSport(_sport, _selected);
    final template = _template;
    final session = WorkoutSession(
      db: widget.db,
      sport: _sport,
      devices:
          _devices.where((d) => _selected.contains(d.deviceId)).toList(),
      template: template,
      positions: _sport.usesGps ? PhoneGps.positions() : null,
      controlMachine: _canControl && _controlMachine,
      // Im Freien sagt die App auch ohne Intervall jeden Kilometer an.
      signals: template == null && !_sport.usesGps
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

  /// Steuern lässt sich nur, wenn die Vorlage Zielwerte hat und ein
  /// Fitnessgerät mitläuft.
  bool get _canControl =>
      (_template?.targetKind ?? TargetKind.none) != TargetKind.none &&
      _devices.any((d) =>
          d.kind == DeviceKind.fitnessMachine &&
          _selected.contains(d.deviceId));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text('Sportart', style: theme.textTheme.titleMedium),
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
          if (_canControl)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Timer steuert das Gerät'),
              subtitle: Text(
                'Setzt ${_template!.targetKind.label} je Abschnitt selbst. '
                'Noch nicht an deinen Geräten erprobt: beim ersten Mal '
                'vorsichtig testen.',
              ),
              value: _controlMachine,
              onChanged: (v) => setState(() => _controlMachine = v),
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
