import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../data/database.dart';
import '../stats/stats.dart';

/// Ein Ablageort für die Synchronisation: benannte Dateien, die sich lesen
/// und überschreiben lassen. Google Drive ist einer, eine Sicherungsdatei ein
/// anderer.
abstract class SyncStore {
  /// Der Inhalt der Datei oder `null`, wenn es sie nicht gibt.
  Future<Uint8List?> read(String name);

  Future<void> write(String name, Uint8List bytes);
}

/// Hält die Dateien im Speicher. Dient als Sicherungsdatei, die sich als
/// Ganzes weitergeben lässt, und in Tests als Ersatz für Google Drive.
class MemorySyncStore implements SyncStore {
  MemorySyncStore();

  /// Liest eine mit [toBackup] erzeugte Sicherung.
  factory MemorySyncStore.fromBackup(List<int> bytes) {
    final store = MemorySyncStore();
    try {
      final json =
          jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
      if (json['fitappBackup'] != 1) throw const FormatException();
      (json['files'] as Map<String, dynamic>).forEach((name, content) {
        store.files[name] = base64Decode(content as String);
      });
    } catch (_) {
      throw const FormatException('Das ist keine FitApp-Sicherung.');
    }
    return store;
  }

  final Map<String, Uint8List> files = {};

  @override
  Future<Uint8List?> read(String name) async => files[name];

  @override
  Future<void> write(String name, Uint8List bytes) async =>
      files[name] = bytes;

  /// Alle Dateien in einer einzigen, komprimierten Datei.
  Uint8List toBackup() => Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode({
        'fitappBackup': 1,
        'files': {
          for (final e in files.entries) e.key: base64Encode(e.value),
        },
      }))));
}

/// Was ein Abgleich bewegt hat.
class SyncResult {
  /// Einträge, die von dort hierher übernommen wurden.
  int received = 0;

  /// Einträge, die von hier dorthin gegangen sind.
  int sent = 0;

  String get message => received == 0 && sent == 0
      ? 'Alles auf dem gleichen Stand.'
      : '$received übernommen, $sent abgegeben.';
}

const _indexFile = 'index.json.gz';
String _workoutFile(String uuid) => 'workout-$uuid.json.gz';

Uint8List _pack(Object json) =>
    Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(json))));

dynamic _unpack(List<int> bytes) => jsonDecode(utf8.decode(gzip.decode(bytes)));

/// Gleicht die Daten dieses Geräts mit dem Ablageort ab (Lastenheft A-061).
///
/// Jeder Eintrag trägt eine geräteübergreifende Kennung und den Zeitpunkt
/// seiner letzten Änderung. Gibt es ihn auf beiden Seiten, gilt die jüngere
/// Fassung. Gelöschtes bleibt als Löschmarke erhalten und setzt sich ebenso
/// durch.
///
/// Am Ablageort liegt ein Verzeichnis aller Einträge samt den kleinen
/// Inhalten (Vorlagen, Übungen, Programme, Profil) und je Training eine
/// eigene Datei mit dessen Messpunkten. So wird ein Training nur übertragen,
/// wenn es sich geändert hat.
Future<SyncResult> synchronize(AppDatabase db, SyncStore store) async {
  final result = SyncResult();
  final indexBytes = await store.read(_indexFile);
  final remote = indexBytes == null
      ? const <String, dynamic>{}
      : _unpack(indexBytes) as Map<String, dynamic>;

  // --- Vorlagen, Übungen, Programme
  for (final table in AppDatabase.syncTables.keys) {
    final local = {
      for (final r in db.syncRows(table)) r['uuid']: r['updated_at'] as int,
    };
    final remoteRows = (remote[table] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final remoteStamps = <Object?, int>{};
    for (final row in remoteRows) {
      remoteStamps[row['uuid']] = row['updated_at'] as int;
      if (db.applySyncRow(table, row)) result.received++;
    }
    local.forEach((uuid, stamp) {
      final there = remoteStamps[uuid];
      if (there == null || stamp > there) result.sent++;
    });
  }

  // --- Profil
  final localProfileAt =
      int.tryParse(db.setting(HeartProfile.updatedAtKey) ?? '') ?? 0;
  final remoteProfile = remote['profile'] as Map<String, dynamic>?;
  final remoteProfileAt = remoteProfile?['updated_at'] as int? ?? 0;
  if (remoteProfile != null && remoteProfileAt > localProfileAt) {
    HeartProfile(
      birthYear: remoteProfile['birth_year'] as int?,
      manualMaxHr: remoteProfile['max_hr'] as int?,
      weightKg: (remoteProfile['weight_kg'] as num?)?.toDouble(),
      sex: Sex.fromId(remoteProfile['sex'] as String?),
    ).save(db);
    // Der Zeitstempel bleibt der des anderen Geräts.
    db.setSetting(HeartProfile.updatedAtKey, '$remoteProfileAt');
    result.received++;
  } else if (localProfileAt > remoteProfileAt) {
    result.sent++;
  }

  // --- Trainings
  final localWorkouts = {
    for (final w in db.workoutSyncIndex()) w['uuid'] as String: w,
  };
  final remoteWorkouts = {
    for (final w in (remote['workouts'] as List? ?? const [])
        .cast<Map<String, dynamic>>())
      w['uuid'] as String: w,
  };
  for (final entry in remoteWorkouts.entries) {
    final uuid = entry.key;
    final there = entry.value;
    final here = localWorkouts[uuid];
    final thereAt = there['updated_at'] as int;
    if (here != null && thereAt <= (here['updated_at'] as int)) continue;
    if (there['deleted'] == 1) {
      db.applySyncedDeletion(uuid, thereAt);
      result.received++;
      continue;
    }
    final file = await store.read(_workoutFile(uuid));
    // Fehlt die Datei, hat ein anderes Gerät den Abgleich nicht beendet; das
    // Training kommt beim nächsten Mal.
    if (file == null) continue;
    db.applySyncedWorkout((_unpack(file) as Map).cast<String, Object?>());
    result.received++;
  }
  for (final entry in localWorkouts.entries) {
    final uuid = entry.key;
    final here = entry.value;
    final there = remoteWorkouts[uuid];
    final hereAt = here['updated_at'] as int;
    if (there != null && hereAt <= (there['updated_at'] as int)) continue;
    if (here['deleted'] != 1) {
      await store.write(_workoutFile(uuid), _pack(db.workoutSyncData(uuid)));
    }
    result.sent++;
  }

  // --- Verzeichnis: Die Datenbank ist jetzt der vereinte Stand.
  if (indexBytes == null || result.sent > 0) {
    final profile = HeartProfile.load(db);
    await store.write(
      _indexFile,
      _pack({
        'version': 1,
        for (final table in AppDatabase.syncTables.keys)
          table: db.syncRows(table),
        'profile': {
          'updated_at':
              int.tryParse(db.setting(HeartProfile.updatedAtKey) ?? '') ?? 0,
          'birth_year': profile.birthYear,
          'max_hr': profile.manualMaxHr,
          'weight_kg': profile.weightKg,
          'sex': profile.sex?.id,
        },
        'workouts': db.workoutSyncIndex(),
      }),
    );
  }
  return result;
}
