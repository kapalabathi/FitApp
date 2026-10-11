import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/device_kind.dart';
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

  Future<void> _add() async {
    final found = await Navigator.of(context).push<BleDevice>(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (found == null) return;
    final name = (found.name ?? '').isEmpty ? 'Gerät' : found.name!;
    widget.db.saveDevice(SavedDevice(
      deviceId: found.deviceId,
      name: name,
      kind: DeviceKind.detect(found.name, found.services),
    ));
    _load();
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
      body: _devices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Noch keine Geräte gemerkt.\nGemerkte Geräte verbinden sich '
                  'beim Trainingsstart von selbst.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
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
