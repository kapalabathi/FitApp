import '../data/models.dart';

/// Schreibt die Strecke eines Trainings als GPX-Datei. Enthält nur
/// Messpunkte mit Standort; ohne solche ist das Ergebnis `null`.
String? buildGpx(Workout workout, List<Sample> samples) {
  final points = samples
      .where((s) => s.latitude != null && s.longitude != null)
      .toList();
  if (points.isEmpty) return null;
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="FitApp" '
        'xmlns="http://www.topografix.com/GPX/1/1" '
        'xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">')
    ..writeln('  <metadata><time>${_iso(workout.startedAt)}</time></metadata>')
    ..writeln('  <trk>')
    ..writeln('    <name>${_escape(workout.title ?? workout.sport.label)}</name>')
    ..writeln('    <trkseg>');
  for (final s in points) {
    b.write('      <trkpt lat="${s.latitude}" lon="${s.longitude}">');
    if (s.altitudeM != null) b.write('<ele>${_num(s.altitudeM!)}</ele>');
    b.write('<time>${_iso(_timeOf(workout, s))}</time>');
    if (s.heartRate != null) {
      b.write('<extensions><gpxtpx:TrackPointExtension>'
          '<gpxtpx:hr>${s.heartRate}</gpxtpx:hr>'
          '</gpxtpx:TrackPointExtension></extensions>');
    }
    b.writeln('</trkpt>');
  }
  b
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return b.toString();
}

/// Schreibt ein Training als TCX-Datei mit allen Messpunkten.
String buildTcx(Workout workout, List<Sample> samples) {
  final sport = switch (workout.sport) {
    Sport.running || Sport.treadmill => 'Running',
    Sport.indoorBike || Sport.cycling => 'Biking',
    _ => 'Other',
  };
  final start = _iso(workout.startedAt);
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<TrainingCenterDatabase '
        'xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" '
        'xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">')
    ..writeln('  <Activities>')
    ..writeln('    <Activity Sport="$sport">')
    ..writeln('      <Id>$start</Id>')
    ..writeln('      <Lap StartTime="$start">')
    ..writeln('        <TotalTimeSeconds>${workout.durationS}</TotalTimeSeconds>')
    ..writeln('        <DistanceMeters>${_num(workout.distanceM)}</DistanceMeters>');
  if (workout.energyKcal != null) {
    b.writeln('        <Calories>${workout.energyKcal}</Calories>');
  }
  b
    ..writeln('        <Intensity>Active</Intensity>')
    ..writeln('        <TriggerMethod>Manual</TriggerMethod>')
    ..writeln('        <Track>');
  for (final s in samples) {
    b.write('          <Trackpoint><Time>${_iso(_timeOf(workout, s))}</Time>');
    if (s.latitude != null && s.longitude != null) {
      b.write('<Position><LatitudeDegrees>${s.latitude}</LatitudeDegrees>'
          '<LongitudeDegrees>${s.longitude}</LongitudeDegrees></Position>');
    }
    if (s.altitudeM != null) {
      b.write('<AltitudeMeters>${_num(s.altitudeM!)}</AltitudeMeters>');
    }
    if (s.distanceM != null) {
      b.write('<DistanceMeters>${_num(s.distanceM!)}</DistanceMeters>');
    }
    if (s.heartRate != null) {
      b.write('<HeartRateBpm><Value>${s.heartRate}</Value></HeartRateBpm>');
    }
    if (s.cadence != null) b.write('<Cadence>${s.cadence!.round()}</Cadence>');
    if (s.speedKmh != null || s.power != null) {
      b.write('<Extensions><ns3:TPX>');
      if (s.speedKmh != null) {
        b.write('<ns3:Speed>${_num(s.speedKmh! / 3.6)}</ns3:Speed>');
      }
      if (s.power != null) b.write('<ns3:Watts>${s.power}</ns3:Watts>');
      b.write('</ns3:TPX></Extensions>');
    }
    b.writeln('</Trackpoint>');
  }
  b
    ..writeln('        </Track>')
    ..writeln('      </Lap>')
    ..writeln('    </Activity>')
    ..writeln('  </Activities>')
    ..writeln('</TrainingCenterDatabase>');
  return b.toString();
}

DateTime _timeOf(Workout w, Sample s) =>
    w.startedAt.add(Duration(seconds: s.t));

String _iso(DateTime t) => t.toUtc().toIso8601String();

String _num(double v) => v.toStringAsFixed(2);

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
