import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../data/models.dart';
import '../interval/interval_models.dart';
import 'decoders.dart';
import 'ftms.dart';
import 'ftms_control.dart';
import 'link_monitor.dart';
import 'uuids.dart';

/// Womit sich die App bei einem steuerbaren Gerät meldet, damit es die
/// Verbindung nicht wegen Stille trennt. Wählbar, um herauszufinden, was ein
/// Gerät verträgt.
enum KeepAliveMode {
  control('control', 'Steuererlaubnis', 'Bittet alle 20 s um Steuererlaubnis'),
  read('read', 'Lesen', 'Liest alle 20 s die Fähigkeiten des Geräts'),
  off('off', 'Aus', 'Sendet kein Lebenszeichen');

  const KeepAliveMode(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static KeepAliveMode fromId(String? id) =>
      values.firstWhere((m) => m.id == id, orElse: () => control);
}

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
  SensorConnection(
    this.saved, {
    required this.onData,
    this.onLinkLost,
    this.onLinkRestored,
    this.fastLink = false,
    this.keepAliveMode = KeepAliveMode.control,
  });

  /// Unter diesem Schlüssel steht die Einstellung für [keepAliveMode].
  static const keepAliveKey = 'ble.keepAlive';

  final KeepAliveMode keepAliveMode;

  /// Unter diesem Schlüssel steht die Einstellung für [fastLink].
  static const fastLinkKey = 'ble.fastLink';

  /// Bittet Android um einen schnelleren Funktakt. Kostet etwas Akku und
  /// nicht jedes Gerät mag es, darum nur auf Wunsch.
  final bool fastLink;

  /// Die bestehende Verbindung ist abgebrochen; [reason] ist der Grund, den
  /// Android meldet.
  final void Function(SavedDevice device, String? reason)? onLinkLost;

  /// Nach einem Abbruch steht die Verbindung wieder.
  final void Function(SavedDevice device)? onLinkRestored;

  static const _connectTimeout = Duration(seconds: 15);
  static const _cleanupTimeout = Duration(seconds: 2);

  /// In diesem Abstand bekommt ein steuerbares Fitnessgerät ein
  /// Lebenszeichen. Das Domyos-Laufband trennt die Verbindung, wenn es
  /// rund eine Minute lang nichts von der App empfängt.
  static const _keepAliveInterval = Duration(seconds: 20);
  static const _disconnectTimeout = Duration(seconds: 5);

  final SavedDevice saved;
  final void Function(SavedDevice device, Map<Metric, double> values) onData;

