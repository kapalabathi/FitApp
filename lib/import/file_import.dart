import 'dart:convert';
import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart' as fit;
import 'package:xml/xml.dart';

import '../data/models.dart';
import '../gps/geo.dart';

/// Ein aus einer Datei gelesenes Training, bereit zum Speichern.
class ParsedActivity {
  const ParsedActivity({
    required this.sport,
    required this.startedAt,
    required this.samples,
    this.title,
  });

  final Sport sport;
  final DateTime startedAt;
  final List<Sample> samples;
  final String? title;

  int get durationS => samples.isEmpty ? 0 : samples.last.t;

  /// Summe der Anstiege aus dem Höhenverlauf; `null` ohne Höhendaten.
  int? get ascentM {
    final heights = samples.map((s) => s.altitudeM).whereType<double>();
    return heights.isEmpty ? null : ascentMeters(heights).round();
  }
}

/// Die Datei ließ sich nicht als Training lesen.
class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Liest eine FIT-, GPX- oder TCX-Datei (Lastenheft A-063). Das Format ergibt
/// sich aus der Endung von [fileName].
ParsedActivity parseActivityFile(String fileName, Uint8List bytes) {
  final lower = fileName.toLowerCase();
  try {
    if (lower.endsWith('.fit')) return _parseFit(bytes);
    if (lower.endsWith('.gpx')) return _parseGpx(utf8.decode(bytes));
    if (lower.endsWith('.tcx')) return _parseTcx(utf8.decode(bytes));
  } on ImportException {
    rethrow;
  } catch (e) {
    throw ImportException('Die Datei ist beschädigt oder kein gültiges '
        '${lower.split('.').last.toUpperCase()}.');
  }
  throw const ImportException(
      'Unbekanntes Format; möglich sind FIT, GPX und TCX.');
}

/// Ein Messpunkt mit seinem Zeitpunkt, bevor daraus Sekunden ab Start werden.
class _Point {
  _Point(this.time);

  final DateTime time;
  double? latitude;
  double? longitude;
  double? altitudeM;
  double? distanceM;
  double? speedKmh;
  int? heartRate;
  double? cadence;
  int? power;
}

/// Macht aus zeitgestempelten Punkten die Messpunkte der App. Fehlen Strecke
/// oder Geschwindigkeit, werden sie aus den Standorten berechnet.
ParsedActivity _build(List<_Point> points,
    {required Sport? sport, String? title}) {
  points.sort((a, b) => a.time.compareTo(b.time));
  if (points.isEmpty) {
    throw const ImportException('Die Datei enthält keine Messpunkte.');
  }
  final start = points.first.time;
  final hasDistance = points.any((p) => p.distanceM != null);
  // Uhren ohne Leistungsmessung schreiben durchgehend 0 W in die Datei.
  // Das ist keine Messung und soll nicht als Leistung von 0 W erscheinen.
  if (!points.any((p) => (p.power ?? 0) > 0)) {
    for (final p in points) {
      p.power = null;
    }
  }
  final hasSpeed = points.any((p) => p.speedKmh != null);

  if (!hasDistance) {
    var total = 0.0;
    _Point? anchor;
    for (final p in points) {
      if (p.latitude == null || p.longitude == null) continue;
      if (anchor == null) {
        anchor = p;
      } else {
        final step = distanceMeters(
            anchor.latitude!, anchor.longitude!, p.latitude!, p.longitude!);
        // Kleinere Bewegungen sind meist Rauschen im Stand und würden die
        // Strecke aufblähen.
        if (step >= _minStepM) {
          total += step;
          anchor = p;
        }
      }
      p.distanceM = total;
    }
  }
  if (!hasSpeed) {
    // Geschwindigkeit über die letzten Sekunden gemittelt; von Punkt zu
    // Punkt gerechnet wäre sie vom Rauschen des GPS zerhackt.
    var from = 0;
    for (var i = 1; i < points.length; i++) {
      final distance = points[i].distanceM;
      if (distance == null) continue;
      while (points[i].time.difference(points[from].time) > _speedWindow &&
          from < i - 1) {
        from++;
      }
      final earlier = points[from].distanceM;
      final seconds =
          points[i].time.difference(points[from].time).inMilliseconds / 1000;
      if (earlier != null && seconds > 0) {
        points[i].speedKmh = (distance - earlier) / seconds * 3.6;
      }
    }
  }

  final samples = <Sample>[];
  for (final p in points) {
    final t = p.time.difference(start).inSeconds + 1;
    // Mehrere Punkte in derselben Sekunde: der letzte gilt.
    if (samples.isNotEmpty && samples.last.t == t) samples.removeLast();
    samples.add(Sample(
      t: t,
      heartRate: p.heartRate,
      speedKmh: p.speedKmh,
      cadence: p.cadence,
      power: p.power,
      distanceM: p.distanceM,
      latitude: p.latitude,
      longitude: p.longitude,
      altitudeM: p.altitudeM,
    ));
  }
  return ParsedActivity(
    sport: sport ?? _guessSport(samples),
    startedAt: start.toLocal(),
    samples: samples,
    title: title == null || title.trim().isEmpty ? null : title.trim(),
  );
}

const _speedWindow = Duration(seconds: 8);
const _minStepM = 3.0;

/// Nennt die Datei keine Sportart, entscheidet das Durchschnittstempo:
/// langsamer als zügiges Gehen ist Spazieren/Wandern, bis Lauftempo Laufen.
Sport _guessSport(List<Sample> samples) {
  final distance = samples.last.distanceM ?? 0;
  if (distance <= 0) return Sport.other;
  final kmh = distance / samples.last.t * 3.6;
  if (kmh < 7) return Sport.hiking;
  if (kmh < 20) return Sport.running;
  return Sport.other;
}

