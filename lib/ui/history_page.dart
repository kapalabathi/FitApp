import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import 'compare_page.dart';
import 'format.dart';
import 'stats_views.dart';
import 'strava_page.dart';
import 'sync_page.dart';
import 'workout_actions.dart';
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

/// Der Verlauf: Liste aller Trainings, filterbar nach Sportart und
/// Zeitraum, dazu die Auswertungen Umfang, Pulszonen und Bestwerte.
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

  /// Die Nummern der ausgewählten Trainings. Solange hier etwas steht, ist
  /// die Liste im Auswahlmodus: Tippen wählt aus, statt zu öffnen.
  final Set<int> _selected = {};

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
      // Was der Filter ausblendet, ist auch nicht mehr ausgewählt.
      _selected.retainAll(_workouts.map((w) => w.id));
    });
  }

  void _toggle(Workout w) => setState(() {
    _selected.contains(w.id) ? _selected.remove(w.id) : _selected.add(w.id);
  });

  List<Workout> get _selectedWorkouts =>
      _workouts.where((w) => _selected.contains(w.id)).toList();

  Future<void> _exportSelected(ExportFormat format) async {
    await exportWorkouts(context, widget.db, _selectedWorkouts, format);
    if (mounted) setState(_selected.clear);
  }

  Future<void> _uploadSelected() async {
    await uploadManyToStrava(context, widget.db, _selectedWorkouts);
    if (!mounted) return;
    _selected.clear();
    _load();
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          count == 1
              ? 'Das ausgewählte Training löschen?'
              : '$count Trainings löschen?',
        ),
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
    for (final id in _selected) {
      widget.db.deleteWorkout(id);
    }
    _selected.clear();
    _load();
  }

  Future<void> _open(Workout w) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailPage(db: widget.db, workoutId: w.id),
      ),
    );
    // Das Training kann in der Detailansicht gelöscht worden sein.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = Column(
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
                    final selected = _selected.contains(w.id);
                    return ListTile(
                      selected: selected,
                      leading: Icon(
                        selected
                            ? Icons.check_circle
                            : _selected.isEmpty
                            ? w.sport.icon
                            : Icons.circle_outlined,
                      ),
                      title: Text(w.title ?? w.sport.label),
                      trailing: w.stravaId == null
                          ? null
                          : Tooltip(
                              message: w.imported
                                  ? 'Von Strava importiert'
                                  : 'Bei Strava hochgeladen',
                              child: Icon(
                                w.imported
                                    ? Icons.cloud_download_outlined
                                    : Icons.cloud_done_outlined,
                                size: 20,
                              ),
                            ),
                      subtitle: Text(
                        '${formatDateTime(w.startedAt)}\n${facts.join('  ·  ')}',
                      ),
                      isThreeLine: true,
                      onTap: () => _selected.isEmpty ? _open(w) : _toggle(w),
                      onLongPress: () => _toggle(w),
                    );
                  },
                ),
        ),
      ],
    );
    return PopScope(
      // Mit einer Auswahl hebt die Zurück-Taste erst sie auf, statt die App
      // zu verlassen.
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          leading: _selected.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Auswahl aufheben',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_selected.clear),
                ),
          title: Text(
            _selected.isEmpty ? 'Verlauf' : '${_selected.length} ausgewählt',
          ),
          actions: [
            if (_selected.isNotEmpty) ...[
              IconButton(
                tooltip: 'Alle auswählen',
                icon: const Icon(Icons.select_all),
                onPressed: () => setState(
                  () => _selected.addAll(_workouts.map((w) => w.id)),
                ),
              ),
              IconButton(
                tooltip: 'Kurven vergleichen',
                icon: const Icon(Icons.stacked_line_chart),
                onPressed: _selected.length < 2
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ComparePage(
                            db: widget.db,
                            workouts: _selectedWorkouts,
                          ),
                        )),
              ),
              PopupMenuButton<ExportFormat>(
                tooltip: 'Exportieren',
                icon: const Icon(Icons.ios_share),
                onSelected: _exportSelected,
                itemBuilder: (_) => [
                  for (final format in ExportFormat.values)
                    PopupMenuItem(
                      value: format,
                      child: Text('Als ${format.label} exportieren'),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Zu Strava hochladen',
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: _uploadSelected,
              ),
              IconButton(
                tooltip: 'Ausgewählte löschen',
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteSelected,
              ),
            ] else ...[
              IconButton(
                tooltip: 'Dateien importieren',
                icon: const Icon(Icons.file_open_outlined),
                onPressed: () async {
                  if (await importFiles(context, widget.db) && mounted) {
                    _load();
                  }
                },
              ),
              IconButton(
                tooltip: 'Synchronisation',
                icon: const Icon(Icons.sync),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SyncPage(db: widget.db),
                    ),
                  );
                  // Ein Abgleich kann neue Trainings gebracht haben.
                  if (mounted) _load();
                },
              ),
              IconButton(
                tooltip: 'Strava',
                icon: const Icon(Icons.cloud_sync_outlined),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StravaPage(db: widget.db),
                    ),
                  );
                  // Ein Import kann neue Trainings gebracht haben.
                  if (mounted) _load();
                },
              ),
            ],
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Trainings'),
              Tab(text: 'Umfang'),
              Tab(text: 'Pulszonen'),
              Tab(text: 'Belastung'),
              Tab(text: 'Bestwerte'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            list,
            VolumeView(db: widget.db),
            ZonesView(db: widget.db),
            LoadView(db: widget.db),
            RecordsView(db: widget.db),
          ],
        ),
      ),
      ),
    );
  }
}
