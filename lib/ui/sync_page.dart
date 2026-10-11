import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../sync/drive_sync.dart';
import '../sync/sync_engine.dart';
import 'format.dart';

/// Abgleich zwischen den Geräten: über Google Drive oder von Hand über eine
/// Sicherungsdatei.
class SyncPage extends StatefulWidget {
  const SyncPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  late final _clientId = TextEditingController(
      text: widget.db.setting(DriveSync.webClientIdKey) ?? '');
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _clientId.dispose();
    super.dispose();
  }

  /// Führt [action] aus und zeigt dabei den Fortschritt, danach das Ergebnis
  /// oder die Fehlermeldung.
  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String message;
    try {
      message = await action();
    } on FormatException catch (e) {
      message = e.message;
    } catch (e) {
      message = 'Das hat nicht geklappt: $e';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  Future<String> _syncDrive() async {
    final clientId = _clientId.text.trim();
    if (clientId.isEmpty) return 'Bitte zuerst die Web-Client-ID eintragen.';
    widget.db.setSetting(DriveSync.webClientIdKey, clientId);
    final result = await DriveSync.run(widget.db, interactive: true);
    // Nach dem ersten erfolgreichen Abgleich läuft er von selbst weiter.
    if (widget.db.setting(DriveSync.autoKey) == null) {
      widget.db.setFlag(DriveSync.autoKey, true);
    }
    return 'Google Drive: ${result.message}';
  }

  Future<String> _exportBackup() async {
    final store = MemorySyncStore();
    await synchronize(widget.db, store);
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final file = File(p.join(
        (await getTemporaryDirectory()).path, 'fitapp_sicherung_$stamp.fitapp'));
    await file.writeAsBytes(store.toBackup());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: 'FitApp-Sicherung',
    ));
    return 'Sicherung erstellt.';
  }

  Future<String> _importBackup() async {
    final files = await FilePicker.pickFiles(
        dialogTitle: 'FitApp-Sicherung wählen');
    if (files.isEmpty) return 'Nichts ausgewählt.';
    final store = MemorySyncStore.fromBackup(await files.first.readAsBytes());
    final result = await synchronize(widget.db, store);
    return 'Sicherung eingespielt: ${result.received} Einträge übernommen.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastRun = int.tryParse(widget.db.setting(DriveSync.lastRunKey) ?? '');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation'),
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
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_message!, style: theme.textTheme.bodyLarge),
            ),
          Text('Sicherungsdatei', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Alle Trainings, Vorlagen, Übungen und Programme in einer Datei. '
            'Auf einem anderen Gerät eingespielt, werden die Daten '
            'zusammengeführt: Nichts wird doppelt, und bei Unterschieden gilt '
            'die jüngere Änderung.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _run(_exportBackup),
                icon: const Icon(Icons.upload_file),
                label: const Text('Sicherung erstellen'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _run(_importBackup),
                icon: const Icon(Icons.download),
                label: const Text('Sicherung einspielen'),
              ),
            ],
          ),
          const Divider(height: 48),
          Text('Google Drive', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            lastRun == null
                ? 'Noch nicht abgeglichen.'
                : 'Zuletzt abgeglichen: '
                    '${formatDateTime(DateTime.fromMillisecondsSinceEpoch(lastRun))}',
          ),
          const SizedBox(height: 12),
          const Text(
            'Der automatische Abgleich braucht eine einmalige Einrichtung in '
            'der Google-Cloud-Konsole; die Schritte stehen in der Datei '
            'docs/GOOGLE-DRIVE-EINRICHTUNG.md des Projekts. Am Ende trägst du '
            'hier die Web-Client-ID ein.',
          ),
          TextField(
            controller: _clientId,
            decoration: const InputDecoration(
              labelText: 'Web-Client-ID',
              hintText: '….apps.googleusercontent.com',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(_syncDrive),
            icon: const Icon(Icons.sync),
            label: const Text('Jetzt abgleichen'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatisch abgleichen'),
            subtitle: const Text(
                'Beim Start der App und nach jedem Training, sofern Internet '
                'besteht'),
            value: widget.db.flag(DriveSync.autoKey, fallback: false),
            onChanged: (v) =>
                setState(() => widget.db.setFlag(DriveSync.autoKey, v)),
          ),
        ],
      ),
    );
  }
}
