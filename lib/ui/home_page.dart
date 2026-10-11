import 'package:flutter/material.dart';

import '../data/database.dart';
import 'devices_page.dart';
import 'history_page.dart';
import 'start_page.dart';

/// Rahmen der App mit den drei Hauptbereichen. Auf breiten Bildschirmen
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
    (icon: Icons.history, label: 'Verlauf'),
    (icon: Icons.bluetooth, label: 'Geräte'),
  ];

  int _index = 0;

  /// Erhöht sich nach jedem Training, damit der Verlauf neu lädt.
  int _historyVersion = 0;

  /// Erhöht sich beim Verlassen der Geräteliste, damit die Startseite neu
  /// hinzugefügte Geräte anbietet.
  int _devicesVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.recoveredWorkouts > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final n = widget.recoveredWorkouts;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n == 1
              ? 'Ein unterbrochenes Training wurde gerettet und im Verlauf gespeichert.'
              : '$n unterbrochene Trainings wurden gerettet und im Verlauf gespeichert.'),
        ));
      });
    }
  }

  void _workoutSaved() => setState(() {
        _historyVersion++;
        _index = 1;
      });

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        StartPage(
          key: ValueKey(_devicesVersion),
          db: widget.db,
          onWorkoutSaved: _workoutSaved,
        ),
        HistoryPage(key: ValueKey(_historyVersion), db: widget.db),
        DevicesPage(db: widget.db),
      ],
    );
    void select(int i) => setState(() {
          if (_index == 2 && i != 2) _devicesVersion++;
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
                        icon: Icon(d.icon), label: Text(d.label)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: body,
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
