import '../data/database.dart';
import '../data/models.dart';

// ---------------------------------------------------------------------------
// Pulszonen
// ---------------------------------------------------------------------------

/// Angaben, aus denen sich der Maximalpuls ergibt.
class HeartProfile {
  const HeartProfile({this.birthYear, this.manualMaxHr});

  HeartProfile.load(AppDatabase db)
      : birthYear = int.tryParse(db.setting(_birthYearKey) ?? ''),
        manualMaxHr = int.tryParse(db.setting(_manualMaxKey) ?? '');

  static const _birthYearKey = 'profile.birthYear';
  static const _manualMaxKey = 'profile.maxHr';

  final int? birthYear;

  /// Selbst eingetragener Maximalpuls; hat Vorrang vor der Faustformel.
  final int? manualMaxHr;

  /// Faustformel: 220 minus Lebensalter.
  int? formulaMaxHr(DateTime now) =>
      birthYear == null ? null : 220 - (now.year - birthYear!);

  /// Der geltende Maximalpuls oder `null`, wenn weder Geburtsjahr noch
  /// eigener Wert hinterlegt ist.
  int? maxHr(DateTime now) => manualMaxHr ?? formulaMaxHr(now);

  void save(AppDatabase db) {
    db
      ..setSetting(_birthYearKey, birthYear?.toString())
      ..setSetting(_manualMaxKey, manualMaxHr?.toString());
  }
}

/// Die fünf Pulszonen als Anteil des Maximalpulses.
enum HeartZone {
  z1('Zone 1', 'sehr leicht', 0),
  z2('Zone 2', 'leicht', 0.6),
  z3('Zone 3', 'mittel', 0.7),
  z4('Zone 4', 'hart', 0.8),
  z5('Zone 5', 'maximal', 0.9);

  const HeartZone(this.label, this.effort, this.from);

  final String label;
  final String effort;

  /// Untergrenze als Anteil des Maximalpulses. Zone 1 reicht bis ganz unten.
  final double from;

  /// Der Puls, ab dem diese Zone beginnt.
  int lowerBound(int maxHr) => (maxHr * from).round();

  /// Die vier Grenzen zwischen den Zonen, aufsteigend.
  static List<int> thresholds(int maxHr) =>
      [for (final z in values.skip(1)) z.lowerBound(maxHr)];

  /// Bereich der Zone in Schlägen je Minute, z. B. „126–143".
  String range(int maxHr) {
    final next = index + 1 < values.length ? values[index + 1] : null;
    final low = index == 0 ? null : lowerBound(maxHr);
    final high = next == null ? null : next.lowerBound(maxHr) - 1;
    if (low == null) return 'bis $high';
    if (high == null) return 'ab $low';
    return '$low–$high';
  }
}

// ---------------------------------------------------------------------------
// Umfang je Woche und Monat
// ---------------------------------------------------------------------------

enum VolumePeriod { week, month }

/// Summen einer Sportart in einem Zeitraum.
class SportVolume {
  int count = 0;
  int seconds = 0;
  double meters = 0;

  void add(Workout w) {
    count++;
    seconds += w.durationS;
    meters += w.distanceM;
  }
}

/// Eine Woche oder ein Monat mit den Summen je Sportart.
class VolumeBucket {
  VolumeBucket(this.start);

  /// Montag der Woche bzw. Erster des Monats, jeweils 0 Uhr.
  final DateTime start;
  final Map<Sport, SportVolume> bySport = {};

  int get count => bySport.values.fold(0, (sum, v) => sum + v.count);
  int get seconds => bySport.values.fold(0, (sum, v) => sum + v.seconds);
  double get meters => bySport.values.fold(0, (sum, v) => sum + v.meters);
}

/// Der Beginn des Zeitraums, in dem [day] liegt.
DateTime periodStart(DateTime day, VolumePeriod period) =>
    period == VolumePeriod.month
        ? DateTime(day.year, day.month)
        : DateTime(day.year, day.month, day.day - (day.weekday - 1));

