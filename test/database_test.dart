import 'package:fitapp/ble/device_kind.dart';
import 'package:fitapp/data/database.dart';
import 'package:fitapp/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  int record(Sport sport, DateTime start, {int seconds = 3}) {
    final id = db.startWorkout(sport, start);
    for (var t = 1; t <= seconds; t++) {
      db.addSample(id, Sample(t: t, heartRate: 100 + t, distanceM: t * 2.0));
    }
    return id;
  }

  test('ein laufendes Training erscheint nicht im Verlauf', () {
    record(Sport.treadmill, DateTime(2026, 10, 1));
    expect(db.workouts(), isEmpty);
  });

  test('ein unterbrochenes Training wird beim Start gerettet', () {
    final id = record(Sport.indoorBike, DateTime(2026, 10, 1), seconds: 60);
    db.startWorkout(Sport.skiErg, DateTime(2026, 10, 2)); // ohne Messwerte

    expect(db.recoverUnfinished(), 1);

    final w = db.workouts().single;
    expect(w.id, id);
    expect(w.status, WorkoutStatus.recovered);
    expect(w.durationS, 60);
    expect(w.distanceM, 120);
    expect(w.maxHeartRate, 160);
    expect(db.recoverUnfinished(), 0);
  });

  test('der Verlauf filtert nach Sportart und Zeitraum, neueste zuerst', () {
    final old = record(Sport.treadmill, DateTime(2026, 1, 5));
    final bike = record(Sport.indoorBike, DateTime(2026, 9, 20));
    final recent = record(Sport.treadmill, DateTime(2026, 10, 1));
    for (final id in [old, bike, recent]) {
      db.finishWorkout(id);
    }

    expect(db.workouts().map((w) => w.id), [recent, bike, old]);
    expect(db.workouts(sport: Sport.treadmill).map((w) => w.id), [recent, old]);
    expect(db.workouts(since: DateTime(2026, 9, 1)).map((w) => w.id),
        [recent, bike]);
  });

  test('ein gelöschtes Training verschwindet samt Messwerten', () {
    final id = record(Sport.treadmill, DateTime(2026, 10, 1));
    db.finishWorkout(id);
    db.deleteWorkout(id);

    expect(db.workouts(), isEmpty);
    expect(db.samples(id), isEmpty);
  });

  test('jedes Training bekommt eine eigene geräteübergreifende Kennung', () {
    final a = record(Sport.treadmill, DateTime(2026, 10, 1));
    final b = record(Sport.treadmill, DateTime(2026, 10, 2));
    expect(db.workout(a)!.uuid, hasLength(32));
    expect(db.workout(a)!.uuid, isNot(db.workout(b)!.uuid));
  });

  group('Geräte', () {
    const gurt = SavedDevice(
        deviceId: 'AA:BB', name: 'Brustgurt', kind: DeviceKind.heartRate);
    const band = SavedDevice(
        deviceId: 'CC:DD', name: 'Laufband', kind: DeviceKind.fitnessMachine);

    test('merken, umbenennen und entfernen', () {
      db.saveDevice(gurt);
      db.saveDevice(band);
      db.renameDevice('AA:BB', 'Mein Gurt');

      final devices = db.devices();
      expect(devices.map((d) => d.name), ['Mein Gurt', 'Laufband']);
      expect(devices.first.kind, DeviceKind.heartRate);

      db.forgetDevice('AA:BB');
      expect(db.devices().single.deviceId, 'CC:DD');
    });

    test('erneutes Merken legt kein zweites Gerät an', () {
      db.saveDevice(gurt);
      db.saveDevice(gurt);
      expect(db.devices(), hasLength(1));
    });

    test('die Geräteauswahl wird je Sportart gemerkt', () {
      db.saveDevice(gurt);
      db.saveDevice(band);
      db.setDevicesForSport(Sport.treadmill, ['AA:BB', 'CC:DD']);
      db.setDevicesForSport(Sport.indoorBike, ['AA:BB']);

      expect(db.devicesForSport(Sport.treadmill), {'AA:BB', 'CC:DD'});
      expect(db.devicesForSport(Sport.indoorBike), {'AA:BB'});
      expect(db.devicesForSport(Sport.skiErg), isEmpty);

      // Ein entferntes Gerät verschwindet auch aus der Auswahl.
      db.forgetDevice('CC:DD');
      expect(db.devicesForSport(Sport.treadmill), {'AA:BB'});
    });
  });
}
