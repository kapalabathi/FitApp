import 'package:fit_tool/fit_tool.dart' as fit;
import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/export/fit_writer.dart';
import 'package:fitapp/export/xml_writers.dart';
import 'package:fitapp/ui/workout_actions.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 10, 11, 8);

final _workout = Workout(
  id: 1,
  uuid: 'abc',
  sport: Sport.running,
  startedAt: _start,
  status: WorkoutStatus.finished,
  title: 'Runde <am> See',
  durationS: 4,
  distanceM: 12,
  avgHeartRate: 141,
  maxHeartRate: 143,
  energyKcal: 2,
  ascentM: 7,
);

const _samples = [
  Sample(
      t: 1,
      heartRate: 140,
      speedKmh: 10.8,
      distanceM: 3,
      latitude: 50.1,
      longitude: -8.25,
      altitudeM: 212.4),
  Sample(
      t: 2,
      heartRate: 141,
      speedKmh: 10.8,
      distanceM: 6,
      latitude: 50.10003,
      longitude: -8.25,
      altitudeM: 212.6),
  // Sekunde ohne Standort und ohne Puls
  Sample(t: 3, distanceM: 9, cadence: 82, power: 205),
  Sample(t: 4, heartRate: 143, distanceM: 12, latitude: 50.1001, longitude: -8.25),
];

const _laps = [Lap(t: 2, distanceM: 6, auto: true)];

