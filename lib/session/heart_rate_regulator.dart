import '../ble/ftms_control.dart';

/// Was der Nutzer für das pulsgesteuerte Training festlegt.
class HeartRateTarget {
  const HeartRateTarget({required this.bpm, required this.maxValue});

  /// Der Puls, den das Training halten soll.
  final int bpm;

  /// Höchstens so schnell oder schwer stellt die Regelung das Gerät.
  final double maxValue;
}

/// Hält den Puls bei einem Zielwert, indem sie das Gerät in kleinen Schritten
/// nachstellt (I-032).
///
/// Der Puls folgt der Belastung erst nach einer halben Minute und mehr. Die
/// Regelung ist deshalb bewusst träge: Sie mittelt den Puls, wartet nach jeder
/// Änderung ab und ändert immer nur um einen Schritt. Nur wenn der Puls
/// deutlich zu hoch ist, nimmt sie schneller zurück.
///
/// Kennt weder Uhr noch Gerät: [update] wird je aktiver Sekunde aufgerufen.
class HeartRateRegulator {
  HeartRateRegulator({
    required this.targetBpm,
    required this.step,
    required this.min,
    required this.max,
  });

  /// In dieser Zeit steigt der Puls von selbst; erst danach wird gesteigert.
  /// Zurückgenommen wird auch vorher.
  static const warmUpS = 120;

  /// So lange wartet die Regelung nach einer Änderung auf deren Wirkung.
  static const settleS = 45;

  /// Wartezeit, wenn der Puls deutlich über dem Ziel liegt.
  static const urgentSettleS = 15;

  /// Innerhalb dieser Abweichung bleibt alles, wie es ist.
  static const toleranceBpm = 3;

  /// Ab dieser Abweichung nach oben gilt der Puls als deutlich zu hoch.
  static const urgentBpm = 10;

  /// Über so viele Sekunden wird der Puls gemittelt.
  static const averageS = 10;

  final int targetBpm;
  final double step;
  final double min;
  final double max;

  final List<double> _recent = [];
  int _active = 0;
  int _sinceChange = settleS;

  /// Ob gerade ein Messwert fehlt und die Regelung deshalb nichts tut.
  bool holding = false;

  /// Meldet eine aktive Sekunde mit dem frischen Puls und dem aktuellen Wert
  /// des Geräts. Gibt den neuen Zielwert zurück, wenn er sich ändern soll.
  double? update(double? heartRate, double? current) {
    _active++;
    _sinceChange++;
    holding = heartRate == null || current == null;
    if (heartRate == null || current == null) {
      // Nach einer Lücke gilt nur, was danach gemessen wurde.
      _recent.clear();
      return null;
    }
    // Ein stehendes Gerät wird nie von der Regelung gestartet.
    if (current < min) return null;

    _recent.add(heartRate);
    if (_recent.length > averageS) _recent.removeAt(0);
    if (_recent.length < averageS) return null;

    final average = _recent.reduce((a, b) => a + b) / _recent.length;
    final error = average - targetBpm;
    if (error.abs() <= toleranceBpm) return null;
    final tooHigh = error > 0;
    if (!tooHigh && _active < warmUpS) return null;
    final wait = error >= urgentBpm ? urgentSettleS : settleS;
    if (_sinceChange < wait) return null;

    final next = steppedTarget(current, tooHigh ? -1 : 1,
        step: step, min: min, max: max);
    if (next == current) return null;
    _sinceChange = 0;
    return next;
  }
}
