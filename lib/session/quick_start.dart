import 'dart:convert';

import '../data/database.dart';
import '../data/models.dart';

/// Eine gemerkte Zusammenstellung, mit der sich ein Training mit einem Tipp
/// wieder starten lässt: Sportart mit Geräten und Intervall, oder ein
/// Trainingsprogramm.
class QuickStart {
  const QuickStart({
    required this.sport,
    this.deviceIds = const {},
    this.templateId,
    this.controlMachine = false,
    this.programId,
    this.pinned = false,
    this.usedAt = 0,
  });

  final Sport sport;
  final Set<String> deviceIds;

  /// Die Intervall-Vorlage, falls eine gewählt war.
  final int? templateId;
  final bool controlMachine;

  /// Gesetzt, wenn der Eintrag für ein Trainingsprogramm steht.
  final int? programId;

  /// Als Favorit markiert; bleibt oben stehen und wird nie verdrängt.
  final bool pinned;

  /// Zeitpunkt der letzten Nutzung in Millisekunden.
  final int usedAt;

  /// Zwei Einträge mit derselben Kennung meinen dasselbe Training.
  String get signature => programId != null
      ? 'program:$programId'
      : '${sport.id}|${templateId ?? ''}|${(deviceIds.toList()..sort()).join(',')}';

  QuickStart copyWith({bool? pinned, int? usedAt, bool? controlMachine}) =>
      QuickStart(
        sport: sport,
        deviceIds: deviceIds,
        templateId: templateId,
        controlMachine: controlMachine ?? this.controlMachine,
        programId: programId,
        pinned: pinned ?? this.pinned,
        usedAt: usedAt ?? this.usedAt,
      );

  Map<String, Object?> toJson() => {
        'sport': sport.id,
        'devices': deviceIds.toList(),
        'template': templateId,
        'control': controlMachine,
        'program': programId,
        'pinned': pinned,
        'usedAt': usedAt,
      };

  static QuickStart fromJson(Map<String, Object?> j) => QuickStart(
        sport: Sport.fromId(j['sport'] as String? ?? ''),
        deviceIds: {...(j['devices'] as List? ?? const []).cast<String>()},
        templateId: j['template'] as int?,
        controlMachine: j['control'] == true,
        programId: j['program'] as int?,
        pinned: j['pinned'] == true,
        usedAt: (j['usedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Die Liste der Schnellstart-Einträge in den Einstellungen.
abstract final class QuickStarts {
  static const _key = 'quickstart';

  /// So viele nicht als Favorit markierte Einträge bleiben erhalten.
  static const maxRecent = 4;

  /// Favoriten zuerst, danach die zuletzt genutzten.
  static List<QuickStart> load(AppDatabase db) {
    final stored = db.setting(_key);
    if (stored == null) return [];
    try {
      final entries = [
        for (final e in jsonDecode(stored) as List)
          QuickStart.fromJson((e as Map).cast<String, Object?>()),
      ];
      return _sorted(entries);
    } catch (_) {
      return [];
    }
  }

  static List<QuickStart> _sorted(List<QuickStart> entries) => entries
    ..sort((a, b) => a.pinned != b.pinned
        ? (a.pinned ? -1 : 1)
        : b.usedAt.compareTo(a.usedAt));

  static void _save(AppDatabase db, List<QuickStart> entries) {
    final sorted = _sorted(entries);
    final kept = [
      ...sorted.where((e) => e.pinned),
      ...sorted.where((e) => !e.pinned).take(maxRecent),
    ];
    db.setSetting(_key, jsonEncode(kept.map((e) => e.toJson()).toList()));
  }

  /// Merkt sich ein eben gestartetes Training. Gab es den Eintrag schon,
  /// rückt er nach vorn und behält seine Markierung als Favorit.
  static void remember(AppDatabase db, QuickStart started, {DateTime? now}) {
    final entries = load(db);
    final known =
        entries.where((e) => e.signature == started.signature).firstOrNull;
    entries.removeWhere((e) => e.signature == started.signature);
    entries.add(started.copyWith(
      pinned: known?.pinned ?? false,
      usedAt: (now ?? DateTime.now()).millisecondsSinceEpoch,
    ));
    _save(db, entries);
  }

  static void setPinned(AppDatabase db, QuickStart entry, bool pinned) {
    final entries = load(db);
    final index = entries.indexWhere((e) => e.signature == entry.signature);
    if (index < 0) return;
    entries[index] = entries[index].copyWith(pinned: pinned);
    _save(db, entries);
  }

  static void remove(AppDatabase db, QuickStart entry) {
    _save(
        db, load(db)..removeWhere((e) => e.signature == entry.signature));
  }
}
