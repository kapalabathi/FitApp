import 'package:flutter/material.dart';

import '../ble/sensor_connection.dart';
import '../data/models.dart';
import '../interval/interval_models.dart';
import '../session/tile_layout.dart';
import '../session/workout_session.dart';
import 'format.dart';
import 'line_chart.dart';
import 'tile_settings_page.dart';

/// Anzeige während des Trainings: große Live-Werte, Pause und Stopp.
class LivePage extends StatefulWidget {
  const LivePage({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  bool _finishing = false;
  late TileLayout _layout =
      TileLayout.load(_session.recorder.db, _session.sport);

  WorkoutSession get _session => widget.session;

  Future<void> _stop() async {
    if (_finishing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Training beenden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weiter trainieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
    if (confirmed != true || _finishing || !mounted) return;
    _finishing = true;
    Navigator.of(context).pop(_session.finish());
  }

  /// Die Werte aller Kacheln, die es in diesem Training gibt, in der vom
  /// Nutzer gewählten Auswahl und Reihenfolge.
  List<({String label, String value})> _tiles() {
    final r = _session.recorder;
    final sport = _session.sport;
    final speed = r.value(Metric.speed);
    String? number(Metric m, {int decimals = 0}) {
      final v = r.value(m);
      if (v == null) return null;
      return decimals == 0 ? v.round().toString() : formatDecimal(v);
    }

    // Wo die Pace zählt, steht sie statt der Geschwindigkeit.
    final ({String label, String? value}) pace = sport == Sport.skiErg
        ? (label: 'min/500 m', value: formatPace(speed, perMeters: 500) ?? '–')
        : sport == Sport.treadmill || sport.usesGps
            ? (label: 'min/km', value: formatPace(speed) ?? '–')
            : (
                label: 'Geschwindigkeit km/h',
                value: number(Metric.speed, decimals: 1),
              );

    final all = <LiveTileKind, ({String label, String? value})>{
      LiveTileKind.time: (label: 'Zeit', value: formatDuration(r.elapsedS)),
      LiveTileKind.heartRate:
          (label: 'Puls', value: number(Metric.heartRate) ?? '–'),
      LiveTileKind.distance:
          (label: 'Distanz km', value: formatKm(r.distanceM)),
      LiveTileKind.pace: pace,
      LiveTileKind.power: (label: 'Leistung W', value: number(Metric.power)),
      LiveTileKind.cadence: (
        label: '${sport.cadenceLabel} /min',
        value: number(Metric.cadence),
      ),
      LiveTileKind.incline:
          (label: 'Steigung %', value: number(Metric.incline, decimals: 1)),
      LiveTileKind.resistance:
          (label: 'Widerstand', value: number(Metric.resistance)),
      LiveTileKind.energy: (
        // Das Zeichen ≈ kennzeichnet einen aus dem Puls geschätzten Wert.
        label: r.energyEstimated ? 'Energie ≈ kcal' : 'Energie kcal',
        value: r.energyKcal?.toString(),
      ),
      LiveTileKind.ascent: (label: 'Anstieg m', value: r.ascentM?.toString()),
      LiveTileKind.lap: (
        label: 'Runde ${r.laps.length + 1}',
        value: r.laps.isEmpty
            ? null
            : formatDuration(r.elapsedS - r.laps.last.t),
      ),
    };
    return [
      for (final kind in _layout.visible)
        if (all[kind]!.value case final value?)
          (label: all[kind]!.label, value: value),
    ];
  }

  Future<void> _editTiles() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          TileSettingsPage(db: _session.recorder.db, sport: _session.sport),
    ));
    if (mounted) {
      setState(() => _layout =
          TileLayout.load(_session.recorder.db, _session.sport));
    }
  }

