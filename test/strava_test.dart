import 'dart:convert';

import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/stats/stats.dart';
import 'package:fitapp/strava/strava_api.dart';
import 'package:fitapp/strava/strava_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Eine Strava-Attrappe: merkt sich die Anfragen und antwortet nach Vorgabe.
class FakeStrava {
  final List<http.Request> requests = [];
  List<Map<String, Object?>> activities = [];
  Map<int, Map<String, Object?>> streams = {};

  /// Antworten auf die Abfrage des Upload-Stands, der Reihe nach.
  List<Map<String, Object?>> uploadStatus = [];
  int tokenCalls = 0;

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    http.Response json(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status,
            headers: {'content-type': 'application/json; charset=utf-8'});

    if (path == '/oauth/token') {
      tokenCalls++;
      return json({
        'access_token': 'access-$tokenCalls',
        'refresh_token': 'refresh-$tokenCalls',
        'expires_at':
            DateTime.now().add(const Duration(hours: 6)).millisecondsSinceEpoch ~/
                1000,
      });
    }
    if (path == '/api/v3/athlete/activities') return json(activities);
    if (path == '/api/v3/uploads') return json({'id': 77}, 201);
    if (path == '/api/v3/uploads/77') return json(uploadStatus.removeAt(0));
    final stream = RegExp(r'^/api/v3/activities/(\d+)/streams$').firstMatch(path);
    if (stream != null) return json(streams[int.parse(stream.group(1)!)] ?? {});
    return json({'message': 'unbekannt'}, 404);
  });
}

Map<String, Object?> activity(int id, DateTime start,
        {String type = 'Run',
        bool trainer = false,
        int seconds = 1800,
        String? externalId,
        String name = 'Morgenlauf'}) =>
    {
      'id': id,
      'name': name,
      'sport_type': type,
      'trainer': trainer,
      'start_date': start.toUtc().toIso8601String(),
      'elapsed_time': seconds,
      'total_elevation_gain': 42.4,
      'external_id': externalId,
    };

