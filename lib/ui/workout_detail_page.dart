import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import 'format.dart';
import 'line_chart.dart';

/// Kennzahlen und Verlaufskurven eines gespeicherten Trainings.
class WorkoutDetailPage extends StatelessWidget {
  const WorkoutDetailPage({super.key, required this.db, required this.workoutId});

  final AppDatabase db;
  final int workoutId;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Training löschen?'),
        content: const Text('Das lässt sich nicht rückgängig machen.'),
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
    db.deleteWorkout(workoutId);
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Verteilt die Messpunkte auf eine lückenlose Sekundenachse.
  static List<double?> _series(
      List<Sample> samples, int length, double? Function(Sample) pick) {
    final series = List<double?>.filled(length, null);
    for (final s in samples) {
      if (s.t >= 1 && s.t <= length) series[s.t - 1] = pick(s);
    }
    return series;
  }

  @override
  Widget build(BuildContext context) {
    final w = db.workout(workoutId);
    if (w == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Training nicht gefunden.')),
      );
    }
    final samples = db.samples(workoutId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final skiErg = w.sport == Sport.skiErg;

    final facts = <(String, String)>[
      ('Dauer', formatDuration(w.durationS)),
      if (w.distanceM > 0) ('Distanz', '${formatKm(w.distanceM)} km'),
      if (w.avgSpeedKmh case final v?) ...[
        ('Ø Geschwindigkeit', '${formatDecimal(v)} km/h'),
        if (formatPace(v, perMeters: skiErg ? 500 : 1000) case final pace?)
          (skiErg ? 'Ø Tempo /500 m' : 'Ø Tempo /km', pace),
      ],
      if (w.avgHeartRate != null) ('Ø Puls', '${w.avgHeartRate}'),
      if (w.maxHeartRate != null) ('Max. Puls', '${w.maxHeartRate}'),
      if (w.avgPower != null) ('Ø Leistung', '${w.avgPower} W'),
      if (w.maxPower != null) ('Max. Leistung', '${w.maxPower} W'),
      if (w.avgCadence != null)
        ('Ø ${w.sport.cadenceLabel}', '${w.avgCadence} /min'),
      if (w.energyKcal != null) ('Energie', '${w.energyKcal} kcal'),
    ];

    List<double?> series(double? Function(Sample) pick) =>
        _series(samples, w.durationS, pick);

    return Scaffold(
      appBar: AppBar(
        title: Text(w.title ?? w.sport.label),
        actions: [
          IconButton(
            tooltip: 'Training löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(formatDateTime(w.startedAt), style: theme.textTheme.titleMedium),
          if (w.status == WorkoutStatus.recovered)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Dieses Training wurde nicht regulär beendet und aus den '
                'gesicherten Messwerten wiederhergestellt.',
                style: TextStyle(color: scheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              for (final (label, value) in facts)
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelMedium),
                      Text(value, style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          for (final chart in [
            LineChart(
              title: 'Puls',
              color: scheme.error,
              values: series((s) => s.heartRate?.toDouble()),
            ),
            LineChart(
              title: 'Geschwindigkeit km/h',
              color: scheme.primary,
              values: series((s) => s.speedKmh),
            ),
            LineChart(
              title: 'Leistung W',
              color: scheme.tertiary,
              values: series((s) => s.power?.toDouble()),
            ),
            LineChart(
              title: '${w.sport.cadenceLabel} /min',
              color: scheme.secondary,
              values: series((s) => s.cadence),
            ),
            LineChart(
              title: 'Steigung %',
              color: scheme.outline,
              values: series((s) => s.incline),
            ),
          ])
            Padding(padding: const EdgeInsets.only(bottom: 24), child: chart),
        ],
      ),
    );
  }
}