  Future<void> _chooseHeartRateSource(List<SensorConnection> sources) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Puls anzeigen von'),
        children: [
          for (final c in sources)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c.saved.deviceId),
              child: Text(c.saved.name),
            ),
        ],
      ),
    );
    if (chosen != null) _session.preferHeartRateFrom(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // Die Zurück-Taste darf ein laufendes Training nicht einfach schließen.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stop();
      },
      child: ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          final r = _session.recorder;
          final tiles = _tiles();
          final hrIds = r.heartRateSources;
          final hrSources = _session.connections
              .where((c) => hrIds.contains(c.saved.deviceId))
              .toList();
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(!r.paused
                  ? _session.sport.label
                  : _session.autoPaused
                      ? '${_session.sport.label} – Pause (automatisch)'
                      : '${_session.sport.label} – pausiert'),
              actions: [
                IconButton(
                  tooltip: 'Anzeige anpassen',
                  icon: const Icon(Icons.tune),
                  onPressed: _editTiles,
                ),
                IconButton(
                  tooltip: 'Runde',
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: r.paused ? null : _session.markLap,
                ),
                if (hrSources.length > 1)
                  IconButton(
                    tooltip: 'Pulsquelle wählen',
                    icon: const Icon(Icons.favorite_border),
                    onPressed: () => _chooseHeartRateSource(hrSources),
                  ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  if (_session.connections.isNotEmpty || _session.sport.usesGps)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_session.sport.usesGps)
                            _GpsChip(
                              accuracyM: r.gpsAccuracyM,
                              error: _session.gpsError,
                            ),
                          for (final c in _session.connections)
                            _LinkChip(connection: c),
                        ],
                      ),
                    ),
                  if (_session.interval != null)
                    _IntervalPanel(session: _session),
                  if (_layout.showChart) _LiveChart(session: _session),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final columns = box.maxWidth >= 900
                            ? 4
                            : box.maxWidth >= 600
                                ? 3
                                : 2;
                        return GridView.count(
                          padding: const EdgeInsets.all(12),
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            for (final t in tiles)
                              _LiveTile(label: t.label, value: t.value),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_session.canControlManually)
                    _ManualControl(session: _session),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(64)),
                            onPressed:
                                _finishing ? null : _session.togglePause,
                            icon:
                                Icon(r.paused ? Icons.play_arrow : Icons.pause),
                            label: Text(r.paused ? 'Weiter' : 'Pause'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(64),
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            ),
                            onPressed: _finishing ? null : _stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Beenden'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.connection});

  final SensorConnection connection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = connection.state == LinkState.connected;
    return Tooltip(
      message: connection.lastError ?? connection.state.label,
      child: Chip(
        avatar: connected
            ? Icon(connection.saved.kind.icon, size: 18)
            : const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
        label: Text(connected
            ? connection.saved.name
            : '${connection.saved.name}: ${connection.state.label}'),
        backgroundColor: connected ? null : scheme.errorContainer,
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.displayLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Der laufende Abschnitt des Intervall-Timers mit Restzeit, Vorschau und,
/// falls gewünscht, dem Stand der Gerätesteuerung.
class _IntervalPanel extends StatelessWidget {
  const _IntervalPanel({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final run = session.interval!;
    final kind = session.targetKind;
    final step = run.current;

    String describe(PlannedStep s) {
      final label = s.label.isEmpty ? 'Abschnitt' : s.label;
      final target = s.target;
      return target == null ? label : '$label · ${kind.format(target)}';
    }

    final Widget body;
    if (step == null) {
      body = Text('Intervall beendet', style: theme.textTheme.titleLarge);
    } else {
      final next = run.next;
      final ending = run.remainingInStep <= 5;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        'Abschnitt ${run.position} von ${run.steps.length}',
                        if (step.round != null)
                          'Runde ${step.round} von ${step.rounds}',
                      ].join('  ·  '),
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(describe(step), style: theme.textTheme.headlineSmall),
                  ],
                ),
              ),
              Text(
                formatDuration(run.remainingInStep),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ending ? scheme.error : null,
                ),
              ),
              IconButton(
                tooltip: 'Nächster Abschnitt',
                iconSize: 32,
                icon: const Icon(Icons.skip_next),
                onPressed: session.skipStep,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: 1 - run.remainingInStep / step.durationS,
          ),
          const SizedBox(height: 8),
          Text(
            [
              next == null ? 'Danach: Ende' : 'Danach: ${describe(next)}',
              'Rest ${formatDuration(run.remainingTotal)}',
            ].join('  ·  '),
            style: ending
                ? theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)
                : theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            body,
            if (session.control != ControlState.off ||
                session.controlMessage != null) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        switch (session.control) {
                          ControlState.active => 'Steuerung aktiv',
                          ControlState.suspended => 'Steuerung angehalten',
                          ControlState.off => 'Steuerung aus',
                        },
                        if (session.controlMessage != null)
                          session.controlMessage!,
                      ].join(': '),
                    ),
                  ),
                  switch (session.control) {
                    ControlState.active => FilledButton.tonal(
                        onPressed: session.stopControl,
                        child: const Text('Steuerung stoppen'),
                      ),
                    ControlState.suspended => FilledButton(
                        onPressed: session.resumeControl,
                        child: const Text('Fortsetzen'),
                      ),
                    ControlState.off => const SizedBox.shrink(),
                  },
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Zeigt, ob das GPS gerade einen brauchbaren Standort liefert.
class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.accuracyM, required this.error});

  final double? accuracyM;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accuracy = accuracyM;
    return Tooltip(
      message: error ?? 'Genauigkeit des Standorts',
      child: Chip(
        avatar: accuracy == null
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.gps_fixed, size: 18),
        label: Text(accuracy == null
            ? (error == null ? 'GPS: suche Standort …' : 'GPS: Fehler')
            : 'GPS ±${accuracy.round()} m'),
        backgroundColor: accuracy == null ? scheme.errorContainer : null,
      ),
    );
  }
}

