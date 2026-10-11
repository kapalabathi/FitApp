import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/byte_reader.dart';
import '../ble/ftms.dart';
import '../ble/heart_rate.dart';
import '../ble/uuids.dart';

/// Verbindet sich mit einem Gerät, zeigt dessen Live-Werte und erstellt einen
/// Gerätebericht: Dienste, Fähigkeiten, Einstellbereiche und Rohdaten.
class DevicePage extends StatefulWidget {
  const DevicePage({super.key, required this.device});

  final BleDevice device;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, String> _live = {};
  final Map<String, _RawPacket> _raw = {};
  final List<String> _notes = [];
  List<BleService> _services = [];
  FtmsFeatures? _features;
  final Map<String, FtmsRange> _ranges = {};

  String _status = 'Verbinde …';
  bool _connected = false;
  bool _busy = true;

  BleDevice get _device => widget.device;

  @override
  void initState() {
    super.initState();
    _subs.add(_device.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _connected = connected;
        if (!connected && !_busy) _status = 'Verbindung getrennt';
      });
    }));
    _connect();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _device.disconnect().catchError((_) {});
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _status = 'Verbinde …';
      _notes.clear();
    });
    try {
      await _device.connect();
      _set(() => _status = 'Lese Dienste …');
      final services = await _device.discoverServices();
      _set(() => _services = services);
      await _readCapabilities();
      await _subscribeAll();
      _set(() => _status = 'Verbunden');
    } catch (e) {
      _set(() => _status = 'Fehler: $e');
    } finally {
      _set(() => _busy = false);
    }
  }

  void _set(VoidCallback change) {
    if (mounted) setState(change);
  }

  BleCharacteristic? _find(String serviceUuid, String characteristicUuid) {
    for (final s in _services) {
      if (!Uuids.same(s.uuid, serviceUuid)) continue;
      for (final c in s.characteristics) {
        if (Uuids.same(c.uuid, characteristicUuid)) return c;
      }
    }
    return null;
  }

  Future<void> _readCapabilities() async {
    Future<void> read(String uuid, void Function(List<int>) use) async {
      final c = _find(Uuids.ftmsService, uuid);
      if (c == null) return;
      try {
        final value = await c.read();
        _raw[Uuids.full(uuid)] = _RawPacket(value, 1);
        use(value);
      } catch (e) {
        _notes.add('${Uuids.label(uuid)} nicht lesbar: $e');
      }
    }

    await read(Uuids.ftmsFeature, (v) => _features = FtmsFeatures.parse(v));
    await read(Uuids.supportedSpeedRange,
        (v) => _ranges['Geschwindigkeit (km/h)'] = FtmsRange.parseSpeed(v));
    await read(Uuids.supportedInclinationRange,
        (v) => _ranges['Steigung (%)'] = FtmsRange.parseInclination(v));
    await read(Uuids.supportedResistanceRange,
        (v) => _ranges['Widerstand'] = FtmsRange.parseResistance(v));
    await read(Uuids.supportedPowerRange,
        (v) => _ranges['Leistung (W)'] = FtmsRange.parsePower(v));
    _set(() {});
  }

  Future<void> _subscribeAll() async {
    await _subscribe(Uuids.heartRateService, Uuids.heartRateMeasurement, (v) {
      final s = HeartRateSample.parse(v);
      _live['Puls'] = '${s.bpm}';
      if (s.sensorContact == false) _live['Puls'] = '${s.bpm} (kein Kontakt)';
    });
    await _subscribe(Uuids.ftmsService, Uuids.treadmillData, (v) {
      final d = TreadmillData.parse(v);
      _put('Geschwindigkeit km/h', d.speedKmh?.toStringAsFixed(1));
      _put('Steigung %', d.inclinationPercent?.toStringAsFixed(1));
      _put('Distanz m', d.totalDistanceM);
      _put('Zeit s', d.elapsedSeconds);
      _put('Energie kcal', d.totalEnergyKcal);
      _put('Puls (Gerät)', d.heartRate);
      _put('Leistung W', d.powerWatt);
    });
    await _subscribe(Uuids.ftmsService, Uuids.indoorBikeData, (v) {
      final d = IndoorBikeData.parse(v);
      _put('Geschwindigkeit km/h', d.speedKmh?.toStringAsFixed(1));
      _put('Trittfrequenz 1/min', d.cadenceRpm?.toStringAsFixed(0));
      _put('Leistung W', d.powerWatt);
      _put('Widerstand', d.resistanceLevel);
      _put('Distanz m', d.totalDistanceM);
      _put('Zeit s', d.elapsedSeconds);
      _put('Energie kcal', d.totalEnergyKcal);
      _put('Puls (Gerät)', d.heartRate);
    });
    // Weitere Datenmerkmale werden noch nicht ausgewertet, aber mitgeschnitten,
    // damit der Gerätebericht ihre Rohdaten enthält.
    for (final s in _services) {
      for (final c in s.characteristics) {
        final known = _raw.containsKey(Uuids.full(c.uuid)) || c.isSubscribed;
        final notifies = c.properties.any((p) => p.name == 'notify');
        final relevant = Uuids.same(s.uuid, Uuids.ftmsService) ||
            Uuids.full(s.uuid).startsWith('ce0600');
        if (!known && notifies && relevant) {
          await _subscribe(s.uuid, c.uuid, (_) {});
        }
      }
    }
  }

  void _put(String label, Object? value) {
    if (value != null) _live[label] = '$value';
  }

  Future<void> _subscribe(
    String serviceUuid,
    String characteristicUuid,
    void Function(List<int>) onValue,
  ) async {
    final c = _find(serviceUuid, characteristicUuid);
    if (c == null) return;
    final key = Uuids.full(characteristicUuid);
    _subs.add(c.onValueReceived.listen((value) {
      _raw[key] = _RawPacket(value, (_raw[key]?.count ?? 0) + 1);
      try {
        onValue(value);
      } on FormatException catch (e) {
        _live['Fehler'] = e.message;
      }
      _set(() {});
    }));
    try {
      await c.notifications.subscribe();
    } catch (e) {
      _notes.add('${Uuids.label(key) ?? key}: Abonnieren fehlgeschlagen: $e');
    }
  }

  String _report() {
    final b = StringBuffer()
      ..writeln('FitApp-Gerätebericht')
      ..writeln('Name: ${_device.name ?? '(ohne)'}')
      ..writeln('Kennung: ${_device.deviceId}')
      ..writeln('Status: $_status')
      ..writeln();

    final features = _features;
    if (features != null) {
      b
        ..writeln('FTMS misst:')
        ..writeln(_bullets(features.machineFeatures))
        ..writeln('FTMS lässt sich steuern über:')
        ..writeln(_bullets(features.targetSettings))
        ..writeln();
    }
    if (_ranges.isNotEmpty) {
      b.writeln('Einstellbereiche:');
      _ranges.forEach((k, v) => b.writeln('  $k: $v'));
      b.writeln();
    }
    if (_live.isNotEmpty) {
      b.writeln('Letzte Werte:');
      _live.forEach((k, v) => b.writeln('  $k: $v'));
      b.writeln();
    }
    b.writeln('Dienste:');
    for (final s in _services) {
      b.writeln('  ${Uuids.label(s.uuid) ?? '?'} [${s.uuid}]');
      for (final c in s.characteristics) {
        final props = c.properties.map((p) => p.name).join(', ');
        b.writeln('    ${Uuids.label(c.uuid) ?? '?'} [${c.uuid}] ($props)');
        final raw = _raw[Uuids.full(c.uuid)];
        if (raw != null) {
          b.writeln('      ${raw.count} Paket(e), letztes: ${hex(raw.bytes)}');
        }
      }
    }
    if (_notes.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Hinweise:')
        ..writeln(_bullets(_notes));
    }
    return b.toString();
  }

  static String _bullets(List<String> items) =>
      items.isEmpty ? '  (nichts)' : items.map((i) => '  - $i').join('\n');

  Future<void> _copyReport() async {
    final report = _report();
    debugPrint(report, wrapWidth: 1024);
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerätebericht in die Zwischenablage kopiert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text((_device.name ?? '').isEmpty ? 'Gerät' : _device.name!),
        actions: [
          IconButton(
            tooltip: 'Gerätebericht kopieren',
            icon: const Icon(Icons.copy),
            onPressed: _services.isEmpty ? null : _copyReport,
          ),
          if (!_connected && !_busy)
            IconButton(
              tooltip: 'Erneut verbinden',
              icon: const Icon(Icons.refresh),
              onPressed: _connect,
            ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_status, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          if (_live.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final e in _live.entries)
                  _ValueTile(label: e.key, value: e.value),
              ],
            ),
          if (_services.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Gerätebericht', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              _report(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RawPacket {
  const _RawPacket(this.bytes, this.count);

  final List<int> bytes;
  final int count;
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            Text(value, style: theme.textTheme.displaySmall),
          ],
        ),
      ),
    );
  }
}
