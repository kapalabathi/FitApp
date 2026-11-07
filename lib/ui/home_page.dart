import 'package:flutter/material.dart';

import '../data/database.dart';
import '../sync/auto_backup.dart';
import '../sync/drive_sync.dart';
import 'devices_page.dart';
import 'history_page.dart';
import 'intervals_page.dart';
import 'programs_page.dart';
import 'start_page.dart';
import 'sync_page.dart';

/// Rahmen der App mit den fünf Hauptbereichen. Auf breiten Bildschirmen
/// (Tablet, Querformat) steht die Navigation seitlich.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.db, this.recoveredWorkouts = 0});

  final AppDatabase db;

  /// Anzahl der Trainings, die nach einem Absturz gerettet wurden.
  final int recoveredWorkouts;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _wideLayoutFrom = 600.0;
  static const _destinations = [
    (icon: Icons.play_circle_outline, label: 'Training'),
    (icon: Icons.self_improvement, label: 'Programme'),
    (icon: Icons.timer_outlined, label: 'Intervalle'),
    (icon: Icons.history, label: 'Verlauf'),
    (icon: Icons.bluetooth, label: 'Geräte'),
  ];

  static const _start = 0;
  static const _history = 3;

  int _index = _start;

  /// Erhöht sich nach jedem Training, damit der Verlauf neu lädt.
  int _historyVersion = 0;

  /// Erhöht sich bei jedem Wechsel zur Startseite, damit sie neu angelegte
  /// Geräte und Vorlagen anbietet.
  int _startVersion = 0;

  static const _restoreHintKey = 'hint.restoreDismissed';

  /// Eine leere App, etwa nach einer Neuinstallation, bietet an, eine
  /// Sicherung einzuspielen.
  late bool _offerRestore =
      widget.db.workouts().isEmpty &&
      !widget.db.flag(_restoreHintKey, fallback: false);

  Future<void> _restore() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SyncPage(db: widget.db)));
    if (!mounted) return;
    setState(() {
      _historyVersion++;
      _startVersion++;
      _offerRestore = widget.db.workouts().isEmpty;
    });
  }

  Widget _withRestoreHint(Widget body) {
    if (!_offerRestore) return body;
    return Column(
      children: [
        // Der Hinweis rückt unter die Statusleiste; die Seite darunter
        // braucht dann oben keinen Abstand mehr.
        SafeArea(
          bottom: false,
          child: MaterialBanner(
            leading: const Icon(Icons.restore),
            content: const Text(
              'Noch keine Trainings. Hast du die App neu '
              'installiert? Eine Sicherungsdatei bringt deine Daten zurück.',
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() {
                  widget.db.setFlag(_restoreHintKey, true);
                  _offerRestore = false;
                }),
                child: const Text('Nicht mehr zeigen'),
              ),
              TextButton(
                onPressed: _restore,
                child: const Text('Sicherung einspielen'),
              ),
            ],
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: body,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _syncInBackground();
    if (widget.recoveredWorkouts > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final n = widget.recoveredWorkouts;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n == 1
                  ? 'Ein unterbrochenes Training wurde gerettet und im Verlauf gespeichert.'
                  : '$n unterbrochene Trainings wurden gerettet und im Verlauf gespeichert.',
            ),
          ),
        );
      });
    }
  }

  void _workoutSaved() {
    setState(() {
      _historyVersion++;
      _index = _history;
    });
    _syncInBackground();
  }

  /// Gleicht mit Google Drive ab, falls eingerichtet. Kommt dabei etwas
  /// Neues an, lädt der Verlauf neu.
  Future<void> _syncInBackground() async {
    // Die tägliche Sicherung in den gewählten Ordner, falls eingerichtet.
    AutoBackup.runIfDue(widget.db);
    if (await DriveSync.runInBackground(widget.db) && mounted) {
      setState(() => _historyVersion++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        StartPage(
          key: ValueKey(_startVersion),
          db: widget.db,
          onWorkoutSaved: _workoutSaved,
        ),
        ProgramsPage(db: widget.db, onWorkoutSaved: _workoutSaved),
        IntervalsPage(db: widget.db),
        HistoryPage(key: ValueKey(_historyVersion), db: widget.db),
        DevicesPage(db: widget.db),
      ],
    );
    void select(int i) => setState(() {
      if (i == _start && _index != _start) _startVersion++;
      _index = i;
    });

    if (MediaQuery.sizeOf(context).width >= _wideLayoutFrom) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _withRestoreHint(body)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: _withRestoreHint(body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
