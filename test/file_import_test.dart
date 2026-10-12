import 'dart:convert';
import 'dart:typed_data';

import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/export/fit_writer.dart';
import 'package:fitapp/export/xml_writers.dart';
import 'package:fitapp/gps/geo.dart';
import 'package:fitapp/import/file_import.dart';
import 'package:fitapp/ui/workout_actions.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List text(String s) => Uint8List.fromList(utf8.encode(s));

/// Eine GPX-Datei, wie Uhren-Apps sie exportieren: 11,1 m je Sekunde nach
/// Norden, Puls in einer Erweiterung mit eigener Vorsilbe.
String gpx({String type = '', int points = 60, double stepDegrees = 0.0001}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="Zepp" '
        'xmlns="http://www.topografix.com/GPX/1/1" '
        'xmlns:ns3="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">')
    ..writeln('<trk><name>Abendrunde</name><type>$type</type><trkseg>');
  final start = DateTime.utc(2026, 10, 9, 17);
  for (var i = 0; i < points; i++) {
    b.writeln('<trkpt lat="${50 + i * stepDegrees}" lon="8.0">'
        '<ele>${200 + i * 0.5}</ele>'
        '<time>${start.add(Duration(seconds: i)).toIso8601String()}</time>'
        '<extensions><ns3:TrackPointExtension><ns3:hr>${130 + i % 5}</ns3:hr>'
        '<ns3:cad>85</ns3:cad></ns3:TrackPointExtension></extensions>'
        '</trkpt>');
  }
  b.writeln('</trkseg></trk></gpx>');
  return b.toString();
}

