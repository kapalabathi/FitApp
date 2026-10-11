import 'dart:convert';

import '../data/models.dart';

/// Die vier Bereiche der Übungsbibliothek. [id] steht in der Datenbank.
enum ExerciseCategory {
  yoga('yoga', 'Yoga', Sport.yoga),
  crossfit('crossfit', 'Crossfit', Sport.crossfit),
  calisthenics('calisthenics', 'Calisthenics', Sport.calisthenics),
  stretching('stretching', 'Dehnen', Sport.stretching);

  const ExerciseCategory(this.id, this.label, this.sport);

  final String id;
  final String label;

  /// Als diese Sportart wird ein absolviertes Programm gespeichert.
  final Sport sport;

  static ExerciseCategory fromId(String? id) =>
      values.firstWhere((c) => c.id == id, orElse: () => yoga);
}

/// Die Körperbereiche, die eine Übung trainiert oder dehnt. [id] steht in
/// der Datenbank.
enum BodyArea {
  neck('nacken', 'Nacken'),
  shoulders('schultern', 'Schultern'),
  arms('arme', 'Arme'),
  chest('brust', 'Brust'),
  back('ruecken', 'Rücken'),
  core('rumpf', 'Bauch und Rumpf'),
  hips('huefte', 'Hüfte'),
  glutes('gesaess', 'Gesäß'),
  legs('beine', 'Beine'),
  calves('waden', 'Waden und Füße'),
  fullBody('ganzkoerper', 'Ganzkörper');

  const BodyArea(this.id, this.label);

  final String id;
  final String label;

  /// Liest die in der Datenbank mit Komma getrennt abgelegten Bereiche.
  static List<BodyArea> parse(String? stored) => [
        for (final id in (stored ?? '').split(','))
          for (final area in values)
            if (area.id == id) area,
      ];

  static String store(Iterable<BodyArea> areas) =>
      areas.map((a) => a.id).join(',');
}

/// Eine mitgelieferte Übung, wie sie beim ersten Start in die Datenbank kommt.
class BuiltinExercise {
  const BuiltinExercise({
    required this.key,
    required this.category,
    required this.name,
    required this.description,
    required this.areas,
    required this.timed,
    required this.batch,
  });

  /// Dateiname der Grafik ohne Endung; zugleich Grundlage der Kennung.
  final String key;
  final ExerciseCategory category;
  final String name;
  final String description;

  final List<BodyArea> areas;

  /// Wird üblicherweise auf Zeit ausgeführt statt mit Wiederholungen.
  final bool timed;

  /// Mit welcher Lieferung die Übung kam: 1 für die ersten 80, 2 für die
  /// Erweiterung ohne Geräte. Bestehende Installationen bekommen spätere
  /// Lieferungen nachträglich.
  final int batch;

  String get uuid => 'builtin-$key';
}

/// Eine Übung der Bibliothek, mitgeliefert oder selbst angelegt.
class Exercise {
  const Exercise({
    this.id,
    required this.uuid,
    required this.category,
    required this.name,
    this.description = '',
    this.builtinKey,
    this.imagePath,
    this.timed = true,
    this.areas = const [],
  });

  /// `null`, solange die Übung noch nicht gespeichert ist.
  final int? id;

  /// Geräteübergreifend eindeutig; Programme verweisen darauf.
  final String uuid;
  final ExerciseCategory category;
  final String name;
  final String description;

  /// Gesetzt bei mitgelieferten Übungen; führt zur mitgelieferten Grafik.
  final String? builtinKey;

  /// Pfad eines selbst hinterlegten Bildes; hat Vorrang vor der Grafik.
  final String? imagePath;
  final bool timed;

  /// Die Körperbereiche, die die Übung trainiert oder dehnt.
  final List<BodyArea> areas;

  String? get imageAsset =>
      builtinKey == null ? null : 'assets/exercises/$builtinKey.webp';

  Exercise copyWith({
    ExerciseCategory? category,
    String? name,
    String? description,
    String? imagePath,
    bool clearImage = false,
    bool? timed,
    List<BodyArea>? areas,
  }) =>
      Exercise(
        id: id,
        uuid: uuid,
        category: category ?? this.category,
        name: name ?? this.name,
        description: description ?? this.description,
        builtinKey: builtinKey,
        imagePath: clearImage ? null : imagePath ?? this.imagePath,
        timed: timed ?? this.timed,
        areas: areas ?? this.areas,
      );
}

/// Eine Übung innerhalb eines Programms.
class ProgramItem {
  const ProgramItem({
    required this.exerciseUuid,
    required this.timed,
    required this.amount,
    this.restS = 0,
  });

  final String exerciseUuid;

  /// `true`: [amount] sind Sekunden. `false`: [amount] sind Wiederholungen.
  final bool timed;
  final int amount;

  /// Pause nach der Übung in Sekunden.
  final int restS;

  String get amountLabel => timed ? '$amount s' : '$amount ×';

  ProgramItem copyWith({bool? timed, int? amount, int? restS}) => ProgramItem(
        exerciseUuid: exerciseUuid,
        timed: timed ?? this.timed,
        amount: amount ?? this.amount,
        restS: restS ?? this.restS,
      );

  Map<String, Object?> toJson() => {
        'exercise': exerciseUuid,
        'timed': timed,
        'amount': amount,
        'rest': restS,
      };

  static ProgramItem fromJson(Map<String, Object?> j) => ProgramItem(
        exerciseUuid: j['exercise'] as String? ?? '',
        timed: j['timed'] as bool? ?? true,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        restS: (j['rest'] as num?)?.toInt() ?? 0,
      );
}

/// Ein Trainingsprogramm: Übungen in fester Reihenfolge, [rounds]-mal.
class Program {
  const Program({
    this.id,
    required this.name,
    required this.category,
    this.rounds = 1,
    required this.items,
  });

  /// `null`, solange das Programm noch nicht gespeichert ist.
  final int? id;
  final String name;
  final ExerciseCategory category;
  final int rounds;
  final List<ProgramItem> items;

  /// Dauer ohne die Übungen mit Wiederholungen, deren Zeit offen ist.
  int get timedSeconds =>
      rounds *
      items.fold(0, (sum, i) => sum + (i.timed ? i.amount : 0) + i.restS);

  bool get hasRepetitions => items.any((i) => !i.timed);

  Program copyWith({
    String? name,
    ExerciseCategory? category,
    int? rounds,
    List<ProgramItem>? items,
  }) =>
      Program(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        rounds: rounds ?? this.rounds,
        items: items ?? this.items,
      );

  String itemsJson() => jsonEncode(items.map((i) => i.toJson()).toList());

  static List<ProgramItem> itemsFromJson(String json) => [
        for (final i in jsonDecode(json) as List)
          ProgramItem.fromJson((i as Map).cast<String, Object?>()),
      ];
}
