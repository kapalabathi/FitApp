import '../data/models.dart';

/// Entscheidet aus der Geschwindigkeit, wann ein Training von selbst
/// pausiert und wieder weiterläuft.
///
/// Kennt weder Uhr noch Geräte: [update] wird einmal je Sekunde mit der
/// aktuellen Geschwindigkeit aufgerufen.
class AutoPause {
  AutoPause({
    required this.thresholdKmh,
    required this.pauseAfterS,
    this.resumeAfterS = 2,
  });

  /// Die Regeln für eine Sportart, oder `null`, wenn sie keine
  /// Geschwindigkeit kennt, an der sich Stillstand ablesen ließe.
  static AutoPause? forSport(Sport sport) => switch (sport) {
        // Geräte melden den Stillstand eindeutig.
        Sport.treadmill ||
        Sport.indoorBike ||
        Sport.skiErg =>
          AutoPause(thresholdKmh: 0.5, pauseAfterS: 3),
        // Draußen schwankt das GPS im Stand; deshalb höhere Schwelle und
        // längeres Abwarten, beim Gehen mehr als beim Laufen.
        Sport.running => AutoPause(thresholdKmh: 2, pauseAfterS: 6),
        Sport.hiking => AutoPause(thresholdKmh: 1, pauseAfterS: 10),
        _ => null,
      };

  /// Darunter gilt die Geschwindigkeit als Stillstand.
  final double thresholdKmh;

  /// So viele Sekunden Stillstand am Stück führen zur Pause.
  final int pauseAfterS;

  /// So viele Sekunden Bewegung am Stück beenden die Pause.
  final int resumeAfterS;

  bool _paused = false;
  bool _armed = true;
  int _still = 0;
  int _moving = 0;

  bool get paused => _paused;

  /// Meldet die Geschwindigkeit einer Sekunde; `null`, wenn gerade keine
  /// vorliegt. Gibt `true` zurück, wenn sich dadurch [paused] geändert hat.
  bool update(double? speedKmh) {
    // Ohne Messwert ist unbekannt, ob Stillstand herrscht; es bleibt, wie es
    // ist. Ein Verbindungsabbruch soll kein Training anhalten.
    if (speedKmh == null) {
      _still = 0;
      _moving = 0;
      return false;
    }
    if (speedKmh < thresholdKmh) {
      _moving = 0;
      _still++;
      if (_armed && !_paused && _still >= pauseAfterS) {
        _paused = true;
        return true;
      }
    } else {
      _still = 0;
      _moving++;
      _armed = true;
      if (_paused && _moving >= resumeAfterS) {
        _paused = false;
        return true;
      }
    }
    return false;
  }

  /// Der Nutzer hat die automatische Pause von Hand beendet. Sie greift erst
  /// wieder, nachdem er sich einmal bewegt hat; sonst würde sie sofort
  /// erneut pausieren.
  void overrideByUser() {
    _paused = false;
    _armed = false;
    _still = 0;
    _moving = 0;
  }

  /// Der Nutzer pausiert selbst; die Zählung beginnt danach von vorn.
  void reset() {
    _paused = false;
    _still = 0;
    _moving = 0;
  }
}
