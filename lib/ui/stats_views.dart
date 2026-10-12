import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../stats/stats.dart';
import 'format.dart';
import 'workout_detail_page.dart';

// ---------------------------------------------------------------------------
// Umfang
// ---------------------------------------------------------------------------

enum _VolumeMetric {
  time('Zeit'),
  distance('Distanz'),
  count('Anzahl');

  const _VolumeMetric(this.label);

  final String label;

  double of(VolumeBucket b) => switch (this) {
        time => b.seconds.toDouble(),
        distance => b.meters,
        count => b.count.toDouble(),
      };

  String get unit => switch (this) {
        time => 'h',
        distance => 'km',
        count => 'Trainings',
      };

  /// Der Wert in der Einheit der Achse, ohne die Einheit selbst.
  String format(double value) => switch (this) {
        time => formatDecimal(value / 3600),
        distance => formatDecimal(value / 1000),
        count => value.round().toString(),
      };
}

/// Trainingsumfang der letzten zwölf Wochen oder Monate (Lastenheft A-051).
class VolumeView extends StatefulWidget {
  const VolumeView({super.key, required this.db});

  final AppDatabase db;

  @override
  State<VolumeView> createState() => _VolumeViewState();
}

class _VolumeViewState extends State<VolumeView> {
  static final _weekLabel = DateFormat('d.M.', 'de');
  static final _monthLabel = DateFormat('MMM', 'de');
  static final _weekTitle = DateFormat('d. MMMM y', 'de');
  static final _monthTitle = DateFormat('MMMM y', 'de');

  VolumePeriod _period = VolumePeriod.week;
  _VolumeMetric _metric = _VolumeMetric.time;

