import 'dart:math';

/// Die Gelenke, die das Zählen braucht.
enum Joint {
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

/// Ein erkanntes Gelenk im Kamerabild.
class PosePoint {
  const PosePoint(this.x, this.y, this.likelihood);

  final double x;
  final double y;

  /// Wie sicher die Erkennung ist, 0 bis 1.
  final double likelihood;
}

typedef BodyPose = Map<Joint, PosePoint>;

/// Woran sich eine Übung messen lässt.
enum _Signal { elbow, knee, torso }

/// Die Übungen, die die Kamera zählt. Jede ist ein Winkel, der zwischen einem
/// hohen und einem tiefen Wert pendelt; eine Wiederholung ist der Weg von
/// hoch über tief zurück nach hoch.
enum RepKind {
  squat(_Signal.knee, low: 110, high: 155, hint: 'Von der Seite oder schräg'),
  pushUp(_Signal.elbow, low: 105, high: 150, hint: 'Genau von der Seite'),
  pikePushUp(_Signal.elbow, low: 115, high: 150, hint: 'Genau von der Seite'),
  benchDip(_Signal.elbow, low: 115, high: 150, hint: 'Genau von der Seite'),
  pullUp(_Signal.elbow, low: 90, high: 145, hint: 'Von vorn oder hinten'),
  burpee(_Signal.torso, low: 125, high: 155, hint: 'Genau von der Seite'),

  /// Beginnt liegend, also unten; die erste Wiederholung zählt beim
  /// Aufrichten.
  sitUp(_Signal.torso,
      low: 120, high: 150, hint: 'Genau von der Seite', startsLow: true);

  const RepKind(this._signal,
      {required this.low,
      required this.high,
      required this.hint,
      this.startsLow = false});

  /// Die Ausgangshaltung ist unten statt oben.
  final bool startsLow;

  final _Signal _signal;

  /// Unter diesem Winkel gilt die Bewegung als unten angekommen.
  final double low;

  /// Über diesem Winkel gilt sie als wieder oben.
  final double high;

  /// Wo die Kamera am besten steht.
  final String hint;
}

/// Zählt die Wiederholungen einer Übung aus den erkannten Haltungen.
///
/// Kennt weder Kamera noch Uhr: [add] bekommt jede Haltung mit ihrem Zeitpunkt.
class RepCounter {
  RepCounter(this.kind) : _seenHigh = kind.startsLow;

  /// Unsicherer erkannte Gelenke werden nicht verwendet.
  static const minLikelihood = 0.5;

  /// So lange gilt eine Person nach dem letzten sicheren Bild noch als
  /// erkannt; einzelne Aussetzer lassen den Hinweis nicht flackern.
  static const trackingGrace = Duration(seconds: 1);

  /// Geglättet wird über so viele Bilder, damit einzelne Ausreißer nichts
  /// zählen.
  static const smoothing = 3;

  /// Schneller geht keine Wiederholung; so zählt ein Zittern um die Schwelle
  /// nicht doppelt.
  static const minGap = Duration(milliseconds: 400);

  final RepKind kind;
  final List<double> _recent = [];
  bool _seenHigh;
  bool _wentLow = false;
  Duration? _lastRep;
  Duration? _lastSeen;

  int count = 0;

  /// Ob die nötigen Gelenke gerade sicher erkannt werden.
  bool tracking = false;

  /// Der geglättete Winkel in Grad, zur Anzeige und Prüfung.
  double? angle;

  /// Wertet eine Haltung aus. Gibt zurück, ob dabei eine Wiederholung
  /// vollendet wurde.
  bool add(BodyPose pose, Duration at) {
    final raw = _measure(pose);
    if (raw == null) {
      final seen = _lastSeen;
      tracking = seen != null && at - seen <= trackingGrace;
      return false;
    }
    tracking = true;
    _lastSeen = at;
    _recent.add(raw);
    if (_recent.length > smoothing) _recent.removeAt(0);
    final sorted = [..._recent]..sort();
    final value = sorted[sorted.length ~/ 2];
    angle = value;

    if (value >= kind.high) {
      final completed = _seenHigh && _wentLow;
      _seenHigh = true;
      _wentLow = false;
      final last = _lastRep;
      if (completed && (last == null || at - last >= minGap)) {
        _lastRep = at;
        count++;
        return true;
      }
    } else if (value <= kind.low && _seenHigh) {
      _wentLow = true;
    }
    return false;
  }

  double? _measure(BodyPose pose) => switch (kind._signal) {
        _Signal.elbow => _sideAngle(
            pose,
            (Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist),
            (Joint.rightShoulder, Joint.rightElbow, Joint.rightWrist),
          ),
        _Signal.knee => _sideAngle(
            pose,
            (Joint.leftHip, Joint.leftKnee, Joint.leftAnkle),
            (Joint.rightHip, Joint.rightKnee, Joint.rightAnkle),
          ),
        _Signal.torso => _torsoAngle(pose),
      };

  /// Der Winkel auf der besser sichtbaren Körperseite.
  double? _sideAngle(BodyPose pose, (Joint, Joint, Joint) left,
      (Joint, Joint, Joint) right) {
    double score((Joint, Joint, Joint) s) => [
          pose[s.$1]?.likelihood ?? 0,
          pose[s.$2]?.likelihood ?? 0,
          pose[s.$3]?.likelihood ?? 0,
        ].reduce(min);
    final side = score(left) >= score(right) ? left : right;
    if (score(side) < minLikelihood) return null;
    return angleAt(pose[side.$1]!, pose[side.$2]!, pose[side.$3]!);
  }

  /// 180 Grad heißt aufrecht, 90 Grad waagerecht.
  double? _torsoAngle(BodyPose pose) {
    PosePoint? better(Joint a, Joint b) {
      final pa = pose[a];
      final pb = pose[b];
      final best = (pa?.likelihood ?? 0) >= (pb?.likelihood ?? 0) ? pa : pb;
      return best != null && best.likelihood >= minLikelihood ? best : null;
    }

    final shoulder = better(Joint.leftShoulder, Joint.rightShoulder);
    final hip = better(Joint.leftHip, Joint.rightHip);
    if (shoulder == null || hip == null) return null;
    final dx = (shoulder.x - hip.x).abs();
    final dy = hip.y - shoulder.y;
    final tilt = atan2(dx, dy) * 180 / pi;
    return 180 - tilt.abs();
  }

  /// Der Winkel am Punkt [b] zwischen [a] und [c] in Grad.
  static double angleAt(PosePoint a, PosePoint b, PosePoint c) {
    final first = atan2(a.y - b.y, a.x - b.x);
    final second = atan2(c.y - b.y, c.x - b.x);
    var degrees = ((first - second) * 180 / pi).abs();
    if (degrees > 180) degrees = 360 - degrees;
    return degrees;
  }
}