void main() {
  late FakeStrava strava;
  late MemorySecretStore store;
  late StravaApi api;
  late AppDatabase db;
  late StravaService service;

  setUp(() {
    strava = FakeStrava();
    store = MemorySecretStore();
    api = StravaApi(strava.client, store);
    db = AppDatabase.inMemory();
    service = StravaService(db, api, pollDelay: Duration.zero);
  });
  tearDown(() => db.close());

  Future<void> connect() async {
    await api.setCredentials('12345', 'geheim');
    await api.completeAuthorization(
        'fitapp://localhost/strava?code=abc&scope=read,activity:write,activity:read_all');
  }

  group('Anmeldung', () {
    test('die Anmeldeseite bekommt Kennung, Rückadresse und Rechte', () async {
      await api.setCredentials(' 12345 ', 'geheim');
      final uri = await api.authorizeUri();
      expect(uri.host, 'www.strava.com');
      expect(uri.queryParameters['client_id'], '12345');
      expect(uri.queryParameters['redirect_uri'], 'fitapp://localhost/strava');
      expect(uri.queryParameters['scope'], 'activity:write,activity:read_all');
    });

    test('der Anmeldecode wird gegen Tokens getauscht', () async {
      expect(await api.isConnected, isFalse);
      await connect();
      expect(await api.isConnected, isTrue);
      final body = strava.requests.single.bodyFields;
      expect(body['grant_type'], 'authorization_code');
      expect(body['code'], 'abc');
      expect(body['client_secret'], 'geheim');
    });

    test('fehlt ein Recht, wird die Anmeldung nicht abgeschlossen', () async {
      await api.setCredentials('12345', 'geheim');
      await expectLater(
          api.completeAuthorization(
              'fitapp://localhost/strava?code=abc&scope=read,activity:write'),
          throwsA(isA<StravaException>()));
      await expectLater(
          api.completeAuthorization(
              'fitapp://localhost/strava?error=access_denied'),
          throwsA(isA<StravaException>()));
      expect(await api.isConnected, isFalse);
      expect(strava.requests, isEmpty);
    });

    test('ein abgelaufenes Token wird vor der Anfrage erneuert', () async {
      await connect();
      await api.activities(after: DateTime(2026));
      expect(strava.tokenCalls, 1); // noch gültig

      await store.write('strava.expiresAt', '1000');
      await api.activities(after: DateTime(2026));
      expect(strava.tokenCalls, 2);
      final refresh = strava.requests[strava.requests.length - 2].bodyFields;
      expect(refresh['grant_type'], 'refresh_token');
      expect(refresh['refresh_token'], 'refresh-1');
      expect(strava.requests.last.headers['Authorization'], 'Bearer access-2');
      // Das neue Erneuerungs-Token ersetzt das alte.
      expect(await store.read('strava.refreshToken'), 'refresh-2');
    });

    test('ohne Verbindung gibt es eine verständliche Meldung', () async {
      await expectLater(api.activities(after: DateTime(2026)),
          throwsA(isA<StravaException>()));
    });

    test('Trennen vergisst die Tokens, nicht die Anwendung', () async {
      await connect();
      await api.disconnect();
      expect(await api.isConnected, isFalse);
      expect(await api.hasCredentials, isTrue);
    });
  });

  group('Sportarten', () {
    test('App zu Strava', () {
      expect(stravaSport(Sport.treadmill), (type: 'Run', trainer: true));
      expect(stravaSport(Sport.running), (type: 'Run', trainer: false));
      expect(stravaSport(Sport.indoorBike), (type: 'Ride', trainer: true));
      expect(stravaSport(Sport.hiking).type, 'Hike');
    });

    test('Strava zu App', () {
      expect(sportFromStrava('Run', trainer: false), Sport.running);
      expect(sportFromStrava('Run', trainer: true), Sport.treadmill);
      expect(sportFromStrava('Walk', trainer: false), Sport.hiking);
      expect(sportFromStrava('VirtualRide', trainer: false), Sport.indoorBike);
      // Radfahren im Freien kennt die App nicht als eigene Sportart.
      expect(sportFromStrava('Ride', trainer: false), Sport.cycling);
      expect(sportFromStrava('Swim', trainer: false), Sport.other);
    });
  });

  group('Upload', () {
    late Workout workout;

    setUp(() async {
      await connect();
      strava.requests.clear();
      final id = db.startWorkout(Sport.treadmill, DateTime(2026, 10, 11, 8));
      for (var t = 1; t <= 600; t++) {
        db.addSample(id, Sample(t: t, heartRate: 140, distanceM: t * 3.0));
      }
      db.finishWorkout(id);
      db.updateWorkout(id,
          title: 'Intervalle', sport: Sport.treadmill, notes: 'locker');
      workout = db.workout(id)!;
    });

    test('lädt die FIT-Datei mit Titel, Sportart und Kennung hoch', () async {
      strava.uploadStatus = [
        {'activity_id': null, 'error': null},
        {'activity_id': 4711, 'error': null},
      ];
      expect(await service.upload(workout), 4711);

      final upload = strava.requests.first;
      expect(upload.method, 'POST');
      // Der Anhang ist binär; als Latin-1 gelesen bleiben die Textfelder lesbar.
      final body = latin1.decode(upload.bodyBytes);
      expect(body, contains('name="sport_type"\r\n\r\nRun'));
      expect(body, contains('name="trainer"\r\n\r\n1'));
      expect(body, contains('name="name"\r\n\r\nIntervalle'));
      expect(body, contains('name="description"\r\n\r\nlocker'));
      expect(body, contains('name="external_id"\r\n\r\nfitapp-${workout.uuid}'));
      expect(body, contains('.FIT'));

      expect(db.workout(workout.id)!.stravaId, 4711);
      expect(db.workout(workout.id)!.imported, isFalse);
    });

    test('mehrere Trainings: überspringt Hochgeladene und zählt das Ergebnis',
        () async {
      final done = db.startWorkout(Sport.treadmill, DateTime(2026, 10, 12, 8));
      db.addSample(done, const Sample(t: 1, distanceM: 3));
      db.finishWorkout(done);
      db.setStravaId(done, 99);
      strava.uploadStatus = [
        {'activity_id': 4711, 'error': null},
      ];
      final progress = <int>[];
      final result = await service.uploadMany(
        [workout, db.workout(done)!],
        onProgress: (n, _) => progress.add(n),
      );
      expect(result.uploaded, 1);
      expect(result.skipped, 1);
      expect(result.failed, 0);
      expect(result.summary, '1 hochgeladen, 1 übersprungen');
      expect(progress, [0, 1, 2]);
      expect(db.workout(workout.id)!.stravaId, 4711);
    });

    test('mehrere Trainings: ein Fehler hält die übrigen nicht auf', () async {
      final other = db.startWorkout(Sport.treadmill, DateTime(2026, 10, 12, 8));
      db.addSample(other, const Sample(t: 1, distanceM: 3));
      db.finishWorkout(other);
      strava.uploadStatus = [
        {'activity_id': null, 'error': 'kaputt'},
        {'activity_id': 4712, 'error': null},
      ];
      final result = await service.uploadMany([workout, db.workout(other)!]);
      expect(result.uploaded, 1);
      expect(result.failed, 1);
      expect(result.firstError, contains('kaputt'));
    });

    test('eine von Strava abgelehnte Datei wird gemeldet', () async {
      strava.uploadStatus = [
        {'activity_id': null, 'error': 'duplicate of activity 99'},
      ];
      await expectLater(
          service.upload(workout),
          throwsA(isA<StravaException>()
              .having((e) => e.message, 'Meldung', contains('duplicate'))));
      expect(db.workout(workout.id)!.stravaId, isNull);
    });

    test('erkennt eine Aktivität im selben Zeitraum', () async {
      // Training: 8:00 bis 8:10
      strava.activities = [
        activity(1, DateTime(2026, 10, 11, 6, 30), seconds: 3600), // bis 7:30
        activity(2, DateTime(2026, 10, 11, 8, 5), name: 'Uhr-Lauf'),
      ];
      final similar = await service.similarActivity(workout);
      expect(similar!.name, 'Uhr-Lauf');

      strava.activities = [strava.activities.first];
      expect(await service.similarActivity(workout), isNull);
    });
  });

  group('Import', () {
    final start = DateTime(2026, 10, 10, 7);

    setUp(connect);

    test('übernimmt Aktivitäten mit Strecke, Puls und Kennzahlen', () async {
      strava.activities = [activity(500, start, seconds: 3)];
      strava.streams[500] = {
        'time': {'data': [0, 1, 3]},
        'latlng': {
          'data': [
            [50.0, 8.0],
            [50.00003, 8.0],
            [50.0001, 8.0],
          ]
        },
        'heartrate': {'data': [120, 125, 131]},
        'distance': {'data': [0.0, 3.3, 11.1]},
        'altitude': {'data': [200.0, 200.5, 201.0]},
        'velocity_smooth': {'data': [0, 3.3, 3.9]},
      };

      expect(await service.importNew(), 1);

      final w = db.workouts().single;
      expect(w.sport, Sport.running);
      expect(w.title, 'Morgenlauf');
      expect(w.startedAt, start);
      expect(w.imported, isTrue);
      expect(w.stravaId, 500);
      expect(w.durationS, 4);
      expect(w.distanceM, 11.1);
      expect(w.maxHeartRate, 131);
      expect(w.ascentM, 42);

      final samples = db.samples(w.id);
      expect(samples.map((s) => s.t), [1, 2, 4]);
      expect(samples.last.latitude, 50.0001);
      expect(samples[1].speedKmh, closeTo(11.88, 0.001));
      expect(samples.first.altitudeM, 200);
    });

    test('überspringt Bekanntes und eigene Uploads', () async {
      strava.activities = [
        activity(500, start),
        activity(501, start.add(const Duration(hours: 5)),
            externalId: 'fitapp-abcdef'),
        activity(502, start.add(const Duration(hours: 9)), type: 'Hike'),
      ];
      expect(await service.importNew(), 2);
      expect(db.workouts().map((w) => w.stravaId), [502, 500]);

      // Ein zweiter Lauf bringt nichts doppelt.
      expect(await service.importNew(), 0);
      expect(db.workouts(), hasLength(2));
    });

    test('ein gelöschter Import kommt nicht zurück', () async {
      strava.activities = [activity(500, start)];
      await service.importNew();
      db.deleteWorkout(db.workouts().single.id);
      expect(await service.importNew(), 0);
      expect(db.workouts(), isEmpty);
    });

    test('Aktivitäten ohne Messreihen behalten ihre Dauer', () async {
      strava.activities = [activity(500, start, type: 'Yoga', seconds: 1200)];
      await service.importNew();
      final w = db.workouts().single;
      expect(w.sport, Sport.yoga);
      expect(w.durationS, 1200);
    });
  });

  test('Bestzeiten rechnen bei lückenhaften Messpunkten mit der echten Zeit',
      () {
    // 1000 m in 500 s, aber nur alle 100 s ein Messpunkt
    final id = db.importWorkout(
      sport: Sport.running,
      startedAt: DateTime(2026, 10, 1),
      title: 'Lückenhaft',
      stravaId: 9,
      samples: [
        for (var t = 100; t <= 500; t += 100) Sample(t: t, distanceM: t * 2.0),
      ],
    );
    final best = db.bestEfforts(Sport.running)[EffortKind.fastest1km]!;
    expect(best.workoutId, id);
    expect(best.value, 500);
  });
}
