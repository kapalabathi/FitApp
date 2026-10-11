import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../data/models.dart';
import 'decoders.dart';
import 'uuids.dart';

enum LinkState {
  connecting('Verbinde …'),
  connected('Verbunden'),
  reconnecting('Verbindung verloren, verbinde neu …'),
  stopped('Getrennt');

  const LinkState(this.label);

  final String label;
}

/// Hält die Verbindung zu einem gemerkten Gerät während eines Trainings und
/// liefert dessen Messwerte. Bricht die Verbindung ab, verbindet sie sich
/// von selbst neu (Lastenheft A-011).
class SensorConnection extends ChangeNotifier {
  SensorConnection(this.saved, {required this.onData});

  static const _connectTimeout = Duration(seconds: 15);
  static const _retryDelay = Duration(seconds: 3);

  final SavedDevice saved;
  final void Function(SavedDevice device, Map<Metric, double> values) onData;

  late final BleDevice _device =
      BleDevice(deviceId: saved.deviceId, name: saved.name);
  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<bool>? _linkSub;
  Completer<void>? _lost;
  bool _stopped = false;

  LinkState _state = LinkState.connecting;
  LinkState get state => _state;

  /// Die letzte Fehlermeldung, solange keine Verbindung besteht.
  String? lastError;

  void start() {
    _linkSub = _device.connectionStream.listen((connected) {
      if (!connected) _signalLost();
    });
    _run();
  }

  Future<void> stop() async {
    _stopped = true;
    _signalLost();
    await _linkSub?.cancel();
    await _dropSubscriptions();
    try {
      await _device.disconnect();
    } catch (_) {
      // War schon getrennt.
    }
    _setState(LinkState.stopped);
  }

  void _signalLost() {
    final lost = _lost;
    if (lost != null && !lost.isCompleted) lost.complete();
  }

  Future<void> _run() async {
    var first = true;
    while (!_stopped) {
      _setState(first ? LinkState.connecting : LinkState.reconnecting);
      first = false;
      try {
        await _device.connect(timeout: _connectTimeout);
        final lost = _lost = Completer<void>();
        final services = await _device.discoverServices();
        await _subscribe(services);
        if (_stopped) break;
        lastError = null;
        _setState(LinkState.connected);
        await lost.future;
      } catch (e) {
        lastError = '$e';
      }
      await _dropSubscriptions();
      if (_stopped) break;
      _setState(LinkState.reconnecting);
      await Future<void>.delayed(_retryDelay);
      if (_stopped) break;
      await _refreshScan();
    }
  }

  Future<void> _subscribe(List<BleService> services) async {
    for (final service in services) {
      for (final c in service.characteristics) {
        for (final decoder in decoders) {
          if (!Uuids.same(service.uuid, decoder.service) ||
              !Uuids.same(c.uuid, decoder.characteristic)) {
            continue;
          }
          _subs.add(c.onValueReceived.listen((bytes) {
            try {
              final values = decoder.decode(bytes);
              if (values.isNotEmpty) onData(saved, values);
            } on FormatException {
              // Ein unverständliches Paket darf das Training nicht stören.
            }
          }));
          await c.notifications.subscribe();
        }
      }
    }
  }

  Future<void> _dropSubscriptions() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  void _setState(LinkState state) {
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }

  static Future<void>? _scan;

  /// Android findet manche Geräte nach einem Abbruch erst wieder, wenn kurz
  /// gesucht wurde. Mehrere Verbindungen teilen sich dieselbe Suche.
  static Future<void> _refreshScan() => _scan ??= () async {
        try {
          await UniversalBle.startScan();
          await Future<void>.delayed(const Duration(seconds: 4));
          await UniversalBle.stopScan();
        } catch (_) {
          // Ohne Suche wird es beim nächsten Versuch einfach erneut probiert.
        } finally {
          _scan = null;
        }
      }();
}
