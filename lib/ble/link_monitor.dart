import 'dart:async';

import 'package:universal_ble/universal_ble.dart';

/// Eine Änderung der Verbindung zu einem Gerät, mit dem Grund, den Android
/// beim Trennen meldet.
typedef LinkUpdate = ({String deviceId, bool connected, String? reason});

/// Wie lange nach einem Abbruch oder Fehlversuch gewartet wird. Direkt
/// nach einem Abbruch braucht Android einen Moment, um die alte Verbindung
/// aufzuräumen; ein sofortiger Versuch scheitert sonst oft.
Duration reconnectDelay(int failures) => failures == 0
    ? const Duration(milliseconds: 600)
    : const Duration(seconds: 3);

/// Ob vor dem nächsten Versuch kurz gesucht wird. Eine Suche belegt die
/// Funkstrecke und stört die übrigen Geräte, darum erst nach drei
/// Fehlversuchen und dann nur bei jedem dritten.
bool scanBeforeReconnect(int failures) => failures > 0 && failures % 3 == 0;

/// Erkennt eine Verbindung, die Android noch für gesund hält, über die aber
/// nichts mehr kommt: Das Gerät beantwortet die Lebenszeichen nicht mehr
/// und schickt auch keine Messwerte.
class LinkWatch {
  LinkWatch({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _lastData = _now();
  }

  static const silence = Duration(seconds: 30);
  static const missedAnswers = 2;

  final DateTime Function() _now;
  late DateTime _lastData;
  int _missed = 0;

  void sawData() => _lastData = _now();

  void answered(bool ok) => _missed = ok ? 0 : _missed + 1;

  bool get stale =>
      _missed >= missedAnswers && _now().difference(_lastData) >= silence;
}

/// Verteilt die Verbindungsänderungen samt Grund an alle Interessenten.
/// Die Bibliothek kennt dafür nur einen einzigen Empfänger.
class LinkMonitor {
  LinkMonitor._();

  static final _updates = StreamController<LinkUpdate>.broadcast();
  static bool _installed = false;

  static Stream<LinkUpdate> forDevice(String deviceId) {
    if (!_installed) {
      _installed = true;
      UniversalBle.onConnectionChange = (id, connected, error) =>
          _updates.add((deviceId: id, connected: connected, reason: error));
    }
    final wanted = deviceId.toLowerCase();
    return _updates.stream.where((u) => u.deviceId.toLowerCase() == wanted);
  }
}