void main() {
  group('FIT', () {
    // Eine fremde Bibliothek liest, was die App geschrieben hat.
    final file = fit.FitFile.fromBytes(buildFit(_workout, _samples, _laps));
    List<T> messages<T>() =>
        file.records.map((r) => r.message).whereType<T>().toList();

    test('Kopf und Prüfsumme sind gültig', () {
      expect(file.crc, isNotNull);
      final id = messages<fit.FileIdMessage>().single;
      expect(id.type, fit.FileType.activity);
    });

    test('Messpunkte mit Zeit, Standort, Puls, Strecke und Geschwindigkeit',
        () {
      final records = messages<fit.RecordMessage>();
      expect(records, hasLength(4));

      final first = records.first;
      expect(first.timestamp,
          _start.add(const Duration(seconds: 1)).millisecondsSinceEpoch);
      expect(first.positionLat, closeTo(50.1, 1e-6));
      expect(first.positionLong, closeTo(-8.25, 1e-6));
      expect(first.altitude, closeTo(212.4, 0.11));
      expect(first.heartRate, 140);
      expect(first.distance, 3);
      expect(first.speed, closeTo(3, 0.001));

      // Fehlende Werte bleiben in der Datei fehlend, statt 0 zu werden.
      final third = records[2];
      expect(third.positionLat, isNull);
      expect(third.heartRate, isNull);
      expect(third.altitude, isNull);
      // 82 Schritte beider Beine; FIT zählt beim Laufen die eines Beins.
      expect(third.cadence, 41);
      expect(third.power, 205);
    });

    test('Runden: jede Marke und der Rest danach', () {
      final laps = messages<fit.LapMessage>();
      expect(laps, hasLength(2));
      expect(laps[0].totalTimerTime, 2);
      expect(laps[0].totalDistance, 6);
      expect(laps[1].totalTimerTime, 2);
      expect(laps[1].totalDistance, 6);
    });

    test('Zusammenfassung mit Sportart und Kennzahlen', () {
      final session = messages<fit.SessionMessage>().single;
      expect(session.sport, fit.Sport.running);
      expect(session.startTime, _start.millisecondsSinceEpoch);
      expect(session.totalTimerTime, 4);
      expect(session.totalDistance, 12);
      expect(session.avgHeartRate, 141);
      expect(session.totalAscent, 7);
      expect(session.numLaps, 2);
      expect(messages<fit.ActivityMessage>(), hasLength(1));
    });

    test('ein Training ohne Rundenmarken ist eine einzige Runde', () {
      final plain = fit.FitFile.fromBytes(buildFit(_workout, _samples, const []));
      final laps =
          plain.records.map((r) => r.message).whereType<fit.LapMessage>();
      expect(laps.single.totalTimerTime, 4);
    });

    test('mit Trainingsort trägt jeder Messpunkt ohne Strecke diesen Standort',
        () {
      const indoor = [
        Sample(t: 1, heartRate: 120, distanceM: 3),
        Sample(t: 2, heartRate: 121, distanceM: 6),
      ];
      final records = fit.FitFile.fromBytes(buildFit(_workout, indoor, const [],
              fixedLocation: (latitude: 48.5, longitude: 7.8)))
          .records
          .map((r) => r.message)
          .whereType<fit.RecordMessage>()
          .toList();
      expect(records, hasLength(2));
      for (final r in records) {
        expect(r.positionLat, closeTo(48.5, 1e-6));
        expect(r.positionLong, closeTo(7.8, 1e-6));
      }
      // Ohne Trainingsort bleibt der Standort leer.
      final plain = fit.FitFile.fromBytes(buildFit(_workout, indoor, const []))
          .records
          .map((r) => r.message)
          .whereType<fit.RecordMessage>();
      expect(plain.every((r) => r.positionLat == null), isTrue);
    });

    test('eine echte Strecke wird vom Trainingsort nicht überschrieben', () {
      final records = fit.FitFile.fromBytes(buildFit(_workout, _samples, _laps,
              fixedLocation: (latitude: 1, longitude: 2)))
          .records
          .map((r) => r.message)
          .whereType<fit.RecordMessage>()
          .toList();
      expect(records.first.positionLat, closeTo(50.1, 1e-6));
      // Der Messpunkt ohne Standort bleibt eine Lücke in der Strecke.
      expect(records[2].positionLat, isNull);
    });

    test('Laufband wird als Laufen auf dem Laufband gekennzeichnet', () {
      final treadmill = Workout(
        id: 2,
        uuid: 'x',
        sport: Sport.treadmill,
        startedAt: _start,
        status: WorkoutStatus.finished,
        durationS: 4,
      );
      final session = fit.FitFile.fromBytes(buildFit(treadmill, _samples, const []))
          .records
          .map((r) => r.message)
          .whereType<fit.SessionMessage>()
          .single;
      expect(session.sport, fit.Sport.running);
      expect(session.subSport, fit.SubSport.treadmill);
    });
  });

  group('GPX', () {
    test('enthält nur Punkte mit Standort, mit Höhe, Zeit und Puls', () {
      final gpx = buildGpx(_workout, _samples)!;
      expect('<trkpt'.allMatches(gpx), hasLength(3));
      expect(gpx, contains('<name>Runde &lt;am&gt; See</name>'));
      expect(gpx, contains('lat="50.1" lon="-8.25"'));
      expect(gpx, contains('<ele>212.40</ele>'));
      expect(gpx, contains('<time>2026-10-11T08:00:01.000Z</time>'));
      expect(gpx, contains('<gpxtpx:hr>140</gpxtpx:hr>'));
    });

    test('ohne Standorte gibt es keine GPX-Datei', () {
      expect(buildGpx(_workout, const [Sample(t: 1, heartRate: 120)]), isNull);
    });
  });

  group('Exportdateien', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    Workout record({required bool withRoute}) {
      final id = db.startWorkout(Sport.running, DateTime(2026, 10, 11, 8, 5));
      db.addSample(
          id,
          Sample(
              t: 1,
              heartRate: 120,
              distanceM: 3,
              latitude: withRoute ? 50 : null,
              longitude: withRoute ? 8 : null));
      db.finishWorkout(id);
      return db.workout(id)!;
    }

    test('der Dateiname nennt Datum, Sportart und Nummer', () {
      final w = record(withRoute: true);
      expect(exportFileName(w, ExportFormat.fit),
          'fitapp_2026-10-11_0805_running_${w.id}.fit');
      expect(exportFileName(w, ExportFormat.fitWithLocation),
          'fitapp_2026-10-11_0805_running_${w.id}_ort.fit');
      // Zwei Trainings derselben Minute bekommen verschiedene Namen.
      final other = record(withRoute: true);
      expect(exportFileName(other, ExportFormat.fit),
          isNot(exportFileName(w, ExportFormat.fit)));
    });

    test('GPX gibt es nur mit Strecke, FIT und TCX immer', () {
      final indoor = record(withRoute: false);
      expect(exportBytes(db, indoor, ExportFormat.gpx), isNull);
      expect(exportBytes(db, indoor, ExportFormat.fit), isNotEmpty);
      expect(exportBytes(db, indoor, ExportFormat.tcx), isNotEmpty);
      expect(exportBytes(db, record(withRoute: true), ExportFormat.gpx),
          isNotEmpty);
    });
  });

  group('TCX', () {
    test('enthält alle Messpunkte mit den vorhandenen Werten', () {
      final tcx = buildTcx(_workout, _samples);
      expect('<Trackpoint>'.allMatches(tcx), hasLength(4));
      expect(tcx, contains('<Activity Sport="Running">'));
      expect(tcx, contains('<TotalTimeSeconds>4</TotalTimeSeconds>'));
      expect(tcx, contains('<Calories>2</Calories>'));
      expect(tcx, contains('<Cadence>82</Cadence>'));
      expect(tcx, contains('<ns3:Watts>205</ns3:Watts>'));
      expect(tcx, contains('<ns3:Speed>3.00</ns3:Speed>'));
    });
  });
}
