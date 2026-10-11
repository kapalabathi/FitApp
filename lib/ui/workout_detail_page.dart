import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/database.dart';
import '../data/models.dart';
import 'format.dart';
import 'line_chart.dart';
import 'route_map.dart';

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
      if (w.ascentM != null) ('Anstieg', '${w.ascentM} m'),
    ];

    List<double?> series(double? Function(Sample) pick) =>
        _series(samples, w.durationS, pick);

    final route = [
      for (final s in samples)
        if (s.latitude != null && s.longitude != null)
          LatLng(s.latitude!, s.longitude!),
    ];
    final laps = db.laps(workoutId);

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
          if (route.length >= 2) ...[
            RouteMap(points: route),
            const SizedBox(height: 24),
          ],
          if (laps.isNotEmpty) ...[
            _LapTable(laps: laps, workout: w),
            const SizedBox(height: 24),
          ],
          for (final chart in [
            LineChart(
              title: 'Puls',
              unit: '/min',
              color: scheme.error,
              values: series((s) => s.heartRate?.toDouble()),
            ),
            LineChart(
              title: 'Geschwindigkeit',
              unit: 'km/h',
              color: scheme.primary,
              values: series((s) => s.speedKmh),
            ),
            LineChart(
              title: 'Leistung',
              unit: 'W',
              color: scheme.tertiary,
              values: series((s) => s.power?.toDouble()),
            ),
            LineChart(
              title: w.sport.cadenceLabel,
              unit: '/min',
              color: scheme.secondary,
              values: series((s) => s.cadence),
            ),
            LineChart(
              title: 'Steigung',
              unit: '%',
              color: scheme.outline,
              values: series((s) => s.incline),
            ),
            LineChart(
              title: 'Höhe',
              unit: 'm',
              color: scheme.outline,
              values: series((s) => s.altitudeM),
            ),
          ])
            Padding(padding: const EdgeInsets.only(bottom: 24), child: chart),
        ],
      ),
    );
  }
}

/// Die Runden eines Trainings mit Zeit, Strecke und Tempo je Runde. Der Rest
/// nach der letzten Marke zählt als eigene Runde.
class _LapTable extends StatelessWidget {
  const _LapTable({required this.laps, required this.workout});

  final List<Lap> laps;
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marks = [
      ...laps,
      if (workout.durationS > laps.last.t)
        Lap(t: workout.durationS, distanceM: workout.distanceM, auto: false),
    ];
    final skiErg = workout.sport == Sport.skiErg;
    var lastT = 0;
    var lastDistance = 0.0;
    final rows = <TableRow>[
      TableRow(
        children: [
          for (final h in [
            'Runde',
            'Zeit',
            'Strecke',
            skiErg ? 'Tempo /500 m' : 'Tempo /km',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(h, style: theme.textTheme.labelMedium),
            ),
        ],
      ),
    ];
    for (var i = 0; i < marks.length; i++) {
      final seconds = marks[i].t - lastT;
      final meters = marks[i].distanceM - lastDistance;
      lastT = marks[i].t;
      lastDistance = marks[i].distanceM;
      final speedKmh = seconds > 0 ? meters / seconds * 3.6 : null;
      rows.add(TableRow(
        children: [
          for (final cell in [
            '${i + 1}',
            formatDuration(seconds),
            '${formatKm(meters)} km',
            formatPace(speedKmh, perMeters: skiErg ? 500 : 1000) ?? '–',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(cell),
            ),
        ],
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Runden', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {0: IntrinsicColumnWidth()},
          defaultColumnWidth: const FlexColumnWidth(),
          children: rows,
        ),
      ],
    );
  }
}
