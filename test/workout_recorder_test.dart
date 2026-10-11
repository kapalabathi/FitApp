import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/session/workout_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late WorkoutRecorder recorder;

  /// Lässt [seconds] Sekunden vergehen und tickt dabei im Sekundentakt.
  void run(int seconds) {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      recorder.tick();
    }
  }

  setUp(() {
    db = AppDatabase.inMemory();
    now = DateTime(2026, 10, 11, 8);
    recorder = WorkoutRecorder(db: db, sport: Sport.treadmill, clock: () => now)
      ..addSource('band', dedicatedHeartRate: false)
      ..addSource('gurt', dedicatedHeartRate: true);
  });

  tearDown(() => db.close());

  test('koppelt Werte mehrerer Geräte in einem Messpunkt', () {
    recorder.onData('band', {Metric.speed: 9.0, Metric.incline: 1.5});
    recorder.onData('gurt', {Metric.heartRate: 140});
    run(1);

    final sample = db.samples(recorder.workoutId).single;
    expect(sample.t, 1);
    expect(sample.speedKmh, 9.0);
    expect(sample.incline, 1.5);
    expect(sample.heartRate, 140);
  });

  test('der Pulssensor hat Vorrang vor dem Puls des Fitnessgeräts', () {
    recorder.onData('band', {Metric.heartRate: 120});
    recorder.onData('gurt', {Metric.heartRate: 150});
    expect(recorder.value(Metric.heartRate), 150);
    expect(recorder.heartRateSources, ['band', 'gurt']);
  });

  test('die gewählte Pulsquelle hat Vorrang vor allen anderen', () {
    recorder.onData('band', {Metric.heartRate: 120});
    recorder.onData('gurt', {Metric.heartRate: 150});
    recorder.preferredHeartRateSource = 'band';
    expect(recorder.value(Metric.heartRate), 120);
  });

  test('veraltete Werte gelten nicht mehr; die nächste Quelle springt ein', () {
    recorder.onData('gurt', {Metric.heartRate: 150});
    run(3);
    recorder.onData('band', {Metric.heartRate: 120});
    run(3);
    // Der Gurt schweigt seit 6 s, das Band seit 3 s.
    expect(recorder.value(Metric.heartRate), 120);
    run(3);
    expect(recorder.value(Metric.heartRate), isNull);
    expect(db.samples(recorder.workoutId).last.heartRate, isNull);
  });

  test('ohne Distanzzähler wird die Strecke aus der Geschwindigkeit berechnet',
      () {
    for (var i = 0; i < 10; i++) {
      recorder.onData('band', {Metric.speed: 36.0});
      run(1);
    }
    expect(recorder.distanceM, closeTo(100, 0.001));
  });

  test('mit Distanzzähler zählt nur dessen Zuwachs seit Trainingsbeginn', () {
    // Das Band lief schon 500 m, bevor das Training begann.
    recorder.onData('band', {Metric.distanceTotal: 500, Metric.speed: 36.0});
    run(1);
    recorder.onData('band', {Metric.distanceTotal: 503});
    run(1);
    expect(recorder.distanceM, 3);
  });

  test('ein zurückgesetzter Distanzzähler erzeugt keine Strecke', () {
    recorder.onData('band', {Metric.distanceTotal: 500});
    recorder.onData('band', {Metric.distanceTotal: 510});
    recorder.onData('band', {Metric.distanceTotal: 0});
    recorder.onData('band', {Metric.distanceTotal: 4});
    expect(recorder.distanceM, 14);
  });

  test('in der Pause läuft weder Zeit noch Strecke', () {
    recorder.onData('band', {Metric.distanceTotal: 0});
    run(5);
    recorder.pause();
    recorder.onData('band', {Metric.distanceTotal: 20});
    run(30);
    recorder.resume();
    recorder.onData('band', {Metric.distanceTotal: 25});
    run(5);

    expect(recorder.elapsedS, 10);
    expect(recorder.distanceM, 5);
    expect(db.samples(recorder.workoutId), hasLength(10));
  });

  test('Abschluss berechnet die Kennzahlen aus den Messpunkten', () {
    recorder.onData('band', {Metric.distanceTotal: 0, Metric.energyTotal: 0});
    for (final hr in [100.0, 120.0, 140.0]) {
      recorder.onData('gurt', {Metric.heartRate: hr});
      recorder.onData('band', {Metric.power: hr * 2});
      run(1);
    }
    recorder.onData('band', {Metric.distanceTotal: 30, Metric.energyTotal: 7});
    run(1);

    final w = recorder.finish()!;
    expect(w.status, WorkoutStatus.finished);
    expect(w.durationS, 4);
    expect(w.distanceM, 30);
    expect(w.avgHeartRate, 125);
    expect(w.maxHeartRate, 140);
    expect(w.avgPower, 250);
    expect(w.maxPower, 280);
    expect(w.energyKcal, 7);
    expect(db.workouts().single.id, w.id);
  });

  test('ein Training ohne aktive Sekunde wird verworfen', () {
    expect(recorder.finish(), isNull);
    expect(db.workouts(), isEmpty);
  });

  test('nach dem Abschluss wird nichts mehr geschrieben', () {
    run(2);
    recorder.finish();
    run(5);
    expect(db.samples(recorder.workoutId), hasLength(2));
  });
}
