import 'package:universal_ble/universal_ble.dart';

import 'device_kind.dart';
import 'uuids.dart';

/// Was ein Gerät nach dem Verbinden über sich verrät. Viele Fitnessgeräte
/// nennen ihre Dienste nicht in der Suche, sondern erst dann.
class ProbeResult {
  const ProbeResult({this.services = const [], this.error});

  final List<String> services;

  /// Warum die Verbindung nicht zustande kam; sonst `null`.
  final String? error;

  bool get connected => error == null;

  DeviceKind kind(String? name) => DeviceKind.detect(name, services);

  /// Liefert das Gerät Werte, die die App versteht?
  bool get supported {
    final found = DeviceKind.detect(null, services);
    return connected && found != DeviceKind.unknown;
  }

  /// Die lesbaren Namen der Dienste, unbekannte als Kennung.
  List<String> get serviceLabels =>
      [for (final s in services) Uuids.label(s) ?? s];
}

/// Verbindet sich kurz mit [device] und liest seine Dienste.
Future<ProbeResult> probeDevice(BleDevice device) async {
  try {
    await device.connect(timeout: const Duration(seconds: 12));
    final services = await device.discoverServices();
    return ProbeResult(services: [for (final s in services) s.uuid]);
  } catch (e) {
    return ProbeResult(error: '$e');
  } finally {
    try {
      await device.disconnect(timeout: const Duration(seconds: 3));
    } catch (_) {
      // War nicht verbunden.
    }
  }
}

/// Eine Zeile je gefundenem Gerät, zum Weitergeben. Damit lässt sich auch
/// später noch klären, was ein unbekanntes Gerät gesendet hat.
String scanReport(Iterable<BleDevice> devices) => [
      for (final d in devices)
        [
          (d.name ?? '').isEmpty ? 'Ohne Name' : d.name!,
          '${d.rssi ?? '?'} dBm',
          DeviceKind.detect(d.name, d.services).label,
          if (d.services.isNotEmpty)
            'Dienste: ${d.services.map((s) => Uuids.label(s) ?? s).join(', ')}',
          if (d.manufacturerDataList.isNotEmpty)
            'Hersteller: ${d.manufacturerDataList.map((m) => m.companyIdRadix16).join(', ')}',
        ].join(' | '),
    ].join('\n');
