import 'dart:convert';

/// Welche Größe ein Intervall vorgibt.
enum TargetKind {
  none('none', 'Kein Zielwert', ''),
  speed('speed', 'Geschwindigkeit', 'km/h'),
  resistance('resistance', 'Widerstand', 'Stufe'),
  power('power', 'Leistung', 'W');

  const TargetKind(this.id, this.label, this.unit);

  final String id;
  final String label;
  final String unit;

  static TargetKind fromId(String? id) =>
      values.firstWhere((k) => k.id == id, orElse: () => none);

  /// Zielwert mit Einheit, z. B. „12 km/h" oder „Stufe 8".
  String format(double value) {
    final number = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1).replaceAll('.', ',');
    return switch (this) {
      none => '',
      resistance => 'Stufe $number',
      _ => '$number $unit',
    };
  }
}

/// Ein Abschnitt: Bezeichnung, Dauer und optional ein Zielwert.
class IntervalStep {
  const IntervalStep({required this.label, required this.durationS, this.target});

  final String label;
  final int durationS;
  final double? target;

  IntervalStep copyWith({String? label, int? durationS, double? target}) =>
      IntervalStep(
        label: label ?? this.label,
        durationS: durationS ?? this.durationS,
        target: target ?? this.target,
      );

  Map<String, Object?> toJson() =>
      {'label': label, 'duration': durationS, 'target': target};

  static IntervalStep fromJson(Map<String, Object?> j) => IntervalStep(
        label: j['label'] as String? ?? '',
        durationS: (j['duration'] as num?)?.toInt() ?? 0,
        target: (j['target'] as num?)?.toDouble(),
      );
}

/// Eine Gruppe von Abschnitten, die [repeat]-mal hintereinander läuft.
class IntervalBlock {
  const IntervalBlock({this.repeat = 1, required this.steps});

  final int repeat;
  final List<IntervalStep> steps;

  int get totalSeconds =>
      repeat * steps.fold(0, (sum, s) => sum + s.durationS);

  Map<String, Object?> toJson() =>
      {'repeat': repeat, 'steps': steps.map((s) => s.toJson()).toList()};

  static IntervalBlock fromJson(Map<String, Object?> j) => IntervalBlock(
        repeat: (j['repeat'] as num?)?.toInt() ?? 1,
        steps: [
          for (final s in j['steps'] as List? ?? const [])
            IntervalStep.fromJson((s as Map).cast<String, Object?>()),
        ],
      );
}

/// Ein Abschnitt in der abgerollten Reihenfolge, wie der Timer ihn abspielt.
class PlannedStep {
  const PlannedStep({
    required this.label,
    required this.durationS,
    this.target,
    this.round,
    this.rounds,
  });

  final String label;
  final int durationS;
  final double? target;

  /// Nummer und Anzahl der Wiederholungen, wenn die Gruppe mehrfach läuft.
  final int? round;
  final int? rounds;
}

/// Eine gespeicherte Intervall-Vorlage.
class IntervalTemplate {
  const IntervalTemplate({
    this.id,
    required this.name,
    this.targetKind = TargetKind.none,
    required this.blocks,
  });

  /// `null`, solange die Vorlage noch nicht gespeichert ist.
  final int? id;
  final String name;
  final TargetKind targetKind;
  final List<IntervalBlock> blocks;

  int get totalSeconds => blocks.fold(0, (sum, b) => sum + b.totalSeconds);

  IntervalTemplate copyWith({
    int? id,
    String? name,
    TargetKind? targetKind,
    List<IntervalBlock>? blocks,
  }) =>
      IntervalTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        targetKind: targetKind ?? this.targetKind,
        blocks: blocks ?? this.blocks,
      );

  /// Rollt Gruppen und Wiederholungen zu einer einfachen Abfolge aus.
  /// Abschnitte ohne Dauer entfallen.
  List<PlannedStep> flatten() => [
        for (final block in blocks)
          for (var r = 1; r <= block.repeat; r++)
            for (final step in block.steps)
              if (step.durationS > 0)
                PlannedStep(
                  label: step.label,
                  durationS: step.durationS,
                  target: targetKind == TargetKind.none ? null : step.target,
                  round: block.repeat > 1 ? r : null,
                  rounds: block.repeat > 1 ? block.repeat : null,
                ),
      ];

  String blocksJson() => jsonEncode(blocks.map((b) => b.toJson()).toList());

  static List<IntervalBlock> blocksFromJson(String json) => [
        for (final b in jsonDecode(json) as List)
          IntervalBlock.fromJson((b as Map).cast<String, Object?>()),
      ];
}
