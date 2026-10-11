import '../data/database.dart';
import '../data/models.dart';

/// Führt die Messwerte mehrerer Geräte zu einem Training zusammen und
/// schreibt jede aktive Sekunde in die Datenbank.
///
/// Kennt kein Bluetooth: Messwerte kommen über [onData], die Zeit über [tick].
class WorkoutRecorder {
  WorkoutRecorder({
    required this.db,
    required this.sport,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    startedAt = _clock();
    workoutId = db.startWorkout(sport, startedAt);
  }

  /// Älter darf ein Messwert nicht sein, um noch als aktuell zu gelten.
  static const freshness = Duration(seconds: 5);

  /// Größere Sprünge im Distanzzähler eines Geräts gelten als Neustart des
  /// Zählers und werden nicht als Strecke gewertet.
  static const _maxDistanceStepM = 100.0;
  static const _maxEnergyStepKcal = 50.0;

  final AppDatabase db;
  final Sport sport;
  final DateTime Function() _clock;

  late final DateTime startedAt;
  late final int workoutId;

  final List<_Source> _sources = [];

  /// Vom Nutzer bevorzugte Pulsquelle; ohne Angabe gilt die Reihenfolge der
  /// Geräte, eigene Pulssensoren zuerst.
  String? preferredHeartRateSource;

  bool _paused = false;
  bool _finished = false;
  int _elapsedS = 0;
  double _distanceM = 0;
  double _energyKcal = 0;
  bool _machineCountsDistance = false;
  bool _machineCountsEnergy = false;

  bool get paused => _paused;
  int get elapsedS => _elapsedS;
  double get distanceM => _distanceM;
  int? get energyKcal => _machineCountsEnergy ? _energyKcal.round() : null;

  /// Meldet ein Gerät an. [dedicatedHeartRate] kennzeichnet Pulssensoren; ihr
  /// Puls hat Vorrang vor dem, den ein Fitnessgerät mitliefert.
  void addSource(String id, {required bool dedicatedHeartRate}) {
    _sources.add(_Source(id, dedicatedHeartRate));
  }

  void pause() => _paused = true;
  void resume() => _paused = false;

  void onData(String sourceId, Map<Metric, double> values) {
    final source = _sources.firstWhere((s) => s.id == sourceId);
    final now = _clock();
    values.forEach((metric, value) {
      if (metric == Metric.distanceTotal) {
        final step = _counterStep(source, metric, value, _maxDistanceStepM);
        _machineCountsDistance = true;
        if (!_paused) _distanceM += step;
      } else if (metric == Metric.energyTotal) {
        final step = _counterStep(source, metric, value, _maxEnergyStepKcal);
        _machineCountsEnergy = true;
        if (!_paused) _energyKcal += step;
      }
      source.values[metric] = _Reading(value, now);
    });
  }

  /// Zuwachs eines Gerätezählers seit dem letzten Paket; 0 beim ersten Paket,
  /// bei Rückwärtssprüngen und bei unplausibel großen Sprüngen.
  double _counterStep(_Source source, Metric metric, double value, double max) {
    final last = source.values[metric]?.value;
    if (last == null) return 0;
    final step = value - last;
    return step > 0 && step <= max ? step : 0;
  }

  /// Der aktuelle Wert einer Messgröße oder `null`, wenn kein Gerät sie
  /// frisch liefert.
  double? value(Metric metric) {
    final now = _clock();
    for (final source in _ordered(metric)) {
      final reading = source.values[metric];
      if (reading != null && now.difference(reading.at) <= freshness) {
        return reading.value;
      }
    }
    return null;
  }

  /// Die Geräte, die gerade einen frischen Puls liefern.
  List<String> get heartRateSources {
    final now = _clock();
    return [
      for (final s in _sources)
        if (s.values[Metric.heartRate] case final r?
            when now.difference(r.at) <= freshness)
          s.id,
    ];
  }

  Iterable<_Source> _ordered(Metric metric) {
    if (metric != Metric.heartRate) return _sources;
    int rank(_Source s) => s.id == preferredHeartRateSource
        ? 0
        : s.dedicatedHeartRate
            ? 1
            : 2;
    // Stabile Sortierung von Hand, damit die Reihenfolge der Geräte bei
    // gleichem Rang erhalten bleibt.
    return [
      for (var r = 0; r <= 2; r++) ..._sources.where((s) => rank(s) == r),
    ];
  }

  /// Einmal je Sekunde aufzurufen. Schreibt außerhalb von Pausen die
  /// aktuellen Werte als Messpunkt.
  void tick() {
    if (_paused || _finished) return;
    _elapsedS++;
    final speed = value(Metric.speed);
    if (!_machineCountsDistance && speed != null) {
      _distanceM += speed / 3.6;
    }
    db.addSample(
      workoutId,
      Sample(
        t: _elapsedS,
        heartRate: value(Metric.heartRate)?.round(),
        speedKmh: speed,
        cadence: value(Metric.cadence),
        power: value(Metric.power)?.round(),
        distanceM: _distanceM,
        incline: value(Metric.incline),
        resistance: value(Metric.resistance),
      ),
    );
  }

  /// Schließt das Training ab. Gibt `null` zurück, wenn es keine einzige
  /// aktive Sekunde hatte und deshalb verworfen wurde.
  Workout? finish() {
    if (_finished) return db.workout(workoutId);
    _finished = true;
    final kept = db.finishWorkout(workoutId, energyKcal: energyKcal);
    return kept ? db.workout(workoutId) : null;
  }
}

class _Source {
  _Source(this.id, this.dedicatedHeartRate);

  final String id;
  final bool dedicatedHeartRate;
  final Map<Metric, _Reading> values = {};
}

class _Reading {
  const _Reading(this.value, this.at);

  final double value;
  final DateTime at;
}