  late final BleDevice _device =
      BleDevice(deviceId: saved.deviceId, name: saved.name);
  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<LinkUpdate>? _linkSub;
  String? _lostReason;
  bool _lostReported = false;
  Completer<void>? _lost;
  Timer? _keepAlive;
  LinkWatch? _watch;
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
    _linkSub = LinkMonitor.forDevice(saved.deviceId).listen((update) {
      if (update.connected) return;
      _lostReason = update.reason;
      _signalLost();
    });
    _run();
  }

  /// Beendet die Verbindung. Wirft nie und wartet höchstens
  /// [_disconnectTimeout] auf das Gerät.
  Future<void> stop() async {
    _stopped = true;
    _signalLost();
    _state = LinkState.stopped;
    try {
      await _linkSub?.cancel();
      await _dropSubscriptions();
      await _device.disconnect(timeout: _disconnectTimeout);
    } catch (_) {
      // War schon getrennt oder ist nicht erreichbar.
    }
  }

  void _signalLost() {
    final lost = _lost;
    if (lost != null && !lost.isCompleted) lost.complete();
  }

  Future<void> _run() async {
    var first = true;
    // Nach einem Abbruch wird fast sofort neu verbunden; meist ist das Gerät
    // noch da, und die Lücke bleibt so kurz, dass sie nicht auffällt. Erst
    // wenn das mehrmals scheitert, folgt eine Suche.
    var failures = 0;
    while (!_stopped) {
      _setState(first ? LinkState.connecting : LinkState.reconnecting);
      first = false;
      var wasConnected = false;
      try {
        await _device.connect(timeout: _connectTimeout);
        final lost = _lost = Completer<void>();
        final services = await _device.discoverServices();
        final watch = _watch = LinkWatch();
        await _subscribe(services);
        if (fastLink) await _requestFastLink();
        final machine = control = await MachineControl.attach(services, _subs);
        if (_stopped) break;
        lastError = null;
        connectCount++;
        wasConnected = true;
        if (_lostReported) {
          _lostReported = false;
          onLinkRestored?.call(saved);
        }
        if (machine != null && keepAliveMode != KeepAliveMode.off) {
          _keepAlive = Timer.periodic(_keepAliveInterval, (_) async {
            watch.answered(await machine.keepAlive(keepAliveMode));
            if (!watch.stale) return;
            _lostReason = linkSilentReason;
            _signalLost();
          });
        }
        _setState(LinkState.connected);
        _lostReason = null;
        await lost.future;
        if (!_stopped) {
          _lostReported = true;
          onLinkLost?.call(saved, _lostReason);
        }
      } catch (e) {
        lastError = '$e';
      }
      _keepAlive?.cancel();
      _watch = null;
      control = null;
      await _dropSubscriptions();
      if (_stopped) break;
      _setState(LinkState.reconnecting);
      // Ein Fehlversuch oder eine verstummte Verbindung darf nichts
      // Halboffenes zurücklassen, sonst scheitert auch der nächste Versuch.
      if (!wasConnected || _lostReason == linkSilentReason) {
        try {
          await _device.disconnect(timeout: _cleanupTimeout);
        } catch (_) {
          // War nicht verbunden.
        }
      }
      failures = wasConnected ? 0 : failures + 1;
      await Future<void>.delayed(reconnectDelay(failures));
      if (_stopped) break;
      if (scanBeforeReconnect(failures)) await _refreshScan();
    }
    _keepAlive?.cancel();
    // Ein Verbindungsaufbau, der beim Stoppen noch lief, kann erst danach
    // fertig geworden sein; das Gerät soll nicht verbunden zurückbleiben.
    try {
      await _device.disconnect(timeout: _disconnectTimeout);
    } catch (_) {
      // War nicht verbunden.
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
          final decode = decoder.create();
          _subs.add(c.onValueReceived.listen((bytes) {
            _watch?.sawData();
            try {
              final values = decode(bytes);
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

  Future<void> _requestFastLink() async {
    try {
      await UniversalBle.requestConnectionPriority(
          saved.deviceId, BleConnectionPriority.highPerformance);
    } catch (_) {
      // Dann bleibt es beim üblichen Takt.
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
  MachineControl._(this._point, this._feature, this.features, this._ranges);

  static const _answerTimeout = Duration(seconds: 3);

  final BleCharacteristic _point;
  final BleCharacteristic? _feature;

  /// Was das Gerät laut eigener Auskunft annimmt; `null`, wenn es dazu
  /// nichts sagt.
  final FtmsFeatures? features;

  /// Die Einstellbereiche, die das Gerät selbst nennt.
  final Map<TargetKind, FtmsRange> _ranges;

  /// Kleinster und größter Zielwert sowie Schrittweite laut Gerät, oder
  /// `null`, wenn es dazu nichts sagt.
  FtmsRange? range(TargetKind kind) => _ranges[kind];

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
    final feature = find(Uuids.ftmsFeature);
    try {
      if (feature != null) features = FtmsFeatures.parse(await feature.read());
    } catch (_) {
      // Ohne Auskunft wird jeder Zielwert versucht; das Gerät antwortet dann.
    }
    final ranges = <TargetKind, FtmsRange>{};
    Future<void> readRange(TargetKind kind, String uuid,
        FtmsRange Function(List<int>) parse) async {
      try {
        final c = find(uuid);
        if (c != null) ranges[kind] = parse(await c.read());
      } catch (_) {
        // Ohne Angabe gelten die Grenzen der App.
      }
    }

    await readRange(
        TargetKind.speed, Uuids.supportedSpeedRange, FtmsRange.parseSpeed);
    await readRange(TargetKind.resistance, Uuids.supportedResistanceRange,
        FtmsRange.parseResistance);
    final control = MachineControl._(point, feature, features, ranges);
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

  Future<void> _busy = Future.value();

  /// Sendet einen Befehl und wartet auf die Antwort. Befehle laufen streng
  /// nacheinander: Das Gerät beantwortet immer nur den zuletzt gesendeten.
  Future<FtmsResponse> _send(List<int> command) {
    final answer = _busy.then((_) async {
      final pending = _pending = Completer<FtmsResponse>();
      await _point.write(command);
      return pending.future.timeout(_answerTimeout);
    });
    _busy = answer.then((_) {}, onError: (_) {});
    return answer;
  }

  /// Meldet sich beim Gerät, damit es die Verbindung nicht wegen Stille
  /// trennt. Üblich ist die Bitte um Steuererlaubnis: Sie ändert nichts am
  /// laufenden Training und darf beliebig oft gestellt werden. Gibt zurück,
  /// ob das Gerät geantwortet hat.
  Future<bool> keepAlive([KeepAliveMode mode = KeepAliveMode.control]) async {
    try {
      if (mode == KeepAliveMode.read) {
        final feature = _feature;
        if (feature == null) return false;
        await feature.read().timeout(_answerTimeout);
        return true;
      }
      final answer = await _send(ftmsRequestControl);
      if (answer.success) _hasControl = true;
      return true;
    } catch (_) {
      // Ein verpasstes Lebenszeichen ist kein Fehler; das nächste folgt.
      return false;
    }
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
