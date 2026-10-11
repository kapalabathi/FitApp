import 'package:flutter/material.dart';

import '../ble/sensor_connection.dart';
import '../data/models.dart';
import '../session/workout_session.dart';
import 'format.dart';

/// Anzeige während des Trainings: große Live-Werte, Pause und Stopp.
class LivePage extends StatefulWidget {
  const LivePage({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  bool _finishing = false;

  WorkoutSession get _session => widget.session;

  Future<void> _stop() async {
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
    if (confirmed != true || _finishing) return;
    setState(() => _finishing = true);
    final workout = await _session.finish();
    if (mounted) Navigator.of(context).pop(workout);
  }

  List<({String label, String value})> _tiles() {
    final r = _session.recorder;
    final sport = _session.sport;
    final speed = r.value(Metric.speed);
    String? number(Metric m, {int decimals = 0}) {
      final v = r.value(m);
      if (v == null) return null;
      return decimals == 0 ? v.round().toString() : formatDecimal(v);
    }

    final ({String label, String? value}) pace = sport == Sport.skiErg
        ? (label: 'Tempo /500 m', value: formatPace(speed, perMeters: 500))
        : sport == Sport.treadmill
            ? (label: 'Tempo /km', value: formatPace(speed))
            : (label: '', value: null);

    final candidates = <({String label, String? value})>[
      (label: 'Zeit', value: formatDuration(r.elapsedS)),
      (label: 'Puls', value: number(Metric.heartRate) ?? '–'),
      (label: 'Distanz km', value: formatKm(r.distanceM)),
      (label: 'Geschwindigkeit km/h', value: number(Metric.speed, decimals: 1)),
      pace,
      (label: 'Leistung W', value: number(Metric.power)),
      (label: '${sport.cadenceLabel} /min', value: number(Metric.cadence)),
      (label: 'Steigung %', value: number(Metric.incline, decimals: 1)),
      (label: 'Widerstand', value: number(Metric.resistance)),
      (label: 'Energie kcal', value: r.energyKcal?.toString()),
    ];
    return [
      for (final c in candidates)
        if (c.value != null) (label: c.label, value: c.value!),
    ];
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
              title: Text(r.paused
                  ? '${_session.sport.label} – pausiert'
                  : _session.sport.label),
              actions: [
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
                  if (_session.connections.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final c in _session.connections)
                            _LinkChip(connection: c),
                        ],
                      ),
                    ),
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
