import 'package:fitapp/ble/decoders.dart';
import 'package:fitapp/ble/uuids.dart';
import 'package:fitapp/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<Metric, double> decode(String characteristic, List<int> bytes) => decoders
    .firstWhere((d) => Uuids.same(d.characteristic, characteristic))
    .create()(bytes);

void main() {
  test('Pulssensor: 0 gilt als „noch kein Puls"', () {
    expect(decode(Uuids.heartRateMeasurement, [0x00, 72]),
        {Metric.heartRate: 72.0});
    expect(decode(Uuids.heartRateMeasurement, [0x00, 0]), isEmpty);
  });

  test('Laufband: nur mitgeschickte Felder werden zu Messwerten', () {
    // Flags 0x0104: Distanz und Herzfrequenz; Geschwindigkeit 8,50 km/h,
    // 1234 m, Puls 0 (kein Handsensor)
    final values = decode(Uuids.treadmillData,
        [0x04, 0x01, 0x52, 0x03, 0xD2, 0x04, 0x00, 0x00]);
    expect(values, {Metric.speed: 8.5, Metric.distanceTotal: 1234.0});
  });

  test('Indoor-Bike: Trittfrequenz, Widerstand und Leistung', () {
    final values = decode(Uuids.indoorBikeData,
        [0x64, 0x00, 0xC4, 0x09, 0xB4, 0x00, 0x08, 0x00, 0x96, 0x00]);
    expect(values, {
      Metric.speed: 25.0,
      Metric.cadence: 90.0,
      Metric.resistance: 8.0,
      Metric.power: 150.0,
    });
  });

  group('Concept2 PM5', () {
    test('Status: Distanz in Zehntelmetern', () {
      // Zeit 60,00 s, Distanz 250,0 m
      final values = pm5General([0x70, 0x17, 0x00, 0xC4, 0x09, 0x00, 0, 0, 0]);
      expect(values, {Metric.distanceTotal: 250.0});
    });

    test('Zusatzstatus: Geschwindigkeit, Schlagfrequenz, Leistung aus Tempo',
        () {
      // 4,000 m/s, 32 Schläge/min, kein Pulsgurt, Tempo 2:05,0 je 500 m
      final values = pm5Additional(
          [0x70, 0x17, 0x00, 0xA0, 0x0F, 32, 255, 0xD4, 0x30, 0, 0]);
      expect(values[Metric.speed], closeTo(14.4, 0.0001));
      expect(values[Metric.cadence], 32.0);
      expect(values.containsKey(Metric.heartRate), isFalse);
      // 2,80 / (125 s / 500 m)³ = 179,2 W
      expect(values[Metric.power], closeTo(179.2, 0.01));
    });

    test('Zusatzstatus: Stillstand ergibt 0 W statt einer Division durch 0',
        () {
      final values =
          pm5Additional([0, 0, 0, 0, 0, 0, 140, 0, 0, 0, 0]);
      expect(values[Metric.power], 0.0);
      expect(values[Metric.heartRate], 140.0);
    });
  });
}
