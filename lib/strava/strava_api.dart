import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Ablage für Zugangsdaten. Auf dem Gerät liegt sie im verschlüsselten
/// Speicher von Android; so bleiben die Daten auch bei einer späteren
/// Synchronisation der Datenbank außen vor.
abstract class SecretStore {
  Future<String?> read(String key);

  /// `null` löscht den Eintrag.
  Future<void> write(String key, String? value);
}

class SecureSecretStore implements SecretStore {
  const SecureSecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}

/// Ein Fehler im Umgang mit Strava, mit einer Meldung für den Nutzer.
class StravaException implements Exception {
  const StravaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Die Schnittstelle zu Strava: Anmeldung, Aktivitäten lesen, hochladen.
class StravaApi {
  StravaApi(this._http, this._store);

  /// Dorthin schickt Strava nach der Anmeldung zurück. In der Strava-
  /// Anwendung muss als „Authorization Callback Domain" `localhost` stehen.
  static const redirectUri = 'fitapp://localhost/strava';
  static const callbackScheme = 'fitapp';
  static const scopes = ['activity:write', 'activity:read_all'];

  static const _host = 'www.strava.com';
  static const _clientIdKey = 'strava.clientId';
  static const _clientSecretKey = 'strava.clientSecret';
  static const _accessKey = 'strava.accessToken';
  static const _refreshKey = 'strava.refreshToken';
  static const _expiresKey = 'strava.expiresAt';

  /// Ein Zugriffstoken, das in weniger als dieser Zeit abläuft, wird vor der
  /// nächsten Anfrage erneuert.
  static const _refreshMargin = Duration(minutes: 5);

  final http.Client _http;
  final SecretStore _store;

  Future<String?> get clientId => _store.read(_clientIdKey);
  Future<bool> get hasCredentials async =>
      (await _store.read(_clientIdKey) ?? '').isNotEmpty &&
      (await _store.read(_clientSecretKey) ?? '').isNotEmpty;
  Future<bool> get isConnected async =>
      (await _store.read(_refreshKey)) != null;

  Future<void> setCredentials(String clientId, String clientSecret) async {
    await _store.write(_clientIdKey, clientId.trim());
    await _store.write(_clientSecretKey, clientSecret.trim());
  }

  /// Die Seite, auf der der Nutzer der App den Zugriff erlaubt.
  Future<Uri> authorizeUri() async => Uri.https(_host, '/oauth/authorize', {
        'client_id': await _store.read(_clientIdKey) ?? '',
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'approval_prompt': 'auto',
        'scope': scopes.join(','),
      });

  /// Schließt die Anmeldung mit der Adresse ab, auf die Strava zurückgeleitet
  /// hat.
  Future<void> completeAuthorization(String callbackUrl) async {
    final query = Uri.parse(callbackUrl).queryParameters;
    final code = query['code'];
    if (code == null) {
      throw StravaException(query['error'] == 'access_denied'
          ? 'Der Zugriff wurde bei Strava abgelehnt.'
          : 'Strava hat keinen Anmeldecode geliefert.');
    }
    final granted = (query['scope'] ?? '').split(',');
    if (!scopes.every(granted.contains)) {
      throw const StravaException(
          'Bitte bei Strava beide Häkchen gesetzt lassen: Aktivitäten '
          'hochladen und private Aktivitäten ansehen.');
    }
    await _token({'code': code, 'grant_type': 'authorization_code'});
  }

  /// Vergisst die Anmeldung. Die Kennung der Strava-Anwendung bleibt.
  Future<void> disconnect() async {
    for (final key in [_accessKey, _refreshKey, _expiresKey]) {
      await _store.write(key, null);
    }
  }

