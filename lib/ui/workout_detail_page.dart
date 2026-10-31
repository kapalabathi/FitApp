import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../stats/compare.dart';
import '../stats/stats.dart';
import 'compare_page.dart';
import 'format.dart';
import 'line_chart.dart';
import 'route_map.dart';
import 'stats_views.dart';
import 'workout_actions.dart';

/// Kennzahlen und Verlaufskurven eines gespeicherten Trainings.
class WorkoutDetailPage extends StatefulWidget {
  const WorkoutDetailPage({
    super.key,
    required this.db,
    required this.workoutId,
  });

  final AppDatabase db;
  final int workoutId;

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  AppDatabase get db => widget.db;
  int get workoutId => widget.workoutId;

  /// Die in den Kurven gewählte Stelle; alle Kurven teilen sie sich, damit
  /// sich Puls, Pace und die übrigen Werte am selben Zeitpunkt ablesen lassen.
  final _position = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  /// Titel, Sportart und Notiz ändern (Lastenheft A-054).
  Future<void> _edit(Workout w) async {
    final title = TextEditingController(text: w.title ?? '');
    final notes = TextEditingController(text: w.notes ?? '');
    var sport = w.sport;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Training bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Titel',
                  hintText: w.sport.label,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Sport>(
                initialValue: sport,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sportart'),
                items: [
                  for (final s in Sport.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (s) => sport = s ?? sport,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Notiz'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    db.updateWorkout(
      workoutId,
      title: title.text,
      sport: sport,
      notes: notes.text,
    );
    setState(() {});
  }

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

  /// Langsamere Abschnitte erscheinen in der Pace-Kurve als Lücke.
  static const _slowestPaceKmh = 2.0;

  /// Verteilt die Messpunkte auf eine lückenlose Sekundenachse.
  static List<double?> _series(
    List<Sample> samples,
    int length,
    double? Function(Sample) pick,
  ) {
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
          (skiErg ? 'Ø min/500 m' : 'Ø min/km', pace),
      ],
      if (w.avgHeartRate != null) ('Ø Puls', '${w.avgHeartRate}'),
      if (w.maxHeartRate != null) ('Max. Puls', '${w.maxHeartRate}'),
      if (w.avgPower != null) ('Ø Leistung', '${w.avgPower} W'),
      if (w.maxPower != null) ('Max. Leistung', '${w.maxPower} W'),
      if (w.avgCadence != null)
        ('Ø ${w.sport.cadenceLabel}', '${w.avgCadence} /min'),
      if (w.energyKcal != null)
        // Das Zeichen ≈ kennzeichnet einen aus dem Puls geschätzten Wert.
        (
          w.energyEstimated ? 'Energie (geschätzt)' : 'Energie',
          '${w.energyEstimated ? '≈ ' : ''}${w.energyKcal} kcal',
        ),
      if (w.ascentM != null) ('Anstieg', '${w.ascentM} m'),
    ];

    List<double?> series(double? Function(Sample) pick) =>
        _series(samples, w.durationS, pick);

    // Bei diesen Sportarten zählt die Pace mehr als die Geschwindigkeit.
    final showsPace = w.sport == Sport.treadmill || w.sport.usesGps || skiErg;
    final paceMeters = skiErg ? 500 : 1000;
    final avgSpeed = w.avgSpeedKmh;

    final route = [
      for (final s in samples)
        if (s.latitude != null && s.longitude != null)
          LatLng(s.latitude!, s.longitude!),
    ];
    final laps = db.laps(workoutId);
    final sets = db.setLogs(workoutId);
    final losses = db.linkLosses(workoutId);
    final exerciseNames = sets.isEmpty
        ? const <String, String>{}
        : {for (final e in db.exercises()) e.uuid: e.name};
    final maxHr = HeartProfile.load(db).maxHr(DateTime.now());
    final load = maxHr == null
        ? null
        : db.workoutLoads(maxHr, workoutId: workoutId).firstOrNull?.load;
    if (load != null) facts.add(('Belastung', '$load'));
    final runs = sameWorkouts(db.workouts(), w);
    final zones = maxHr == null || w.avgHeartRate == null
        ? null
        : db.zoneSeconds(HeartZone.thresholds(maxHr), workoutId: workoutId);

    return Scaffold(
      appBar: AppBar(
        title: Text(w.title ?? w.sport.label),
        actions: [
          IconButton(
            tooltip: 'Training bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(w),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'Weitere Aktionen',
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              if (w.stravaId == null)
                PopupMenuItem(
                  value: () async {
                    if (await uploadToStrava(context, db, w) && mounted) {
                      setState(() {});
                    }
                  },
                  child: const Text('Zu Strava hochladen'),
                ),
              if (runs.length > 1)
                PopupMenuItem(
                  value: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ComparePage(
                      db: db,
                      workouts: runs,
                      title: w.title ?? w.sport.label,
                    ),
                  )),
                  child: Text('Alle ${runs.length} Durchgänge vergleichen'),
                ),
              for (final format in ExportFormat.values)
                PopupMenuItem(
                  value: () => exportWorkouts(context, db, [w], format),
                  child: Text('Als ${format.label} exportieren'),
                ),
              PopupMenuItem(
                value: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final problem = await rememberTrainingLocation(db);
                  messenger.showSnackBar(SnackBar(
                      content: Text(problem ??
                          'Aktueller Standort als Trainingsort gemerkt.')));
                },
                child: const Text('Trainingsort neu festlegen'),
              ),
              PopupMenuItem(
                value: () => _delete(context),
                child: const Text('Training löschen'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            w.title == null
                ? formatDateTime(w.startedAt)
                : '${w.sport.label}  ·  ${formatDateTime(w.startedAt)}',
            style: theme.textTheme.titleMedium,
          ),
          if (w.stravaId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                w.imported ? 'Von Strava importiert' : 'Bei Strava hochgeladen',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (w.notes != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(w.notes!, style: theme.textTheme.bodyLarge),
            ),
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
          if (zones != null) ...[
            Text('Pulszonen', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            ZoneBars(seconds: zones, maxHr: maxHr!),
            const SizedBox(height: 24),
          ],
          if (sets.isNotEmpty) ...[
            Text('Sätze', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final s in sets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(exerciseNames[s.exerciseUuid] ??
                          'Gelöschte Übung'),
                    ),
                    Text(formatSet(s)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
          if (losses.isNotEmpty) ...[
            _LinkLosses(losses: losses),
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
              position: _position,
              color: scheme.error,
              values: series((s) => s.heartRate?.toDouble()),
            ),
            if (showsPace)
              LineChart(
                title: 'Pace',
                unit: skiErg ? 'min/500 m' : 'min/km',
                position: _position,
                color: scheme.primary,
                lowerIsBetter: true,
                format: (seconds) => formatDuration(seconds.round()),
                // Der Durchschnitt ergibt sich aus Strecke und Zeit, nicht
                // aus dem Mittel der Sekundenwerte.
                average: avgSpeed == null || avgSpeed < _slowestPaceKmh
                    ? null
                    : paceMeters / (avgSpeed / 3.6),
                values: series((s) {
                  final v = s.speedKmh;
                  // Im Stand wäre die Pace unendlich und würde die Kurve
                  // unlesbar strecken.
                  return v == null || v < _slowestPaceKmh
                      ? null
                      : paceMeters / (v / 3.6);
                }),
              )
            else
              LineChart(
                title: 'Geschwindigkeit',
                unit: 'km/h',
                position: _position,
                color: scheme.primary,
                values: series((s) => s.speedKmh),
              ),
            LineChart(
              title: 'Leistung',
              unit: 'W',
              position: _position,
              color: scheme.tertiary,
              values: series((s) => s.power?.toDouble()),
            ),
            LineChart(
              title: w.sport.cadenceLabel,
              unit: '/min',
              position: _position,
              color: scheme.secondary,
              values: series((s) => s.cadence),
            ),
            LineChart(
              title: 'Steigung',
              unit: '%',
              position: _position,
              color: scheme.outline,
              values: series((s) => s.incline),
            ),
            LineChart(
              title: 'Höhe',
              unit: 'm',
              position: _position,
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
/// Die Verbindungsabbrüche des Trainings: Zusammenfassung nach Grund und
/// auf Wunsch jeder einzelne mit Zeitpunkt und Dauer.
class _LinkLosses extends StatelessWidget {
  const _LinkLosses({required this.losses});

  final List<LinkLoss> losses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byReason = <String, int>{};
    for (final l in losses) {
      byReason.update(l.reasonLabel, (n) => n + 1, ifAbsent: () => 1);
    }
    final durations = [for (final l in losses) ?l.downS];
    final average = durations.isEmpty
        ? null
        : (durations.reduce((a, b) => a + b) / durations.length).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verbindung', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text([
          '${losses.length} ${losses.length == 1 ? 'Abbruch' : 'Abbrüche'}',
          if (average != null) 'im Mittel $average s getrennt',
        ].join(', ')),
        for (final e in byReason.entries)
          Text('${e.value} × ${e.key}', style: theme.textTheme.bodySmall),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Alle Abbrüche'),
          children: [
            for (final l in losses)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(formatDuration(l.t)),
                    ),
                    Expanded(
                      child: Text('${l.device}: ${l.reasonLabel}'
                          '${l.downS == null ? ', nicht zurückgekommen' : ', ${l.downS} s'}'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

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
            skiErg ? 'min/500 m' : 'min/km',
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
      rows.add(
        TableRow(
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
        ),
      );
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
