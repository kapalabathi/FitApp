import 'dart:math';

import 'rep_counter.dart';

/// Beruhigt das angezeigte Gerüst: Kleine Bewegungen werden stark geglättet,
/// große folgen schnell, und kurze Erkennungslücken überbrückt der letzte
/// Stand. Nur für die Anzeige; das Zählen arbeitet mit den Rohwerten.
class PoseSmoother {
  /// Ab dieser Sicherheit erscheint ein Gelenk.
  static const showAt = 0.5;

  /// Ein sichtbares Gelenk bleibt bis zu dieser Sicherheit stehen, damit es
  /// um die Schwelle herum nicht flackert.
  static const keepAt = 0.3;

  /// So lange bleibt ein Gelenk ohne brauchbaren Messwert stehen.
  static const hold = Duration(milliseconds: 700);

  /// Glättung bei Stillstand: Anteil des neuen Werts.
  static const minBlend = 0.2;

  /// Ab dieser Bewegung, bezogen auf die Bildgröße, folgt das Gerüst sofort.
  static const fastMove = 0.06;

  final Map<Joint, _Tracked> _joints = {};

  /// Vergisst alles, etwa beim Wechsel der Kamera.
  void reset() => _joints.clear();

  /// Nimmt eine erkannte Haltung auf und gibt die anzuzeigende zurück.
  /// [scale] ist die Bildgröße in denselben Einheiten wie die Punkte.
  BodyPose update(BodyPose raw, Duration at, double scale) {
    for (final joint in Joint.values) {
      final point = raw[joint];
      final known = _joints[joint];
      final likelihood = point?.likelihood ?? 0;
      final usable = known == null ? likelihood >= showAt : likelihood >= keepAt;
      if (point != null && usable) {
        _joints[joint] = known == null
            ? _Tracked(point.x, point.y, at)
            : known.moved(point, at, scale);
      } else if (known != null && at - known.seen > hold) {
        _joints.remove(joint);
      }
    }
    return {
      for (final e in _joints.entries)
        e.key: PosePoint(e.value.x, e.value.y, 1),
    };
  }
}

class _Tracked {
  const _Tracked(this.x, this.y, this.seen);

  final double x;
  final double y;
  final Duration seen;

  _Tracked moved(PosePoint p, Duration at, double scale) {
    final dx = p.x - x;
    final dy = p.y - y;
    final move = scale <= 0 ? 1.0 : sqrt(dx * dx + dy * dy) / scale;
    final share = PoseSmoother.minBlend +
        (1 - PoseSmoother.minBlend) * (move / PoseSmoother.fastMove).clamp(0, 1);
    return _Tracked(x + dx * share, y + dy * share, at);
  }
}