/// Die Sportart zu einer Bezeichnung aus GPX oder TCX, oder `null`, wenn sie
/// nichts Bekanntes nennt.
Sport? _sportFromText(String? text) {
  final t = (text ?? '').toLowerCase();
  if (t.contains('run') || t.contains('lauf')) return Sport.running;
  if (t.contains('hik') || t.contains('walk') || t.contains('wander')) {
    return Sport.hiking;
  }
  if (t.contains('bik') || t.contains('cycl') || t.contains('ride')) {
    return Sport.other;
  }
  return null;
}

// --- FIT ---

ParsedActivity _parseFit(Uint8List bytes) {
  final file = fit.FitFile.fromBytes(bytes);
  final points = <_Point>[];
  fit.Sport? sport;
  fit.SubSport? subSport;
  for (final record in file.records) {
    final m = record.message;
    if (m is fit.SessionMessage) {
      sport ??= m.sport;
      subSport ??= m.subSport;
    } else if (m is fit.RecordMessage) {
      final timestamp = m.timestamp;
      if (timestamp == null) continue;
      final speed = m.enhancedSpeed ?? m.speed;
      points.add(
          _Point(DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true))
            ..latitude = m.positionLat
            ..longitude = m.positionLong
            ..altitudeM = m.enhancedAltitude ?? m.altitude
            ..distanceM = m.distance
            ..speedKmh = speed == null ? null : speed * 3.6
            ..heartRate = m.heartRate
            ..cadence = m.cadence?.toDouble()
            ..power = m.power);
    }
  }
  // FIT zählt beim Laufen und Gehen die Schritte eines Beins; die App zeigt
  // wie üblich die Schritte beider Beine je Minute.
  if (sport == fit.Sport.running ||
      sport == fit.Sport.walking ||
      sport == fit.Sport.hiking) {
    for (final p in points) {
      final oneLeg = p.cadence;
      if (oneLeg != null) p.cadence = oneLeg * 2;
    }
  }
  final indoor = subSport == fit.SubSport.treadmill ||
      subSport == fit.SubSport.indoorCycling ||
      subSport == fit.SubSport.indoorRunning;
  return _build(
    points,
    sport: switch (sport) {
      fit.Sport.running => indoor ? Sport.treadmill : Sport.running,
      fit.Sport.walking || fit.Sport.hiking => Sport.hiking,
      fit.Sport.cycling => indoor ? Sport.indoorBike : Sport.other,
      null || fit.Sport.generic => null,
      _ => Sport.other,
    },
  );
}

// --- GPX ---

ParsedActivity _parseGpx(String text) {
  final doc = XmlDocument.parse(text);
  final track = doc.findAllElements('trk', namespaceUri: '*').firstOrNull;
  final points = <_Point>[];
  for (final e in doc.findAllElements('trkpt', namespaceUri: '*')) {
    final time = DateTime.tryParse(_text(e, 'time') ?? '');
    final lat = double.tryParse(e.getAttribute('lat') ?? '');
    final lon = double.tryParse(e.getAttribute('lon') ?? '');
    if (time == null || lat == null || lon == null) continue;
    points.add(_Point(time)
      ..latitude = lat
      ..longitude = lon
      ..altitudeM = double.tryParse(_text(e, 'ele') ?? '')
      // Puls und Frequenz stehen in Erweiterungen, deren Vorsilbe je nach
      // Programm verschieden ist; der Name ohne Vorsilbe ist überall gleich.
      ..heartRate = int.tryParse(_text(e, 'hr') ?? '')
      ..cadence = double.tryParse(_text(e, 'cad') ?? ''));
  }
  if (points.isEmpty) {
    throw const ImportException(
        'Die GPX-Datei enthält keine Strecke mit Zeitangaben.');
  }
  return _build(
    points,
    sport: _sportFromText(track == null ? null : _text(track, 'type')),
    title: track == null ? null : _text(track, 'name'),
  );
}

// --- TCX ---

ParsedActivity _parseTcx(String text) {
  final doc = XmlDocument.parse(text);
  final activity = doc.findAllElements('Activity', namespaceUri: '*').firstOrNull;
  final points = <_Point>[];
  for (final e in doc.findAllElements('Trackpoint', namespaceUri: '*')) {
    final time = DateTime.tryParse(_text(e, 'Time') ?? '');
    if (time == null) continue;
    final speed = double.tryParse(_text(e, 'Speed') ?? '');
    final heartRate = e.findElements('HeartRateBpm', namespaceUri: '*').firstOrNull;
    points.add(_Point(time)
      ..latitude = double.tryParse(_text(e, 'LatitudeDegrees') ?? '')
      ..longitude = double.tryParse(_text(e, 'LongitudeDegrees') ?? '')
      ..altitudeM = double.tryParse(_text(e, 'AltitudeMeters') ?? '')
      ..distanceM = double.tryParse(_text(e, 'DistanceMeters') ?? '')
      ..speedKmh = speed == null ? null : speed * 3.6
      ..heartRate = heartRate == null
          ? null
          : double.tryParse(_text(heartRate, 'Value') ?? '')?.round()
      ..cadence = double.tryParse(_text(e, 'Cadence') ?? '')
      ..power = double.tryParse(_text(e, 'Watts') ?? '')?.round());
  }
  return _build(points, sport: _sportFromText(activity?.getAttribute('Sport')));
}

/// Der Text des ersten Nachfahren mit diesem Namen, gleich in welchem
/// Namensraum.
String? _text(XmlElement parent, String name) =>
    parent.findAllElements(name, namespaceUri: '*').firstOrNull?.innerText.trim();
