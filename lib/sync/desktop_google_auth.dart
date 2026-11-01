import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../platform/app_platform.dart';
import '../strava/strava_api.dart';

/// Anmeldung bei Google am PC. Die Android-Anmeldung gibt es dort nicht:
/// Google öffnet stattdessen den Browser und schickt das Ergebnis an einen
/// kurzlebigen Port auf dem eigenen Rechner. Der Client ist vom Typ
/// „Desktop-App" und hat deshalb auch ein Geheimnis.
class DesktopGoogleAuth {
  DesktopGoogleAuth(this._store);

  static const _secretKey = 'google.desktopSecret';
  static const _credentialsKey = 'google.desktopCredentials';

  final SecretStore _store;

  Future<bool> get hasSecret async =>
      (await _store.read(_secretKey) ?? '').isNotEmpty;

  Future<void> setSecret(String secret) =>
      _store.write(_secretKey, secret.trim());

  Future<void> signOut() => _store.write(_credentialsKey, null);

  /// Ein Client, der sein Zugriffstoken selbst erneuert. Ohne [interactive]
  /// meldet sich niemand neu an; dann ist das Ergebnis `null`.
  Future<AutoRefreshingAuthClient?> client(
    String clientId,
    List<String> scopes, {
    required bool interactive,
  }) async {
    final id = ClientId(clientId, await _store.read(_secretKey));
    final saved = await _store.read(_credentialsKey);
    if (saved != null) {
      final credentials = AccessCredentials.fromJson(
          (jsonDecode(saved) as Map).cast<String, dynamic>());
      if (credentials.scopes.toSet().containsAll(scopes)) {
        return _remembering(autoRefreshingClient(id, credentials, http.Client()));
      }
    }
    if (!interactive) return null;
    return _remembering(await clientViaUserConsent(
      id,
      scopes,
      (url) => openInBrowser(url),
    ));
  }

  AutoRefreshingAuthClient _remembering(AutoRefreshingAuthClient client) {
    Future<void> save(AccessCredentials c) =>
        _store.write(_credentialsKey, jsonEncode(c.toJson()));
    save(client.credentials);
    client.credentialUpdates.listen(save);
    return client;
  }
}
