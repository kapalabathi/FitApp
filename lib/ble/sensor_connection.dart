import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../data/models.dart';
import '../interval/interval_models.dart';
import 'decoders.dart';
import 'ftms.dart';
import 'ftms_control.dart';
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

  /// Die Steuerung des Geräts, solange es verbunden ist und sich steuern
  /// lässt; sonst `null`.
  MachineControl? control;

  /// Zählt die erfolgreichen Verbindungen. Ab der zweiten war die Verbindung
  /// zwischendurch verloren.
  int connectCount = 0;

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
        control = await MachineControl.attach(services, _subs);
        if (_stopped) break;
        lastError = null;
        connectCount++;
        _setState(LinkState.connected);
        await lost.future;
      } catch (e) {
        lastError = '$e';
      }
      control = null;
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

/// Setzt Zielwerte an einem FTMS-Gerät.
class MachineControl {
  MachineControl._(this._point, this.features);

  static const _answerTimeout = Duration(seconds: 3);

  final BleCharacteristic _point;

  /// Was das Gerät laut eigener Auskunft annimmt; `null`, wenn es dazu
  /// nichts sagt.
  final FtmsFeatures? features;

  bool _hasControl = false;
  Completer<FtmsResponse>? _pending;

  /// Sucht die Steuerung in [services] und bereitet sie vor. Gibt `null`
  /// zurück, wenn das Gerät keine hat.
  static Future<MachineControl?> attach(
    List<BleService> services,
    List<StreamSubscription<dynamic>> subscriptions,
  ) async {
    BleCharacteristic? find(String uuid) {
      for (final s in services) {
        if (!Uuids.same(s.uuid, Uuids.ftmsService)) continue;
        for (final c in s.characteristics) {
          if (Uuids.same(c.uuid, uuid)) return c;
        }
      }
      return null;
    }

    final point = find(Uuids.ftmsControlPoint);
    if (point == null) return null;
    FtmsFeatures? features;
    try {
      final feature = find(Uuids.ftmsFeature);
      if (feature != null) features = FtmsFeatures.parse(await feature.read());
    } catch (_) {
      // Ohne Auskunft wird jeder Zielwert versucht; das Gerät antwortet dann.
    }
    final control = MachineControl._(point, features);
    subscriptions.add(point.onValueReceived.listen(control._onAnswer));
    await point.indications.subscribe();
    return control;
  }

  bool supports(TargetKind kind) {
    final f = features;
    if (f == null) return kind != TargetKind.none;
    return switch (kind) {
      TargetKind.none => false,
      TargetKind.speed => f.canSetSpeed,
      TargetKind.resistance => f.canSetResistance,
      TargetKind.power => f.canSetPower,
    };
  }

  void _onAnswer(List<int> bytes) {
    final response = FtmsResponse.parse(bytes);
    final pending = _pending;
    if (response != null && pending != null && !pending.isCompleted) {
      pending.complete(response);
    }
  }

  Future<FtmsResponse> _send(List<int> command) async {
    final pending = _pending = Completer<FtmsResponse>();
    await _point.write(command);
    return pending.future.timeout(_answerTimeout);
  }

  /// Setzt einen Zielwert. Gibt `null` zurück, wenn das Gerät ihn angenommen
  /// hat, sonst den Grund der Ablehnung.
  Future<String?> setTarget(TargetKind kind, double value) async {
    final command = ftmsSetTarget(kind, value);
    if (command == null) return null;
    if (!supports(kind)) return '${kind.label} lässt sich an diesem Gerät nicht steuern';
    try {
      if (!_hasControl) {
        final granted = await _send(ftmsRequestControl);
        if (!granted.success) return 'Steuerung abgelehnt: ${granted.message}';
        _hasControl = true;
      }
      final answer = await _send(command);
      return answer.success ? null : answer.message;
    } on TimeoutException {
      return 'Gerät antwortet nicht';
    } catch (e) {
      return '$e';
    }
  }
}
