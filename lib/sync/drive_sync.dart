import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../data/database.dart';
import '../platform/app_platform.dart';
import '../strava/strava_api.dart';
import 'desktop_google_auth.dart';
import 'sync_engine.dart';

/// Der Ablageort im Google Drive des Nutzers. Die Dateien liegen im
/// App-Datenordner: Er gehört zur App, ist in der Drive-Oberfläche nicht zu
/// sehen und gibt der App keinen Zugriff auf andere Dateien des Nutzers.
class DriveSyncStore implements SyncStore {
  DriveSyncStore(this._api);

  static const _folder = 'appDataFolder';

  final drive.DriveApi _api;
  final Map<String, String?> _ids = {};

  Future<String?> _idOf(String name) async {
    if (_ids.containsKey(name)) return _ids[name];
    final found = await _api.files.list(
      spaces: _folder,
      q: "name = '$name'",
      $fields: 'files(id)',
    );
    return _ids[name] = found.files?.firstOrNull?.id;
  }

  @override
  Future<Uint8List?> read(String name) async {
    final id = await _idOf(name);
    if (id == null) return null;
    final media = await _api.files.get(id,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = BytesBuilder(copy: false);
    await media.stream.forEach(bytes.add);
    return bytes.toBytes();
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final id = await _idOf(name);
    if (id == null) {
      final created = await _api.files.create(
        drive.File()
          ..name = name
          ..parents = [_folder],
        uploadMedia: media,
      );
      _ids[name] = created.id;
    } else {
      await _api.files.update(drive.File(), id, uploadMedia: media);
    }
  }
}

/// Anmeldung bei Google und Abgleich mit Google Drive.
abstract final class DriveSync {
  /// Die Kennung des Web-Clients aus der Google-Cloud-Konsole; ohne sie
  /// lässt Google die Anmeldung nicht zu.
  static const webClientIdKey = 'sync.webClientId';
  static const autoKey = 'sync.auto';
  static const lastRunKey = 'sync.lastRun';

  static const _scopes = [drive.DriveApi.driveAppdataScope];

  /// Die Anmeldung am PC.
  static DesktopGoogleAuth desktopAuth() =>
      DesktopGoogleAuth(const SecureSecretStore());

  static bool _initialized = false;

  /// Ob die Synchronisation eingerichtet und eingeschaltet ist.
  static bool isEnabled(AppDatabase db) =>
      (db.setting(webClientIdKey) ?? '').isNotEmpty &&
      db.flag(autoKey, fallback: false);

  static Future<DriveSyncStore> _store(AppDatabase db,
      {required bool interactive}) async {
    if (AppPlatform.isDesktop) {
      final client = await desktopAuth().client(
          db.setting(webClientIdKey) ?? '', _scopes,
          interactive: interactive);
      if (client == null) {
        throw const DriveSyncException(
            'Nicht bei Google angemeldet. Bitte einmal von Hand abgleichen.');
      }
      return DriveSyncStore(drive.DriveApi(client));
    }
    final signIn = GoogleSignIn.instance;
    if (!_initialized) {
      await signIn.initialize(serverClientId: db.setting(webClientIdKey));
      _initialized = true;
    }
    var account = await signIn.attemptLightweightAuthentication();
    if (account == null) {
      if (!interactive) {
        throw const DriveSyncException(
            'Nicht bei Google angemeldet. Bitte einmal von Hand abgleichen.');
      }
      account = await signIn.authenticate(scopeHint: _scopes);
    }
    final client = account.authorizationClient;
    var authorization = await client.authorizationForScopes(_scopes);
    if (authorization == null) {
      if (!interactive) {
        throw const DriveSyncException(
            'Der Zugriff auf Google Drive ist noch nicht erlaubt. Bitte '
            'einmal von Hand abgleichen.');
      }
      authorization = await client.authorizeScopes(_scopes);
    }
    return DriveSyncStore(
        drive.DriveApi(authorization.authClient(scopes: _scopes)));
  }

  /// Gleicht mit Google Drive ab. Mit [interactive] darf dabei die Anmeldung
  /// oder die Frage nach dem Zugriff erscheinen; ohne schlägt der Abgleich
  /// stattdessen fehl.
  static Future<SyncResult> run(AppDatabase db,
      {required bool interactive}) async {
    final result =
        await synchronize(db, await _store(db, interactive: interactive));
    db.setSetting(lastRunKey, '${DateTime.now().millisecondsSinceEpoch}');
    return result;
  }

  /// Gleicht im Hintergrund ab, wenn die Synchronisation eingeschaltet ist.
  /// Fehler, etwa ohne Internet, bleiben still; der nächste Anlass versucht
  /// es wieder. Gibt zurück, ob dabei etwas hierher übernommen wurde.
  static Future<bool> runInBackground(AppDatabase db) async {
    if (!isEnabled(db)) return false;
    try {
      return (await run(db, interactive: false)).received > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() => AppPlatform.isDesktop
      ? desktopAuth().signOut()
      : GoogleSignIn.instance.signOut();
}

class DriveSyncException implements Exception {
  const DriveSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}
