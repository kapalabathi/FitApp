import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../data/database.dart';
import 'sync_engine.dart';

/// Legt regelmäßig eine Sicherungsdatei in einem Ordner ab, den der Nutzer
/// einmal gewählt hat, etwa in „Dokumente" oder auf einer Speicherkarte.
///
/// Je Wochentag gibt es eine Datei, die in der Woche darauf überschrieben
/// wird. So liegen immer die Stände der letzten sieben Tage vor, ohne dass
/// der Ordner wächst.
abstract final class AutoBackup {
  static const _folderUriKey = 'backup.folderUri';
  static const _folderNameKey = 'backup.folderName';
  static const _lastRunKey = 'backup.lastRun';

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  /// Der Name des gewählten Ordners, oder `null`, wenn keiner gewählt ist.
  static String? folderName(AppDatabase db) =>
      db.setting(_folderUriKey) == null ? null : db.setting(_folderNameKey);

  static DateTime? lastRun(AppDatabase db) {
    final ms = int.tryParse(db.setting(_lastRunKey) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Lässt den Nutzer den Ordner wählen und merkt ihn sich. Gibt zurück, ob
  /// ein Ordner gewählt wurde.
  static Future<bool> chooseFolder(AppDatabase db) async {
    final folder = await SafUtil().pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    if (folder == null) return false;
    db
      ..setSetting(_folderUriKey, folder.uri)
      ..setSetting(_folderNameKey, folder.name);
    return true;
  }

  static void disable(AppDatabase db) {
    db
      ..setSetting(_folderUriKey, null)
      ..setSetting(_folderNameKey, null);
  }

  /// Der Name der Datei für den Wochentag von [day].
  static String fileName(DateTime day) =>
      'fitapp_sicherung_${_weekdays[day.weekday - 1]}.fitapp';

  /// Ob heute schon gesichert wurde.
  static bool isDue(AppDatabase db, DateTime now) {
    final last = lastRun(db);
    return last == null ||
        last.year != now.year ||
        last.month != now.month ||
        last.day != now.day;
  }

  /// Schreibt jetzt eine Sicherung in den gewählten Ordner.
  static Future<void> run(AppDatabase db, {DateTime? now}) async {
    final uri = db.setting(_folderUriKey);
    if (uri == null) {
      throw const FormatException('Es ist kein Ordner gewählt.');
    }
    final time = now ?? DateTime.now();
    final store = MemorySyncStore();
    await synchronize(db, store);
    await SafStream().writeFileBytes(
      uri,
      fileName(time),
      'application/octet-stream',
      store.toBackup(),
      overwrite: true,
    );
    db.setSetting(_lastRunKey, '${time.millisecondsSinceEpoch}');
  }

  /// Sichert, wenn ein Ordner gewählt ist und heute noch nicht gesichert
  /// wurde. Fehler bleiben still; der nächste Anlass versucht es wieder.
  static Future<void> runIfDue(AppDatabase db) async {
    if (db.setting(_folderUriKey) == null || !isDue(db, DateTime.now())) {
      return;
    }
    try {
      await run(db);
    } catch (_) {
      // Zum Beispiel wenn der Ordner gelöscht oder die Karte entfernt wurde.
    }
  }
}
