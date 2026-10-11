import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import 'format.dart';
import 'workout_detail_page.dart';

enum _Period {
  all('Gesamt', null),
  week('7 Tage', 7),
  month('30 Tage', 30),
  year('365 Tage', 365);

  const _Period(this.label, this.days);

  final String label;
  final int? days;
}

/// Liste aller Trainings, filterbar nach Sportart und Zeitraum.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Sport? _sport;
  _Period _period = _Period.all;
  List<Workout> _workouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final days = _period.days;
    setState(() {
      _workouts = widget.db.workouts(
        sport: _sport,
        since: days == null
            ? null
            : DateTime.now().subtract(Duration(days: days)),
      );
    });
  }

  Future<void> _open(Workout w) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutDetailPage(db: widget.db, workoutId: w.id),
    ));
    // Das Training kann in der Detailansicht gelöscht worden sein.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Sport?>(
                    initialValue: _sport,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sportart'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Alle')),
                      for (final s in Sport.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (s) {
                      _sport = s;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<_Period>(
                    initialValue: _period,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Zeitraum'),
                    items: [
                      for (final p in _Period.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (p) {
                      _period = p ?? _Period.all;
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _workouts.isEmpty
                ? const Center(child: Text('Keine Trainings in dieser Auswahl.'))
                : ListView.separated(
                    itemCount: _workouts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final w = _workouts[i];
                      final facts = [
                        formatDuration(w.durationS),
                        if (w.distanceM > 0) '${formatKm(w.distanceM)} km',
                        if (w.avgHeartRate != null) '♥ ${w.avgHeartRate}',
                        if (w.avgPower != null) '${w.avgPower} W',
                      ];
                      return ListTile(
                        leading: Icon(w.sport.icon),
                        title: Text(w.title ?? w.sport.label),
                        subtitle: Text(
                            '${formatDateTime(w.startedAt)}\n${facts.join('  ·  ')}'),
                        isThreeLine: true,
                        onTap: () => _open(w),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
