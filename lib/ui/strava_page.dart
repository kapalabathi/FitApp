import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../data/database.dart';
import '../strava/strava_api.dart';
import '../strava/strava_service.dart';

/// Verbindung mit Strava einrichten, Aktivitäten importieren, automatischen
/// Upload ein- und ausschalten.
class StravaPage extends StatefulWidget {
  const StravaPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<StravaPage> createState() => _StravaPageState();
}

class _StravaPageState extends State<StravaPage> {
  late final StravaApi _api = createStravaApi();
  late final StravaService _service = StravaService(widget.db, _api);
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();

  bool _loading = true;
  bool _hasCredentials = false;
  bool _connected = false;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final hasCredentials = await _api.hasCredentials;
    final connected = await _api.isConnected;
    _clientId.text = await _api.clientId ?? '';
    if (!mounted) return;
    setState(() {
      _hasCredentials = hasCredentials;
      _connected = connected;
      _loading = false;
    });
  }

  /// Führt [action] aus und zeigt dabei den Fortschritt, danach das Ergebnis
  /// oder die Fehlermeldung.
  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      message = await action();
    } on StravaException catch (e) {
      message = e.message;
    } catch (e) {
      message = 'Das hat nicht geklappt: $e';
    }
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  Future<String?> _connect() async {
    if (_clientId.text.trim().isEmpty || _clientSecret.text.trim().isEmpty) {
      if (!_hasCredentials) return 'Bitte Client-ID und Client-Secret eintragen.';
    } else {
      await _api.setCredentials(_clientId.text, _clientSecret.text);
      _clientSecret.clear();
    }
    final callback = await FlutterWebAuth2.authenticate(
      url: (await _api.authorizeUri()).toString(),
      callbackUrlScheme: StravaApi.callbackScheme,
    );
    await _api.completeAuthorization(callback);
    return 'Mit Strava verbunden.';
  }

  Future<String?> _import() async {
    final count = await _service.importNew();
    return switch (count) {
      0 => 'Keine neuen Aktivitäten bei Strava.',
      1 => 'Eine Aktivität importiert.',
      _ => '$count Aktivitäten importiert.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strava'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _connected ? 'Verbunden' : 'Nicht verbunden',
                  style: theme.textTheme.titleLarge,
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_message!, style: theme.textTheme.bodyLarge),
                  ),
                const SizedBox(height: 16),
                if (_connected) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _run(_import),
                    icon: const Icon(Icons.download),
                    label: const Text('Neue Aktivitäten importieren'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Holt Aktivitäten, die die App noch nicht kennt, mit '
                    'Strecke und Puls – zum Beispiel Läufe von der Uhr. Beim '
                    'ersten Mal die der letzten 30 Tage.',
                    style: theme.textTheme.bodySmall,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nach dem Training hochladen'),
                    subtitle: const Text(
                        'Lädt jedes beendete Training von selbst hoch, außer '
                        'bei Strava liegt schon eine ähnliche Aktivität.'),
                    value: widget.db
                        .flag(StravaService.autoUploadKey, fallback: false),
                    onChanged: (v) => setState(() =>
                        widget.db.setFlag(StravaService.autoUploadKey, v)),
                  ),
                  const Divider(height: 32),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await _api.disconnect();
                              widget.db.setFlag(
                                  StravaService.autoUploadKey, false);
                              return 'Verbindung getrennt.';
                            }),
                    child: const Text('Verbindung trennen'),
                  ),
                ] else ...[
                  const Text(
                    'So richtest du die Verbindung ein:\n\n'
                    '1. Auf strava.com unter Einstellungen → „Meine API-'
                    'Anwendung" eine Anwendung anlegen.\n'
                    '2. Als „Authorization Callback Domain" dort localhost '
                    'eintragen.\n'
                    '3. Client-ID und Client-Secret von dort hier eintragen '
                    'und verbinden.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _clientId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Client-ID'),
                  ),
                  TextField(
                    controller: _clientSecret,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Client-Secret',
                      helperText: _hasCredentials
                          ? 'Bereits gespeichert; nur zum Ändern neu eintragen.'
                          : 'Bleibt verschlüsselt auf diesem Gerät.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => _run(_connect),
                    child: const Text('Mit Strava verbinden'),
                  ),
                ],
              ],
            ),
    );
  }
}
