import '../data/models.dart';

/// Die Messgrößen, die sich über mehrere Trainings vergleichen lassen.
enum CompareMetric {
  heartRate('Puls', '/min'),
  pace('Pace', 'min/km', lowerIsBetter: true),
  speed('Tempo', 'km/h'),
  power('Leistung', 'W'),
  cadence('Frequenz', '/min');

  const CompareMetric(this.label, this.unit, {this.lowerIsBetter = false});

  final String label;
  final String unit;
  final bool lowerIsBetter;

  /// Langsamere Abschnitte haben keine sinnvolle Pace.
  static const _slowestPaceKmh = 2.0;

  double? of(Sample s) => switch (this) {
        heartRate => s.heartRate?.toDouble(),
        pace => (s.speedKmh ?? 0) < _slowestPaceKmh
            ? null
            : 1000 / (s.speedKmh! / 3.6),
        speed => s.speedKmh,
        power => s.power?.toDouble(),
        cadence => s.cadence,
      };
}

/// Worüber die Kurven nebeneinanderliegen.
enum CompareAxis {
  time('Zeit'),
  distance('Strecke');

  const CompareAxis(this.label);

  final String label;
}

/// Eine Kurve: je Schritt ein Wert, `null` für eine Lücke.
class CompareCurve {
  const CompareCurve(this.values, this.step);

  final List<double?> values;

  /// Abstand zweier Werte in Sekunden oder Metern.
  final double step;

  double get end => values.isEmpty ? 0 : values.length * step;

  double? at(double x) {
    final i = (x / step).floor();
    return i < 0 || i >= values.length ? null : values[i];
  }

  /// Das Mittel der vorhandenen Werte.
  double? get average {
    final present = values.whereType<double>();
    if (present.isEmpty) return null;
    return present.reduce((a, b) => a + b) / present.length;
  }

  bool get isEmpty => values.every((v) => v == null);
}

/// Mehr Punkte je Kurve sieht man auf dem Display nicht. Das Zusammenfassen
/// glättet zugleich das Zittern der Sekundenwerte.
const comparePoints = 400;

/// So grob wird die Strecke für den Vergleich aufgeteilt, in Metern.
const compareMetersStep = 25.0;

/// Baut die Kurve einer Messgröße aus den Messpunkten eines Trainings.
CompareCurve compareCurve(
  List<Sample> samples,
  CompareMetric metric,
  CompareAxis axis, {
  int maxPoints = comparePoints,
}) {
  final sums = <int, double>{};
  final counts = <int, int>{};
  var length = 0;
  final step = axis == CompareAxis.time ? 1.0 : compareMetersStep;
  for (final s in samples) {
    final int slot;
    if (axis == CompareAxis.time) {
      slot = s.t - 1;
    } else {
      final d = s.distanceM;
      if (d == null) continue;
      slot = d ~/ compareMetersStep;
    }
    if (slot < 0) continue;
    if (slot >= length) length = slot + 1;
    final value = metric.of(s);
    if (value == null) continue;
    sums.update(slot, (v) => v + value, ifAbsent: () => value);
    counts.update(slot, (n) => n + 1, ifAbsent: () => 1);
  }
  final group = length <= maxPoints ? 1 : (length / maxPoints).ceil();
  final values = <double?>[];
  for (var start = 0; start < length; start += group) {
    var sum = 0.0;
    var count = 0;
    for (var i = start; i < start + group && i < length; i++) {
      sum += sums[i] ?? 0;
      count += counts[i] ?? 0;
    }
    values.add(count == 0 ? null : sum / count);
  }
  return CompareCurve(values, step * group);
}

/// Woran zwei Trainings als dasselbe Workout gelten: gleiche Sportart und
/// gleicher Titel. Ein abgebrochener Durchgang gehört dazu.
String workoutGroupKey(Workout w) {
  final title = (w.title ?? '').replaceFirst(' (abgebrochen)', '').trim();
  return '${w.sport.id}|$title';
}

/// Alle Durchgänge desselben Workouts wie [workout], neueste zuerst.
List<Workout> sameWorkouts(Iterable<Workout> all, Workout workout) {
  final key = workoutGroupKey(workout);
  return [
    for (final w in all)
      if (workoutGroupKey(w) == key) w,
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
}
