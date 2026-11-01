import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../platform/app_platform.dart';
import '../sync/auto_backup.dart';
import '../sync/drive_sync.dart';
import '../sync/sync_engine.dart';
import 'file_handover.dart';
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
  final _clientSecret = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
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
    if (clientId.isEmpty) return 'Bitte zuerst die Client-ID eintragen.';
    if (AppPlatform.isDesktop) {
      final auth = DriveSync.desktopAuth();
      if (_clientSecret.text.trim().isNotEmpty) {
        await auth.setSecret(_clientSecret.text);
        _clientSecret.clear();
      }
      if (!await auth.hasSecret) {
        return 'Bitte zuerst das Client-Secret eintragen.';
      }
    }
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
    final done = await handOverFiles([XFile(file.path)],
        subject: 'FitApp-Sicherung');
    return done ? 'Sicherung erstellt.' : 'Nichts gespeichert.';
  }

  Future<String> _importBackup() async {
    final files = await FilePicker.pickFiles(
        dialogTitle: 'FitApp-Sicherung wählen');
    if (files.isEmpty) return 'Nichts ausgewählt.';
    final store = MemorySyncStore.fromBackup(await files.first.readAsBytes());
    final result = await synchronize(widget.db, store);
    return 'Sicherung eingespielt: ${result.received} Einträge übernommen.';
  }

  Future<String> _chooseBackupFolder() async {
    if (!await AutoBackup.chooseFolder(widget.db)) return 'Nichts ausgewählt.';
    await AutoBackup.run(widget.db);
    return 'Ordner gemerkt und erste Sicherung abgelegt.';
  }

  Future<String> _backupNow() async {
    await AutoBackup.run(widget.db);
    return 'Sicherung abgelegt.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backupFolder = AutoBackup.folderName(widget.db);
    final backupAt = AutoBackup.lastRun(widget.db);
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
          Text('Automatische Sicherung', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            backupFolder == null
                ? 'Legt einmal am Tag von selbst eine Sicherungsdatei in '
                    'einem Ordner deiner Wahl ab, je Wochentag eine. So '
                    'liegen immer die Stände der letzten sieben Tage vor.'
                : 'Ordner: $backupFolder\n'
                    '${backupAt == null ? 'Noch keine Sicherung.' : 'Zuletzt gesichert: ${formatDateTime(backupAt)}'}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _run(_chooseBackupFolder),
                icon: const Icon(Icons.folder_open),
                label: Text(
                    backupFolder == null ? 'Ordner wählen' : 'Ordner ändern'),
              ),
              if (backupFolder != null) ...[
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _run(_backupNow),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Jetzt sichern'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => AutoBackup.disable(widget.db)),
                  child: const Text('Ausschalten'),
                ),
              ],
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
            'hier die Client-ID ein, am PC die des Typs „Desktop-App" samt '
            'Client-Secret.',
          ),
          TextField(
            controller: _clientId,
            decoration: InputDecoration(
              labelText: AppPlatform.isDesktop
                  ? 'Desktop-Client-ID'
                  : 'Web-Client-ID',
              hintText: '….apps.googleusercontent.com',
            ),
          ),
          if (AppPlatform.isDesktop)
            TextField(
              controller: _clientSecret,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Client-Secret (nur beim ersten Mal)',
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