  Future<void> _token(Map<String, String> grant) async {
    final response = await _http.post(Uri.https(_host, '/oauth/token'), body: {
      'client_id': await _store.read(_clientIdKey) ?? '',
      'client_secret': await _store.read(_clientSecretKey) ?? '',
      ...grant,
    });
    if (response.statusCode != 200) {
      throw StravaException(response.statusCode == 400 ||
              response.statusCode == 401
          ? 'Strava lehnt die Anmeldung ab. Stimmen Client-ID und Client-'
              'Secret, und ist die Verbindung noch gültig?'
          : 'Anmeldung bei Strava fehlgeschlagen (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    await _store.write(_accessKey, json['access_token'] as String);
    // Strava kann bei jeder Erneuerung ein neues Token ausgeben; das alte
    // gilt dann sofort nicht mehr.
    await _store.write(_refreshKey, json['refresh_token'] as String);
    await _store.write(_expiresKey, '${json['expires_at']}');
  }

  Future<String> _accessToken() async {
    final refresh = await _store.read(_refreshKey);
    if (refresh == null) {
      throw const StravaException('Die App ist nicht mit Strava verbunden.');
    }
    final expires = int.tryParse(await _store.read(_expiresKey) ?? '') ?? 0;
    final limit = DateTime.now().add(_refreshMargin).millisecondsSinceEpoch;
    if (expires * 1000 < limit) {
      await _token({'grant_type': 'refresh_token', 'refresh_token': refresh});
    }
    return (await _store.read(_accessKey))!;
  }

  Future<Map<String, String>> _headers() async =>
      {'Authorization': 'Bearer ${await _accessToken()}'};

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final response = await _http.get(Uri.https(_host, '/api/v3$path', query),
        headers: await _headers());
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw StravaException(switch (response.statusCode) {
      401 => 'Strava erkennt die Anmeldung nicht mehr an. Bitte neu verbinden.',
      429 => 'Strava nimmt gerade keine weiteren Anfragen an. Bitte in einer '
          'Viertelstunde erneut versuchen.',
      _ => 'Strava meldet einen Fehler (${response.statusCode}).',
    });
  }

  /// Die Aktivitäten des Nutzers in einem Zeitraum, neueste zuerst.
  Future<List<Map<String, dynamic>>> activities({
    required DateTime after,
    DateTime? before,
    int perPage = 50,
  }) async {
    final list = await _get('/athlete/activities', {
      'after': '${after.millisecondsSinceEpoch ~/ 1000}',
      if (before != null) 'before': '${before.millisecondsSinceEpoch ~/ 1000}',
      'per_page': '$perPage',
    }) as List;
    return list.cast<Map<String, dynamic>>();
  }

  /// Die Messreihen einer Aktivität, nach Art benannt.
  Future<Map<String, List<dynamic>>> streams(int activityId) async {
    final json = await _get('/activities/$activityId/streams', {
      'keys': 'time,latlng,altitude,heartrate,distance,velocity_smooth,'
          'cadence,watts',
      'key_by_type': 'true',
    }) as Map<String, dynamic>;
    return {
      for (final e in json.entries)
        e.key: ((e.value as Map)['data'] as List?) ?? const [],
    };
  }

  /// Lädt eine FIT-Datei hoch und gibt die Nummer des Uploads zurück. Strava
  /// verarbeitet die Datei danach im Hintergrund, siehe [uploadStatus].
  Future<int> upload({
    required Uint8List fit,
    required String name,
    required String sportType,
    required bool trainer,
    required String externalId,
    String? description,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.https(_host, '/api/v3/uploads'))
          ..headers.addAll(await _headers())
          ..fields.addAll({
            'data_type': 'fit',
            'name': name,
            'sport_type': sportType,
            'trainer': trainer ? '1' : '0',
            'external_id': externalId,
            'description': ?description,
          })
          ..files.add(http.MultipartFile.fromBytes('file', fit,
              filename: '$externalId.fit'));
    final response = await http.Response.fromStream(await _http.send(request));
    final json = _decode(response) as Map<String, dynamic>;
    return json['id'] as int;
  }

  /// Stand eines Uploads: die Nummer der fertigen Aktivität, eine
  /// Fehlermeldung von Strava, oder beides `null`, solange noch verarbeitet
  /// wird.
  Future<({int? activityId, String? error})> uploadStatus(int uploadId) async {
    final json = await _get('/uploads/$uploadId') as Map<String, dynamic>;
    return (
      activityId: json['activity_id'] as int?,
      error: json['error'] as String?,
    );
  }
}
