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
    this.kcalPerMinute,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    startedAt = _clock();
    workoutId = db.startWorkout(sport, startedAt);
  }

  /// Schätzt den Energieverbrauch je Minute aus dem Puls. Wird nur genutzt,
  /// solange kein Gerät den Verbrauch selbst liefert.
  final double? Function(int heartRate)? kcalPerMinute;

  /// Älter darf ein Messwert nicht sein, um noch als aktuell zu gelten.
  static const freshness = Duration(seconds: 5);

  /// Größere Sprünge im Distanzzähler eines Geräts gelten als Neustart des
  /// Zählers und werden nicht als Strecke gewertet.
  static const _maxDistanceStepM = 100.0;
  static const _maxEnergyStepKcal = 50.0;

  /// Ungenauere Standorte werden verworfen.
  static const maxGpsAccuracyM = 25.0;

  /// Erst ab dieser Entfernung zum letzten gewerteten Standort zählt eine
  /// Bewegung als Strecke; darunter ist es meist Rauschen im Stand. Bei
  /// ungenauem Standort wächst die Schwelle mit der Ungenauigkeit.
  static const _minGpsStepM = 3.0;
  static const _gpsStepPerAccuracy = 0.5;

  /// Ein Standort, der nur mit mehr als diesem Vielfachen der für die
  /// Sportart plausiblen Geschwindigkeit erreichbar wäre, ist ein Sprung
  /// des GPS und wird verworfen.
  static const _jumpFactor = 1.5;

  /// Geschwindigkeiten mit größerem geschätzten Fehler werden nicht gewertet.
  static const _maxSpeedErrorMps = 1.5;

  /// Die angezeigte Geschwindigkeit ist der Median so vieler Messungen;
  /// einzelne Ausreißer verschwinden darin.
  static const _speedWindow = 7;

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
  double _estimatedKcal = 0;
  bool _hasEstimate = false;

  // Manche Geräte zählen die Strecke nur grob, das Domyos-Laufband etwa in
  // Schritten von 10 m. Zwischen zwei Zählerschritten schreibt die App die
  // Strecke deshalb aus der Geschwindigkeit fort; der Zähler bleibt das
  // Maß, an dem sie sich bei jedem Schritt wieder ausrichtet.
  double _counterDistanceM = 0;
  double _sinceCounterStepM = 0;
  double? _counterResolutionM;

  GpsFix? _lastFix;
  DateTime? _lastFixAt;
  GpsFix? _distanceAnchor;
  final List<double> _gpsSpeeds = [];
  bool _gpsCountsDistance = false;
  double? _ascentAnchorM;
  double _ascentM = 0;

  final List<Lap> _laps = [];
  int _autoLapsDone = 0;
  double? _autoLapEveryM;

  bool get paused => _paused;
  int get elapsedS => _elapsedS;
  double get distanceM => _distanceM;
  /// Der Energieverbrauch vom Gerät; liefert es keinen, die Schätzung aus
  /// dem Puls; `null`, wenn es beides nicht gibt.
  int? get energyKcal => _machineCountsEnergy
      ? _energyKcal.round()
      : _hasEstimate
          ? _estimatedKcal.round()
          : null;

  /// Ob [energyKcal] geschätzt statt gemessen ist.
  bool get energyEstimated => !_machineCountsEnergy && _hasEstimate;

  /// Puls und Geschwindigkeit jeder aktiven Sekunde seit Beginn, für die
  /// Kurve während des Trainings. `null` steht für eine Sekunde ohne Wert.
  final List<double?> heartRateHistory = [];
  final List<double?> speedHistory = [];

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
    _gpsSpeeds.clear();
  }

  /// Nimmt einen Standort entgegen. Zu ungenaue und unmöglich weit
  /// entfernte werden verworfen.
  void onPosition(GpsFix fix) {
    if (fix.accuracyM > maxGpsAccuracyM) return;
    final now = _clock();
    final previous = _lastFix;
    final previousAt = _lastFixAt;
    if (previous != null && previousAt != null) {
      final seconds =
          (now.difference(previousAt).inMilliseconds / 1000).clamp(1.0, 1e9);
      final jump = distanceMeters(previous.latitude, previous.longitude,
          fix.latitude, fix.longitude);
      if (jump / seconds > sport.maxPlausibleSpeedMps * _jumpFactor) return;
    }
    if (!_sources.any((s) => s.id == _gpsSourceId)) {
      _sources.add(_Source(_gpsSourceId, false));
    }
    final speed = fix.speedMps;
    final speedError = fix.speedAccuracyMps;
    if (speed != null &&
        speed >= 0 &&
        speed <= sport.maxPlausibleSpeedMps &&
        (speedError == null || speedError <= _maxSpeedErrorMps)) {
      _gpsSpeeds.add(speed);
      if (_gpsSpeeds.length > _speedWindow) _gpsSpeeds.removeAt(0);
      final sorted = [..._gpsSpeeds]..sort();
      _sources
          .firstWhere((s) => s.id == _gpsSourceId)
          .values[Metric.speed] =
          _Reading(sorted[sorted.length ~/ 2] * 3.6, now);
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
      final threshold = fix.accuracyM * _gpsStepPerAccuracy;
      if (step >= (threshold > _minGpsStepM ? threshold : _minGpsStepM)) {
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
        if (!_paused && step > 0) {
          _counterDistanceM += step;
          final rest = _sinceCounterStepM - step;
          _sinceCounterStepM = rest > 0 ? rest : 0;
          final finest = _counterResolutionM;
          if (finest == null || step < finest) _counterResolutionM = step;
          _alignDistanceToCounter();
        }
      } else if (metric == Metric.energyTotal) {
        final step = _counterStep(source, metric, value, _maxEnergyStepKcal);
        _machineCountsEnergy = true;
        if (!_paused) _energyKcal += step;
      }
      source.values[metric] = _Reading(value, now);
    });
  }

  /// Die Strecke ist der Zählerstand plus das seit dem letzten
  /// Zählerschritt Zurückgelegte, höchstens aber einen Zählerschritt mehr.
  /// Sie läuft nie rückwärts.
  void _alignDistanceToCounter() {
    final finest = _counterResolutionM;
    final ahead = finest != null && _sinceCounterStepM > finest
        ? finest
        : _sinceCounterStepM;
    final estimate = _counterDistanceM + ahead;
    if (estimate > _distanceM) _distanceM = estimate;
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
    if (!_gpsCountsDistance && speed != null) {
      if (_machineCountsDistance) {
        _sinceCounterStepM += speed / 3.6;
        _alignDistanceToCounter();
      } else {
        _distanceM += speed / 3.6;
      }
    }
    final position = gpsAccuracyM == null ? null : _lastFix;
    final heartRate = value(Metric.heartRate);
    heartRateHistory.add(heartRate);
    speedHistory.add(speed);
    final perMinute =
        heartRate == null ? null : kcalPerMinute?.call(heartRate.round());
    if (perMinute != null) {
      _estimatedKcal += perMinute / 60;
      _hasEstimate = true;
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
    // Eine Schätzung berechnet die Datenbank selbst aus den Messpunkten;
    // hier geht nur ein vom Gerät gemessener Wert mit.
    final kept = db.finishWorkout(workoutId,
        energyKcal: _machineCountsEnergy ? _energyKcal.round() : null,
        ascentM: ascentM);
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