  /// Der gewählte Zeitraum; ohne Auswahl der laufende.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final buckets =
        buildVolume(widget.db.workouts(), _period, now: DateTime.now());
    final selected = _selected ?? buckets.length - 1;
    final bucket = buckets[selected];
    final largest = buckets.map(_metric.of).fold(0.0, (a, b) => a > b ? a : b);
    final week = _period == VolumePeriod.week;
    final sports = bucket.bySport.entries.toList()
      ..sort((a, b) => b.value.seconds.compareTo(a.value.seconds));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SegmentedButton<VolumePeriod>(
              segments: const [
                ButtonSegment(value: VolumePeriod.week, label: Text('Wochen')),
                ButtonSegment(value: VolumePeriod.month, label: Text('Monate')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() {
                _period = s.first;
                _selected = null;
              }),
            ),
            SegmentedButton<_VolumeMetric>(
              segments: [
                for (final m in _VolumeMetric.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {_metric},
              onSelectionChanged: (s) => setState(() => _metric = s.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${_metric.label} je ${week ? 'Woche' : 'Monat'} in ${_metric.unit}'
          '  ·  max ${_metric.format(largest)} ${_metric.unit}',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < buckets.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selected = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Der Wert jedes Balkens steht darüber.
                        SizedBox(
                          height: 16,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _metric.of(buckets[i]) == 0
                                  ? ''
                                  : _metric.format(_metric.of(buckets[i])),
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: largest == 0
                                  ? 0
                                  : _metric.of(buckets[i]) / largest,
                              widthFactor: 0.7,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: i == selected
                                      ? scheme.primary
                                      : scheme.primaryContainer,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Nur jede zweite Beschriftung, damit sie auf dem
                        // Phone nicht ineinanderlaufen.
                        Text(
                          (buckets.length - 1 - i).isEven
                              ? (week ? _weekLabel : _monthLabel)
                                  .format(buckets[i].start)
                              : '',
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          week
              ? 'Woche ab ${_weekTitle.format(bucket.start)}'
              : _monthTitle.format(bucket.start),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(_summary(bucket.count, bucket.seconds, bucket.meters)),
        const SizedBox(height: 8),
        if (sports.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Kein Training in diesem Zeitraum.'),
          ),
        for (final e in sports)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(e.key.icon),
            title: Text(e.key.label),
            subtitle:
                Text(_summary(e.value.count, e.value.seconds, e.value.meters)),
          ),
      ],
    );
  }

  static String _summary(int count, int seconds, double meters) => [
        count == 1 ? '1 Training' : '$count Trainings',
        formatDuration(seconds),
        if (meters > 0) '${formatKm(meters)} km',
      ].join('  ·  ');
}

// ---------------------------------------------------------------------------
// Pulszonen
// ---------------------------------------------------------------------------

/// Die Farben der fünf Zonen, von leicht bis maximal.
const zoneColors = [
  Color(0xFF90A4AE),
  Color(0xFF4FC3F7),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFE57373),
];

/// Balken mit der Zeit je Pulszone.
class ZoneBars extends StatelessWidget {
  const ZoneBars({super.key, required this.seconds, required this.maxHr});

  /// Sekunden je Zone, aufsteigend.
  final List<int> seconds;
  final int maxHr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = seconds.fold(0, (a, b) => a + b);
    if (total == 0) {
      return const Text('Keine Pulsdaten in dieser Auswahl.');
    }
    return Column(
      children: [
        for (final zone in HeartZone.values.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zone.label, style: theme.textTheme.labelLarge),
                      Text('${zone.range(maxHr)} · ${zone.effort}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: seconds[zone.index] / total,
                      minHeight: 20,
                      color: zoneColors[zone.index],
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    '${formatDuration(seconds[zone.index])}  '
                    '${(seconds[zone.index] * 100 / total).round()} %',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bearbeitet Geburtsjahr und eigenen Maximalpuls. Gibt zurück, ob
/// gespeichert wurde.
Future<bool> editHeartProfile(BuildContext context, AppDatabase db) async {
  final profile = HeartProfile.load(db);
  final birthYear =
      TextEditingController(text: profile.birthYear?.toString() ?? '');
  final manual =
      TextEditingController(text: profile.manualMaxHr?.toString() ?? '');
  final weight = TextEditingController(
      text: profile.weightKg == null ? '' : formatDecimal(profile.weightKg!));
  var sex = profile.sex;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Profil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aus dem Geburtsjahr berechnet die App den '
                    'Maximalpuls nach der Faustformel 220 minus Lebensalter.'),
                TextField(
                  controller: birthYear,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Geburtsjahr'),
                ),
                const SizedBox(height: 16),
                const Text('Kennst du deinen Maximalpuls, trage ihn ein. '
                    'Er hat dann Vorrang vor der Faustformel.'),
                TextField(
                  controller: manual,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Eigener Maximalpuls (optional)'),
                ),
                const SizedBox(height: 16),
                const Text('Mit Gewicht und Geburtsjahr schätzt die App den '
                    'Energieverbrauch aus dem Puls, wenn das Trainingsgerät '
                    'keinen liefert.'),
                TextField(
                  controller: weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Gewicht in kg (optional)'),
                ),
                DropdownButtonFormField<Sex?>(
                  initialValue: sex,
                  decoration: const InputDecoration(
                      labelText: 'Geschlecht (optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Keine Angabe')),
                    for (final s in Sex.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (s) => sex = s,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
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
              onPressed: () {
                final year = int.tryParse(birthYear.text.trim());
                final max = int.tryParse(manual.text.trim());
                final thisYear = DateTime.now().year;
                final kg =
                    double.tryParse(weight.text.trim().replaceAll(',', '.'));
                final problem = weight.text.trim().isNotEmpty &&
                        (kg == null || kg < 20 || kg > 300)
                    ? 'Das Gewicht muss zwischen 20 und 300 kg liegen.'
                    : birthYear.text.trim().isNotEmpty &&
                        (year == null || year < 1900 || year > thisYear)
                    ? 'Bitte ein gültiges Geburtsjahr eingeben.'
                    : manual.text.trim().isNotEmpty &&
                            (max == null || max < 100 || max > 230)
                        ? 'Der Maximalpuls muss zwischen 100 und 230 liegen.'
                        : year == null && max == null
                            ? 'Bitte Geburtsjahr oder Maximalpuls eingeben.'
                            : null;
                if (problem != null) {
                  setDialogState(() => error = problem);
                  return;
                }
                HeartProfile(
                  birthYear: year,
                  manualMaxHr: max,
                  weightKg: kg,
                  sex: sex,
                ).save(db);
                Navigator.pop(context, true);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      );
    },
  );
  return saved == true;
}

enum _ZonePeriod {
  week('7 Tage', 7),
  month('30 Tage', 30),
  year('365 Tage', 365),
  all('Gesamt', null);

  const _ZonePeriod(this.label, this.days);

  final String label;
  final int? days;
}

/// Zeit je Pulszone über einen Zeitraum (Lastenheft A-052).
class ZonesView extends StatefulWidget {
  const ZonesView({super.key, required this.db});

  final AppDatabase db;

  @override
  State<ZonesView> createState() => _ZonesViewState();
}

class _ZonesViewState extends State<ZonesView> {
  _ZonePeriod _period = _ZonePeriod.month;

  Future<void> _edit() async {
    if (await editHeartProfile(context, widget.db) && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final profile = HeartProfile.load(widget.db);
    final maxHr = profile.maxHr(now);
    if (maxHr == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Für die Pulszonen braucht die App deinen Maximalpuls. '
                'Sie berechnet ihn aus dem Geburtsjahr.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _edit, child: const Text('Geburtsjahr eingeben')),
            ],
          ),
        ),
      );
    }
    final days = _period.days;
    final seconds = widget.db.zoneSeconds(
      HeartZone.thresholds(maxHr),
      since: days == null ? null : now.subtract(Duration(days: days)),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_ZonePeriod>(
          segments: [
            for (final p in _ZonePeriod.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.first),
        ),
        const SizedBox(height: 16),
        ZoneBars(seconds: seconds, maxHr: maxHr),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Maximalpuls $maxHr'),
          subtitle: Text(profile.manualMaxHr != null
              ? 'Eigener Wert'
              : 'Faustformel 220 − Alter, Geburtsjahr ${profile.birthYear}'),
          trailing: TextButton(onPressed: _edit, child: const Text('Profil')),
        ),
        Text(
          'Gezählt wird nur Zeit, in der ein Pulssensor Werte geliefert hat.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bestwerte
// ---------------------------------------------------------------------------

/// Bestzeiten und Bestleistungen je Sportart (Lastenheft A-053).
class RecordsView extends StatefulWidget {
  const RecordsView({super.key, required this.db});

  final AppDatabase db;

  @override
  State<RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends State<RecordsView> {
  Sport? _sport;

  List<Record> _records(Sport sport, List<Workout> workouts) {
    final efforts = widget.db.bestEfforts(sport);
    final records = <Record>[
      for (final kind in EffortKind.forSport(sport))
        if (efforts[kind] case final e?)
          Record(
            label: kind.isTime ? 'Schnellste ${kind.label}' : kind.label,
            value: kind.isTime
                ? formatDuration(e.value.round())
                : '${e.value.round()} W',
            workoutId: e.workoutId,
            date: e.date,
          ),
    ];
    void longest(String label, num? Function(Workout) of,
        String Function(num) format) {
      Workout? best;
      for (final w in workouts) {
        final value = of(w);
        if (value == null || value <= 0) continue;
        if (best == null || value > of(best)!) best = w;
      }
      if (best != null) {
        records.add(Record(
          label: label,
          value: format(of(best)!),
          workoutId: best.id,
          date: best.startedAt,
        ));
      }
    }

    longest('Längstes Training', (w) => w.durationS,
        (v) => formatDuration(v.round()));
    longest('Weiteste Strecke', (w) => w.distanceM,
        (v) => '${formatKm(v.toDouble())} km');
    longest('Größter Anstieg', (w) => w.ascentM, (v) => '${v.round()} m');
    longest('Höchste Durchschnittsleistung', (w) => w.avgPower,
        (v) => '${v.round()} W');
    return records;
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.db.workouts();
    if (all.isEmpty) {
      return const Center(child: Text('Noch keine Trainings.'));
    }
    // Sportarten in der Reihenfolge ihrer letzten Nutzung.
    final sports = <Sport>[];
    for (final w in all) {
      if (!sports.contains(w.sport)) sports.add(w.sport);
    }
    final sport = sports.contains(_sport) ? _sport! : sports.first;
    final records =
        _records(sport, all.where((w) => w.sport == sport).toList());

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final s in sports)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(s.icon, size: 18),
                    label: Text(s.label),
                    selected: s == sport,
                    onSelected: (_) => setState(() => _sport = s),
                  ),
                ),
            ],
          ),
        ),
        for (final r in records)
          ListTile(
            title: Text(r.label),
            subtitle: Text(formatDate(r.date)),
            trailing: Text(r.value,
                style: Theme.of(context).textTheme.titleLarge),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    WorkoutDetailPage(db: widget.db, workoutId: r.workoutId),
              ));
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }
}
