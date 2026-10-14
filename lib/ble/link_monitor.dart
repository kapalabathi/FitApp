import 'dart:async';

import 'package:universal_ble/universal_ble.dart';

/// Eine Änderung der Verbindung zu einem Gerät, mit dem Grund, den Android
/// beim Trennen meldet.
typedef LinkUpdate = ({String deviceId, bool connected, String? reason});

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
