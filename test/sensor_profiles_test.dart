import 'package:fitapp/ble/decoders.dart';
import 'package:fitapp/ble/sensor_profiles.dart';
import 'package:fitapp/ble/uuids.dart';
import 'package:fitapp/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drehzahl aus Zählerständen', () {
    test('zwei Pakete ergeben die Frequenz dazwischen', () {
      final rate = RevolutionRate(ticksPerSecond: 1024);
      expect(rate.update(100, 0), isNull); // noch kein Vergleich möglich
      // 3 Umdrehungen in 2 Sekunden sind 90 je Minute
      expect(rate.update(103, 2048), 90);
      expect(rate.lastStep, 3);
    });

    test('ohne neue Umdrehung gibt es keinen neuen Wert', () {
      final rate = RevolutionRate(ticksPerSecond: 1024)..update(100, 500);
      expect(rate.update(100, 500), isNull);
      expect(rate.lastStep, 0);
    });

    test('Zähler und Zeit dürfen überlaufen', () {
      final rate = RevolutionRate(ticksPerSecond: 1024)..update(65534, 65000);
      // Zähler von 65534 über 0 auf 1: 3 Umdrehungen; Zeit ebenso 2048 weiter
      expect(rate.update(1, (65000 + 2048) & 0xFFFF), 90);
    });
  });

  group('Leistungsmesser', () {
    test('Leistung allein', () {
      final decode = cyclingPowerDecoder();
      expect(decode([0x00, 0x00, 0xFA, 0x00]), {Metric.power: 250.0});
    });

    test('mit Kurbeldaten kommt ab dem zweiten Paket die Trittfrequenz dazu',
        () {
      final decode = cyclingPowerDecoder();
      // Flags 0x0020: Kurbelumdrehungen; 200 W, Zähler 10, Zeit 0
      expect(decode([0x20, 0x00, 0xC8, 0x00, 0x0A, 0x00, 0x00, 0x00]),
          {Metric.power: 200.0});
      // Zähler 13, Zeit 2048 (2 s): 90 je Minute
      expect(decode([0x20, 0x00, 0xD2, 0x00, 0x0D, 0x00, 0x00, 0x08]),
          {Metric.power: 210.0, Metric.cadence: 90.0});
    });

    test('jede Verbindung rechnet für sich', () {
      final decoder = decoders.firstWhere(
          (d) => Uuids.same(d.characteristic, Uuids.cyclingPowerMeasurement));
      final first = decoder.create();
      final second = decoder.create();
      first([0x20, 0x00, 0xC8, 0x00, 0x0A, 0x00, 0x00, 0x00]);
      // Die zweite Verbindung kennt das Paket der ersten nicht.
      expect(
          second([0x20, 0x00, 0xD2, 0x00, 0x0D, 0x00, 0x00, 0x08])
              .containsKey(Metric.cadence),
          isFalse);
    });
  });

  test('Tritt- und Geschwindigkeitssensor: Tempo, Strecke und Trittfrequenz',
      () {
    final decode = cyclingSpeedCadenceDecoder(wheelCircumferenceM: 2);
    // Flags 0x03: Rad und Kurbel. Rad 1000 Umdrehungen, Kurbel 50, Zeit 0
    expect(decode([0x03, 0xE8, 0x03, 0x00, 0x00, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00]),
        isEmpty);
    // Eine Sekunde später: Rad +5 (10 m), Kurbel +1 in 1 s
    final values = decode(
        [0x03, 0xED, 0x03, 0x00, 0x00, 0x00, 0x04, 0x33, 0x00, 0x00, 0x04]);
    expect(values[Metric.speed], closeTo(36, 0.001)); // 10 m/s
    expect(values[Metric.distanceTotal], 10);
    expect(values[Metric.cadence], 60);
  });

  test('Laufsensor: Geschwindigkeit, Schrittfrequenz und Gesamtstrecke', () {
    // Flags 0x03: Schrittlänge und Strecke. 3 m/s (768/256), 172 Schritte,
    // Schrittlänge 1,05 m, 1234,5 m
    final values = runningSpeedCadence(
        [0x03, 0x00, 0x03, 0xAC, 0x69, 0x00, 0x39, 0x30, 0x00, 0x00]);
    expect(values[Metric.speed], closeTo(10.8, 0.001));
    expect(values[Metric.cadence], 172);
    expect(values[Metric.distanceTotal], 1234.5);

    // Ohne Zusatzfelder
    expect(runningSpeedCadence([0x00, 0x00, 0x02, 0xA0]),
        {Metric.speed: closeTo(7.2, 0.001), Metric.cadence: 160.0});
  });

  test('Rudergerät: Schlagfrequenz, Strecke, Tempo und Leistung', () {
    // Flags 0x002C: Strecke, Tempo, Leistung. 24 Schläge/min (48 halbe),
    // Schlagzahl 100, 1500 m, 2:05 je 500 m, 180 W
    final values = rowerData([
      0x2C, 0x00, //
      0x30, 0x64, 0x00, //
      0xDC, 0x05, 0x00, //
      0x7D, 0x00, //
      0xB4, 0x00,
    ]);
    expect(values[Metric.cadence], 24);
    expect(values[Metric.distanceTotal], 1500);
    expect(values[Metric.speed], closeTo(14.4, 0.001));
    expect(values[Metric.power], 180);
  });

  test('Rudergerät: gesetztes Bit 0 heißt, die Schlagdaten fehlen', () {
    // Flags 0x0201: mehr Daten folgen, Puls
    expect(rowerData([0x01, 0x02, 0x8C]), {Metric.heartRate: 140.0});
  });

  test('Crosstrainer: Geschwindigkeit, Strecke, Schritte, Widerstand, Leistung',
      () {
    // Flags 0x00018C: Strecke, Schritte, Widerstand, Leistung
    final values = crossTrainerData([
      0x8C, 0x01, 0x00, //
      0x84, 0x03, // 9,00 km/h
      0xE8, 0x03, 0x00, // 1000 m
      0x78, 0x00, 0x70, 0x00, // 120 Schritte/min, Ø 112
      0x50, 0x00, // Widerstand 8,0
      0x96, 0x00, // 150 W
    ]);
    expect(values, {
      Metric.speed: 9.0,
      Metric.distanceTotal: 1000.0,
      Metric.cadence: 120.0,
      Metric.resistance: 8.0,
      Metric.power: 150.0,
    });
  });

  test('alle neuen Profile sind für Verbindungen angemeldet', () {
    for (final uuid in [
      Uuids.cyclingPowerMeasurement,
      Uuids.cscMeasurement,
      Uuids.rscMeasurement,
      Uuids.rowerData,
      Uuids.crossTrainerData,
    ]) {
      expect(decoders.where((d) => Uuids.same(d.characteristic, uuid)),
          hasLength(1),
          reason: uuid);
    }
  });
}