void main() {
  group('GPX', () {
    test('liest Strecke, Zeit, Höhe, Puls und Titel', () {
      final a = parseActivityFile('lauf.GPX', text(gpx(type: 'running')));
      expect(a.sport, Sport.running);
      expect(a.title, 'Abendrunde');
      expect(a.startedAt, DateTime.utc(2026, 10, 9, 17).toLocal());
      expect(a.samples, hasLength(60));
      expect(a.durationS, 60);

      final last = a.samples.last;
      expect(last.latitude, closeTo(50.0059, 1e-9));
      expect(last.altitudeM, 229.5);
      expect(last.heartRate, 134);
      expect(last.cadence, 85);
    });

    test('berechnet Strecke und Geschwindigkeit aus den Standorten', () {
      final a = parseActivityFile('lauf.gpx', text(gpx(type: 'running')));
      // 59 Schritte zu 11,12 m
      expect(a.samples.last.distanceM, closeTo(656, 1));
      // 11,12 m/s sind 40 km/h
      expect(a.samples.last.speedKmh, closeTo(40, 0.2));
      // 29,5 m Höhengewinn; gezählt wird in Stufen ab der Rauschschwelle von 3 m
      expect(a.ascentM, 27);
    });

    test('ohne Angabe entscheidet das Tempo über die Sportart', () {
      // 1,1 m je Sekunde: Gehtempo
      final walk =
          parseActivityFile('a.gpx', text(gpx(stepDegrees: 0.00001, points: 600)));
      expect(walk.sport, Sport.hiking);
      // 3,3 m je Sekunde: Lauftempo
      final run = parseActivityFile('b.gpx', text(gpx(stepDegrees: 0.00003)));
      expect(run.sport, Sport.running);
    });

    test('Zittern im Stand ergibt keine Strecke', () {
      final b = StringBuffer('<gpx><trk><trkseg>');
      for (var i = 0; i < 30; i++) {
        b.write('<trkpt lat="${50 + (i.isEven ? 0.00001 : 0)}" lon="8">'
            '<time>2026-10-09T17:00:${i.toString().padLeft(2, '0')}Z</time>'
            '</trkpt>');
      }
      b.write('</trkseg></trk></gpx>');
      final a = parseActivityFile('stand.gpx', text(b.toString()));
      expect(a.samples.last.distanceM, 0);
    });
  });

  group('eigene Exporte lassen sich wieder einlesen', () {
    final workout = Workout(
      id: 1,
      uuid: 'u',
      sport: Sport.treadmill,
      startedAt: DateTime.utc(2026, 10, 11, 8),
      status: WorkoutStatus.finished,
      durationS: 3,
      distanceM: 9,
    );
    const samples = [
      Sample(t: 1, heartRate: 140, speedKmh: 10.8, distanceM: 3, cadence: 80),
      Sample(t: 2, heartRate: 141, speedKmh: 10.8, distanceM: 6, power: 200),
      Sample(
          t: 3,
          heartRate: 142,
          speedKmh: 10.8,
          distanceM: 9,
          latitude: 50.1,
          longitude: 8.2,
          altitudeM: 210),
    ];

    test('FIT', () {
      final a = parseActivityFile(
          'training.fit', buildFit(workout, samples, const []));
      expect(a.sport, Sport.treadmill);
      expect(a.startedAt,
          DateTime.utc(2026, 10, 11, 8, 0, 1).toLocal()); // erster Messpunkt
      expect(a.samples.map((s) => s.heartRate), [140, 141, 142]);
      expect(a.samples.last.distanceM, 9);
      expect(a.samples.first.speedKmh, closeTo(10.8, 0.01));
      expect(a.samples[1].power, 200);
      expect(a.samples.last.latitude, closeTo(50.1, 1e-6));
      // Ein fehlender Standort bleibt fehlend.
      expect(a.samples.first.latitude, isNull);
    });

    test('FIT einer Uhr: Schrittfrequenz beider Beine, keine Leistung von 0 W',
        () {
      // Wie eine Amazfit sie schreibt: 80 Schritte je Bein, überall 0 W
      final run = Workout(
        id: 2,
        uuid: 'v',
        sport: Sport.running,
        startedAt: DateTime.utc(2026, 10, 1, 3),
        status: WorkoutStatus.finished,
        durationS: 2,
        distanceM: 6,
      );
      final a = parseActivityFile(
          'uhr.fit',
          buildFit(run, const [
            Sample(t: 1, cadence: 160, power: 0, distanceM: 3),
            Sample(t: 2, cadence: 162, power: 0, distanceM: 6),
          ], const []));
      expect(a.sport, Sport.running);
      // Die Datei enthält 80 und 81; gelesen werden wieder 160 und 162.
      expect(a.samples.map((s) => s.cadence), [160, 162]);
      expect(a.samples.every((s) => s.power == null), isTrue);
    });

    test('auf dem Rad bleibt die Trittfrequenz, wie sie ist', () {
      final ride = Workout(
        id: 3,
        uuid: 'w',
        sport: Sport.indoorBike,
        startedAt: DateTime.utc(2026, 10, 1, 3),
        status: WorkoutStatus.finished,
        durationS: 1,
      );
      final a = parseActivityFile('rad.fit',
          buildFit(ride, const [Sample(t: 1, cadence: 90, power: 150)], const []));
      expect(a.samples.single.cadence, 90);
      expect(a.samples.single.power, 150);
    });

    test('TCX', () {
      final a =
          parseActivityFile('training.tcx', text(buildTcx(workout, samples)));
      expect(a.sport, Sport.running);
      expect(a.samples, hasLength(3));
      expect(a.samples.last.distanceM, 9);
      expect(a.samples.last.heartRate, 142);
      expect(a.samples.first.cadence, 80);
      expect(a.samples[1].power, 200);
      expect(a.samples.first.speedKmh, closeTo(10.8, 0.01));
      expect(a.samples.last.altitudeM, 210);
    });
  });

  group('unbrauchbare Dateien', () {
    test('werden mit verständlicher Meldung abgelehnt', () {
      ImportException error(String name, Uint8List bytes) {
        try {
          parseActivityFile(name, bytes);
        } on ImportException catch (e) {
          return e;
        }
        fail('$name wurde nicht abgelehnt');
      }

      expect(error('foto.jpg', Uint8List(10)).message, contains('FIT, GPX'));
      expect(error('kaputt.fit', Uint8List(40)).message, contains('FIT'));
      expect(error('kaputt.gpx', text('<gpx><trk>')).message, contains('GPX'));
      expect(error('leer.gpx', text('<gpx></gpx>')).message,
          contains('keine Strecke'));
      expect(error('leer.tcx', text('<a/>')).message,
          contains('keine Messpunkte'));
    });
  });

  group('Übernahme in die Datenbank', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    test('legt das Training an; dieselbe Datei kommt nicht doppelt', () {
      final summary = ImportSummary();
      final file = text(gpx(type: 'running', points: 300));
      importParsedFile(db, 'lauf.gpx', file, summary);
      importParsedFile(db, 'lauf-kopie.gpx', file, summary);
      importParsedFile(db, 'foto.jpg', [1, 2, 3], summary);

      expect(summary.imported, 1);
      expect(summary.duplicates, 1);
      expect(summary.failures.single, startsWith('foto.jpg'));
      expect(summary.message,
          startsWith('1 Training importiert, 1 schon vorhanden, nicht lesbar'));

      final w = db.workouts().single;
      expect(w.sport, Sport.running);
      expect(w.title, 'Abendrunde');
      expect(w.imported, isTrue);
      expect(w.stravaId, isNull);
      expect(w.durationS, 300);
      expect(w.distanceM, closeTo(3325, 5));
      expect(w.avgHeartRate, 132);
      expect(w.ascentM, 147);
      expect(db.samples(w.id).first.latitude, 50);
    });

    test('ein gelöschtes Training lässt sich erneut importieren', () {
      final file = text(gpx(type: 'running'));
      importParsedFile(db, 'lauf.gpx', file, ImportSummary());
      db.deleteWorkout(db.workouts().single.id);
      final again = ImportSummary();
      importParsedFile(db, 'lauf.gpx', file, again);
      expect(again.imported, 1);
    });
  });

  test('Anstieg aus einem Höhenverlauf', () {
    expect(ascentMeters([100, 101, 99.5, 104, 110, 108, 103, 106.5]), 13.5);
    expect(ascentMeters([]), 0);
  });
}
