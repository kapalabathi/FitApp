import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/device_kind.dart';
import '../ble/device_probe.dart';
import '../ble/sensor_connection.dart';
import '../data/database.dart';
import '../data/models.dart';
import 'device_page.dart';
import 'scan_page.dart';

/// Die gemerkten Geräte: hinzufügen, umbenennen, entfernen, prüfen.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<SavedDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _devices = widget.db.devices());

  KeepAliveMode get _keepAliveMode => KeepAliveMode.fromId(
      widget.db.setting(SensorConnection.keepAliveKey));

  Future<void> _add() async {
    final found = await Navigator.of(context).push<BleDevice>(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (found == null) return;
    final name = (found.name ?? '').isEmpty ? 'Gerät' : found.name!;
    var kind = DeviceKind.detect(found.name, found.services);
    if (kind == DeviceKind.unknown || kind == DeviceKind.likelyMachine) {
      final checked = await _check(found, name, kind);
      if (checked == null) return;
      kind = checked;
    }
    widget.db.saveDevice(SavedDevice(
      deviceId: found.deviceId,
      name: name,
      kind: kind,
    ));
    _load();
  }

  /// Verbindet sich mit einem Gerät, das die Suche nicht einordnen konnte.
  /// Gibt die Art zurück oder `null`, wenn es nicht gemerkt werden soll.
  Future<DeviceKind?> _check(
      BleDevice device, String name, DeviceKind fallback) async {
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Expanded(child: Text('Gerät wird geprüft …')),
          ],
        ),
      ),
    );
    final result = await probeDevice(device);
    navigator.pop();
    if (!mounted) return null;
    if (result.supported) return result.kind(device.name);
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: SelectableText(result.connected
              ? 'Das Gerät sendet nichts, was die App versteht. Es bietet:\n'
                  '${result.serviceLabels.join('\n')}'
              : 'Die Verbindung kam nicht zustande. Vielleicht nimmt das '
                  'Gerät keine Verbindung an oder ist schon mit einer '
                  'anderen App oder dem Studiosystem verbunden.\n\n'
                  '${result.error}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Verwerfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trotzdem merken'),
          ),
        ],
      ),
    );
    return keep == true ? fallback : null;
  }

  Future<void> _rename(SavedDevice d) async {
    final controller = TextEditingController(text: d.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerät umbenennen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    widget.db.renameDevice(d.deviceId, name.trim());
    _load();
  }

  Future<void> _forget(SavedDevice d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${d.name}" entfernen?'),
        content: const Text(
            'Aufgezeichnete Trainings bleiben erhalten. Das Gerät lässt sich '
            'jederzeit neu hinzufügen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.db.forgetDevice(d.deviceId);
    _load();
  }

  void _diagnose(SavedDevice d) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DevicePage(device: BleDevice(deviceId: d.deviceId, name: d.name)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geräte')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-device',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Gerät hinzufügen'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          SwitchListTile(
            title: const Text('Schneller Funktakt'),
            subtitle: const Text(
                'Zum Ausprobieren bei Abbrüchen. Braucht etwas mehr Akku.'),
            value: widget.db.setting(SensorConnection.fastLinkKey) == '1',
            onChanged: (on) => setState(() => widget.db
                .setSetting(SensorConnection.fastLinkKey, on ? '1' : '0')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lebenszeichen an Laufband und Bike'),
                const SizedBox(height: 8),
                SegmentedButton<KeepAliveMode>(
                  segments: [
                    for (final m in KeepAliveMode.values)
                      ButtonSegment(value: m, label: Text(m.label)),
                  ],
                  selected: {_keepAliveMode},
                  onSelectionChanged: (s) => setState(() => widget.db
                      .setSetting(SensorConnection.keepAliveKey, s.first.id)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_keepAliveMode.description}. Zum Ausprobieren, wenn '
                  'ein Gerät die Verbindung regelmäßig trennt.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Noch keine Geräte gemerkt.\nGemerkte Geräte verbinden sich '
                'beim Trainingsstart von selbst.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final d in _devices)
            ListTile(
              leading: Icon(d.kind.icon),
              title: Text(d.name),
              subtitle: Text(d.kind.label),
              trailing: PopupMenuButton<VoidCallback>(
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () => _diagnose(d),
                    child: const Text('Prüfen und Gerätebericht'),
                  ),
                  PopupMenuItem(
                    value: () => _rename(d),
                    child: const Text('Umbenennen'),
                  ),
                  PopupMenuItem(
                    value: () => _forget(d),
                    child: const Text('Entfernen'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
