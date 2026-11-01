import 'dart:async';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/device_kind.dart';
import '../ble/device_probe.dart';
import 'file_handover.dart';

/// Sucht Bluetooth-Geräte in der Nähe. Ein Tipp auf ein Gerät schließt die
/// Seite und gibt es als Ergebnis zurück.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  static const _scanDuration = Duration(seconds: 20);

  final Map<String, BleDevice> _devices = {};
  StreamSubscription<BleDevice>? _scanSub;
  Timer? _scanTimer;
  bool _scanning = false;
  bool _onlyKnown = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _scanSub = UniversalBle.scanStream.listen(_onDevice);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanSub?.cancel();
    UniversalBle.stopScan();
    super.dispose();
  }

  void _onDevice(BleDevice device) {
    final known = _devices[device.deviceId];
    // Name und Dienste kommen oft in getrennten Funkpaketen; nichts davon
    // darf durch ein späteres, ärmeres Paket verloren gehen.
    if (known != null && (device.name ?? '').isEmpty) device.name = known.name;
    // Manche Geräte nennen ihren Dienst nur als Dienstdaten.
    device.services = {
      ...?known?.services,
      ...device.services,
      ...device.serviceData.keys,
    }.toList();
    if (device.manufacturerDataList.isEmpty && known != null) {
      device.manufacturerDataList = known.manufacturerDataList;
    }
    setState(() => _devices[device.deviceId] = device);
  }

  Future<void> _startScan() async {
    setState(() => _message = null);
    try {
      final state = await UniversalBle.getBluetoothAvailabilityState();
      if (state != AvailabilityState.poweredOn) {
        setState(() => _message = switch (state) {
              AvailabilityState.poweredOff =>
                'Bluetooth ist ausgeschaltet. Bitte einschalten.',
              AvailabilityState.unauthorized =>
                'Die App hat keine Bluetooth-Berechtigung.',
              AvailabilityState.unsupported =>
                'Dieses Gerät unterstützt kein Bluetooth Low Energy.',
              _ => 'Bluetooth ist noch nicht bereit. Bitte erneut versuchen.',
            });
        return;
      }
      _devices.clear();
      await UniversalBle.startScan();
      setState(() => _scanning = true);
      _scanTimer?.cancel();
      _scanTimer = Timer(_scanDuration, _stopScan);
    } catch (e) {
      setState(() => _message = 'Suche nicht möglich: $e');
    }
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    try {
      await UniversalBle.stopScan();
    } catch (_) {
      // Die Suche war schon beendet.
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _open(BleDevice device) async {
    await _stopScan();
    if (mounted) Navigator.of(context).pop(device);
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices.values.where((d) {
      if (!_onlyKnown) return true;
      return DeviceKind.detect(d.name, d.services) != DeviceKind.unknown;
    }).toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerät hinzufügen'),
        actions: [
          if (_devices.isNotEmpty)
            IconButton(
              tooltip: 'Suchergebnis teilen',
              icon: const Icon(Icons.ios_share),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (await handOverText(scanReport(_devices.values))) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('In die Zwischenablage kopiert.')));
                }
              },
            ),
        ],
        bottom: _scanning
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'scan',
        onPressed: _scanning ? _stopScan : _startScan,
        icon: Icon(_scanning ? Icons.stop : Icons.search),
        label: Text(_scanning ? 'Stopp' : 'Suchen'),
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Nur Sport- und Fitnessgeräte'),
            subtitle: Text('${devices.length} von ${_devices.length} gefunden'),
            value: _onlyKnown,
            onChanged: (v) => setState(() => _onlyKnown = v),
          ),
          if (_onlyKnown && _devices.length > devices.length)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Viele Geräte im Studio nennen erst nach dem Verbinden, was '
                'sie können. Findest du deins nicht, schalte den Filter aus '
                'und tippe es an: Die App prüft es dann.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _scanning
                            ? 'Suche läuft …'
                            : 'Gerät einschalten bzw. Brustgurt anlegen '
                                'und auf „Suchen" tippen.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: devices.length,
                    itemBuilder: (context, i) {
                      final d = devices[i];
                      final kind = DeviceKind.detect(d.name, d.services);
                      final name = (d.name ?? '').isEmpty ? 'Ohne Name' : d.name!;
                      return ListTile(
                        leading: Icon(kind.icon),
                        title: Text(name),
                        subtitle: Text(kind.label),
                        trailing: d.rssi == null ? null : Text('${d.rssi} dBm'),
                        onTap: () => _open(d),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
