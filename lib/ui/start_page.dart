import 'package:flutter/material.dart';

import '../ble/device_kind.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../session/workout_session.dart';
import 'live_page.dart';
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
  // Sportarten mit GPS oder Übungsprogramm folgen in späteren Meilensteinen.
  static final _sports = Sport.values.where((s) => s.indoorMachine).toList();

  Sport _sport = Sport.treadmill;
  List<SavedDevice> _devices = [];
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
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
    widget.db.setDevicesForSport(_sport, _selected);
    final session = WorkoutSession(
      db: widget.db,
      sport: _sport,
      devices:
          _devices.where((d) => _selected.contains(d.deviceId)).toList(),
    );
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
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutDetailPage(db: widget.db, workoutId: workout.id),
    ));
  }

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
          const SizedBox(height: 24),
          Text('Geräte', style: theme.textTheme.titleMedium),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Noch keine Geräte gemerkt. Füge sie im Bereich „Geräte" hinzu. '
                'Ohne Geräte zeichnet das Training nur die Zeit auf.',
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