/// Die letzten [buckets] Zeiträume bis einschließlich des laufenden, ältester
/// zuerst, mit den Summen der [workouts] darin. Leere Zeiträume bleiben
/// erhalten, damit Lücken sichtbar sind.
List<VolumeBucket> buildVolume(
  List<Workout> workouts,
  VolumePeriod period, {
  required DateTime now,
  int buckets = 12,
}) {
  final current = periodStart(now, period);
  final result = [
    for (var i = buckets - 1; i >= 0; i--)
      VolumeBucket(period == VolumePeriod.month
          ? DateTime(current.year, current.month - i)
          : DateTime(current.year, current.month, current.day - 7 * i)),
  ];
  final byStart = {for (final b in result) b.start: b};
  for (final w in workouts) {
    byStart[periodStart(w.startedAt, period)]
        ?.bySport
        .putIfAbsent(w.sport, SportVolume.new)
        .add(w);
  }
  return result;
}

// ---------------------------------------------------------------------------
// Bestwerte
// ---------------------------------------------------------------------------

/// Eine Bestleistung, die je Training berechnet und gemerkt wird.
/// [id] steht in der Datenbank.
enum EffortKind {
  fastest500m('fastest_500', '500 m', meters: 500),
  fastest1km('fastest_1000', '1 km', meters: 1000),
  fastest5km('fastest_5000', '5 km', meters: 5000),
  fastest10km('fastest_10000', '10 km', meters: 10000),
  power1min('power_60', 'Leistung 1 min', windowS: 60),
  power5min('power_300', 'Leistung 5 min', windowS: 300),
  power20min('power_1200', 'Leistung 20 min', windowS: 1200);

  const EffortKind(this.id, this.label, {this.meters, this.windowS});

  final String id;
  final String label;

  /// Bei Bestzeiten die Strecke; kleiner ist besser.
  final double? meters;

  /// Bei Bestleistungen das Zeitfenster in Sekunden; größer ist besser.
  final int? windowS;

  bool get isTime => meters != null;

  static EffortKind? fromId(String id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Welche Bestwerte für eine Sportart sinnvoll sind.
  static List<EffortKind> forSport(Sport sport) => switch (sport) {
        Sport.running || Sport.treadmill => [fastest1km, fastest5km, fastest10km],
        Sport.skiErg => [
            fastest500m,
            fastest1km,
            fastest5km,
            power1min,
            power5min,
            power20min,
          ],
        Sport.indoorBike => [power1min, power5min, power20min],
        _ => const [],
      };
}

/// Die kürzeste Zeit in Sekunden, in der [meters] am Stück zurückgelegt
/// wurden, oder `null`, wenn das Training kürzer war.
///
/// [distance] ist die zurückgelegte Strecke am Ende jeder aktiven Sekunde.
int? fastestSeconds(List<double> distance, double meters) {
  // Vor der ersten Sekunde ist die Strecke 0.
  double at(int i) => i == 0 ? 0 : distance[i - 1];
  int? best;
  var from = 0;
  for (var to = 1; to <= distance.length; to++) {
    if (at(to) - at(from) < meters) continue;
    // Den Anfang so weit nachziehen, wie die Strecke noch reicht.
    while (at(to) - at(from + 1) >= meters) {
      from++;
    }
    final seconds = to - from;
    if (best == null || seconds < best) best = seconds;
  }
  return best;
}

/// Der höchste Durchschnitt über [window] aufeinanderfolgende Werte, oder
/// `null`, wenn es weniger Werte gibt.
double? bestAverage(List<int> values, int window) {
  if (values.length < window) return null;
  var sum = 0;
  for (var i = 0; i < window; i++) {
    sum += values[i];
  }
  var best = sum;
  for (var i = window; i < values.length; i++) {
    sum += values[i] - values[i - window];
    if (sum > best) best = sum;
  }
  return best / window;
}

/// Ein Bestwert mit dem Training, in dem er erzielt wurde.
class Record {
  const Record({
    required this.label,
    required this.value,
    required this.workoutId,
    required this.date,
  });

  final String label;

  /// Fertig formatiert, mit Einheit.
  final String value;
  final int workoutId;
  final DateTime date;
}