/// Tasten, mit denen sich am Laufband die Geschwindigkeit und am Bike die
/// Widerstandsstufe von Hand einstellen lässt.
class _ManualControl extends StatelessWidget {
  const _ManualControl({required this.session});

  final WorkoutSession session;

  /// Schnellwahl für das Laufband in km/h.
  static const _speedPresets = [4.0, 6.0, 8.0, 10.0, 12.0, 14.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = session.manualKind!;
    final limits = session.manualLimits;
    final target = session.manualTarget;
    final presets = kind == TargetKind.speed
        ? _speedPresets.where((p) => p >= limits.min && p <= limits.max)
        : const <double>[];
    // Ohne laufenden Intervall-Timer steht die Rückmeldung des Geräts hier.
    final message = session.interval == null ? session.controlMessage : null;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Weniger',
                  iconSize: 36,
                  onPressed: () => session.adjustManual(-1),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        kind == TargetKind.speed ? 'Ziel am Laufband' : 'Ziel am Bike',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        target == null ? '–' : kind.format(target),
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Mehr',
                  iconSize: 36,
                  onPressed: () => session.adjustManual(1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (presets.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in presets)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          label: Text(kind.format(p)),
                          onPressed: () => session.setManual(p),
                        ),
                      ),
                  ],
                ),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(message, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

/// Puls und Pace der letzten Minuten als mitlaufende Kurven.
class _LiveChart extends StatelessWidget {
  const _LiveChart({required this.session});

  final WorkoutSession session;

  /// So viele Sekunden zeigt der Ausschnitt.
  static const _windowS = 600;

  /// Vorher lässt sich noch keine Kurve erkennen.
  static const _minPoints = 10;

  /// Langsamere Abschnitte erscheinen in der Pace-Kurve als Lücke.
  static const _slowestPaceKmh = 2.0;

  static List<double?> _recent(List<double?> all) =>
      all.length <= _windowS ? all : all.sublist(all.length - _windowS);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = session.recorder;
    final sport = session.sport;
    final heartRate = _recent(r.heartRateHistory);
    final speed = _recent(r.speedHistory);
    if (heartRate.length < _minPoints) return const SizedBox.shrink();

    final showsPace =
        sport == Sport.treadmill || sport.usesGps || sport == Sport.skiErg;
    final paceMeters = sport == Sport.skiErg ? 500 : 1000;
    final hasPulse = heartRate.any((v) => v != null);
    final hasSpeed = speed.any((v) => v != null);
    if (!hasPulse && !hasSpeed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          if (hasPulse)
            Sparkline(
              title: 'Puls',
              unit: '1/min',
              color: scheme.error,
              values: heartRate,
              format: (v) => v.round().toString(),
            ),
          if (hasSpeed && showsPace)
            Sparkline(
              title: 'Pace',
              unit: sport == Sport.skiErg ? 'min/500 m' : 'min/km',
              color: scheme.primary,
              lowerIsBetter: true,
              format: (seconds) => formatDuration(seconds.round()),
              values: [
                for (final v in speed)
                  v == null || v < _slowestPaceKmh
                      ? null
                      : paceMeters / (v / 3.6),
              ],
            )
          else if (hasSpeed)
            Sparkline(
              title: 'Geschwindigkeit',
              unit: 'km/h',
              color: scheme.primary,
              values: speed,
            ),
        ],
      ),
    );
  }
}
