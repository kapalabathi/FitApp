import '../data/database.dart';
import '../data/models.dart';
import '../gps/geo.dart';

/// Führt die Messwerte mehrerer Geräte zu einem Training zusammen und
/// schreibt jede aktive Sekunde in die Datenbank.
///
/// Kennt weder Bluetooth noch GPS-Empfänger: Messwerte kommen über [onData],
/// Standorte über [onPosition], die Zeit über [tick].
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

  /// Ungenauere Standorte werden verworfen.
  static const maxGpsAccuracyM = 30.0;

  /// Erst ab dieser Entfernung zum letzten gewerteten Standort zählt eine
  /// Bewegung als Strecke; darunter ist es meist Rauschen im Stand.
  static const _minGpsStepM = 3.0;

  /// Höhenänderungen unter dieser Schwelle sind Messrauschen und zählen
  /// nicht als Anstieg.
  static const _ascentThresholdM = 3.0;

  static const _gpsSourceId = 'gps';

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

  GpsFix? _lastFix;
  DateTime? _lastFixAt;
  GpsFix? _distanceAnchor;
  bool _gpsCountsDistance = false;
  double? _ascentAnchorM;
  double _ascentM = 0;

  final List<Lap> _laps = [];
  int _autoLapsDone = 0;
  double? _autoLapEveryM;

  bool get paused => _paused;
  int get elapsedS => _elapsedS;
  double get distanceM => _distanceM;
  int? get energyKcal => _machineCountsEnergy ? _energyKcal.round() : null;

  /// Summe der Anstiege; `null` ohne GPS.
  int? get ascentM => _gpsCountsDistance ? _ascentM.round() : null;

  List<Lap> get laps => List.unmodifiable(_laps);

  /// Genauigkeit des aktuellen Standorts in Metern; `null`, solange das GPS
  /// keinen brauchbaren Standort liefert.
  double? get gpsAccuracyM {
    final at = _lastFixAt;
    return at != null && _clock().difference(at) <= freshness
        ? _lastFix?.accuracyM
        : null;
  }

  /// Setzt nach je [meters] Metern von selbst eine Rundenmarke.
  void enableAutoLap(double meters) => _autoLapEveryM = meters;

  /// Meldet ein Gerät an. [dedicatedHeartRate] kennzeichnet Pulssensoren; ihr
  /// Puls hat Vorrang vor dem, den ein Fitnessgerät mitliefert.
  void addSource(String id, {required bool dedicatedHeartRate}) {
    _sources.add(_Source(id, dedicatedHeartRate));
  }

  void pause() => _paused = true;

  void resume() {
    _paused = false;
    // Der Weg während der Pause zählt nicht: Die Strecke setzt am nächsten
    // Standort neu an.
    _distanceAnchor = null;
    _ascentAnchorM = null;
  }

  /// Nimmt einen Standort entgegen. Zu ungenaue werden verworfen.
  void onPosition(GpsFix fix) {
    if (fix.accuracyM > maxGpsAccuracyM) return;
    final now = _clock();
    if (!_sources.any((s) => s.id == _gpsSourceId)) {
      _sources.add(_Source(_gpsSourceId, false));
    }
    final speed = fix.speedMps;
    if (speed != null && speed >= 0) {
      _sources
          .firstWhere((s) => s.id == _gpsSourceId)
          .values[Metric.speed] = _Reading(speed * 3.6, now);
    }
    _lastFix = fix;
    _lastFixAt = now;
    _gpsCountsDistance = true;
    if (_paused) return;

    final anchor = _distanceAnchor;
    if (anchor == null) {
      _distanceAnchor = fix;
    } else {
      final step = distanceMeters(
          anchor.latitude, anchor.longitude, fix.latitude, fix.longitude);
      if (step >= _minGpsStepM) {
        _distanceM += step;
        _distanceAnchor = fix;
      }
    }

    final altitude = fix.altitudeM;
    if (altitude != null) {
      final reference = _ascentAnchorM;
      if (reference == null) {
        _ascentAnchorM = altitude;
      } else if (altitude - reference >= _ascentThresholdM) {
        _ascentM += altitude - reference;
        _ascentAnchorM = altitude;
      } else if (reference - altitude >= _ascentThresholdM) {
        _ascentAnchorM = altitude;
      }
    }
  }

  /// Setzt von Hand eine Rundenmarke am aktuellen Stand. Gibt sie zurück,
  /// oder `null`, wenn seit der letzten Marke keine Sekunde vergangen ist.
  Lap? markLap() => _addLap(auto: false);

  Lap? _addLap({required bool auto}) {
    if (_finished || _elapsedS == 0) return null;
    if (_laps.isNotEmpty && _laps.last.t >= _elapsedS) return null;
    final lap = Lap(t: _elapsedS, distanceM: _distanceM, auto: auto);
    _laps.add(lap);
    db.addLap(workoutId, lap);
    return lap;
  }

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
  /// aktuellen Werte als Messpunkt. Gibt die Rundenmarke zurück, wenn dabei
  /// von selbst eine gesetzt wurde.
  Lap? tick() {
    if (_paused || _finished) return null;
    _elapsedS++;
    final speed = value(Metric.speed);
    if (!_machineCountsDistance && !_gpsCountsDistance && speed != null) {
      _distanceM += speed / 3.6;
    }
    final position = gpsAccuracyM == null ? null : _lastFix;
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
        latitude: position?.latitude,
        longitude: position?.longitude,
        altitudeM: position?.altitudeM,
      ),
    );
    final every = _autoLapEveryM;
    if (every != null && _distanceM ~/ every > _autoLapsDone) {
      // Bei einem Sprung über mehrere Marken wird nur eine gesetzt.
      _autoLapsDone = _distanceM ~/ every;
      return _addLap(auto: true);
    }
    return null;
  }

  /// Schließt das Training ab. Gibt `null` zurück, wenn es keine einzige
  /// aktive Sekunde hatte und deshalb verworfen wurde.
  Workout? finish() {
    if (_finished) return db.workout(workoutId);
    _finished = true;
    final kept = db.finishWorkout(workoutId,
        energyKcal: energyKcal, ascentM: ascentM);
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
