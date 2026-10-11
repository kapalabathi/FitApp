import 'package:fitapp/ble/byte_reader.dart';
import 'package:fitapp/ble/device_kind.dart';
import 'package:fitapp/ble/ftms.dart';
import 'package:fitapp/ble/heart_rate.dart';
import 'package:fitapp/ble/uuids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Uuids', () {
    test('kurze und lange Schreibweise gelten als gleich', () {
      expect(
          Uuids.same('180D', '0000180d-0000-1000-8000-00805f9b34fb'), isTrue);
      expect(Uuids.same('180d', '1826'), isFalse);
      expect(Uuids.label('0000180d-0000-1000-8000-00805f9b34fb'),
          'Herzfrequenz');
    });
  });

  group('DeviceKind', () {
    test('erkennt Geräte an Dienst oder Name', () {
      expect(DeviceKind.detect('Gurt', ['180d']), DeviceKind.heartRate);
      expect(
          DeviceKind.detect('Domyos', ['00001826-0000-1000-8000-00805f9b34fb']),
          DeviceKind.fitnessMachine);
      expect(DeviceKind.detect('PM5 430123456', []), DeviceKind.concept2);
      expect(DeviceKind.detect(null, []), DeviceKind.unknown);
    });
  });

  group('HeartRateSample', () {
    test('8-Bit-Puls ohne Zusatzfelder', () {
      final s = HeartRateSample.parse([0x00, 72]);
      expect(s.bpm, 72);
      expect(s.sensorContact, isNull);
      expect(s.rrIntervalsMs, isEmpty);
    });

    test('16-Bit-Puls, Kontakt, Energie und RR-Intervalle', () {
      // Flags: 16 Bit, Kontakt unterstützt und erkannt, Energie, RR
      final s = HeartRateSample.parse(
          [0x1F, 0x2C, 0x01, 0x10, 0x00, 0x00, 0x04, 0x00, 0x02]);
      expect(s.bpm, 300);
      expect(s.sensorContact, isTrue);
      expect(s.rrIntervalsMs, [1000, 500]);
    });

    test('abgeschnittenes Paket wird abgelehnt', () {
      expect(() => HeartRateSample.parse([0x01, 72]), throwsFormatException);
    });
  });

  group('FtmsFeatures', () {
    test('liest Mess- und Steuerfähigkeiten', () {
      // Messen: Bit 2 (Distanz), 3 (Steigung), 12 (Zeit)
      // Steuern: Bit 0 (Geschwindigkeit), 1 (Steigung)
      final f = FtmsFeatures.parse(
          [0x0C, 0x10, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00]);
      expect(f.machineFeatures,
          ['Gesamtdistanz', 'Steigung', 'Verstrichene Zeit']);
      expect(f.targetSettings, ['Zielgeschwindigkeit', 'Zielsteigung']);
      expect(f.canSetSpeed, isTrue);
      expect(f.canSetResistance, isFalse);
    });
  });

  group('FtmsRange', () {
    test('Geschwindigkeit in km/h', () {
      // 1,00 bis 16,00 km/h, Schritt 0,10
      final r = FtmsRange.parseSpeed([0x64, 0x00, 0x40, 0x06, 0x0A, 0x00]);
      expect(r.min, 1.0);
      expect(r.max, 16.0);
      expect(r.step, 0.1);
    });

    test('Steigung darf negativ sein', () {
      // -3,0 bis 12,0 %, Schritt 0,5
      final r =
          FtmsRange.parseInclination([0xE2, 0xFF, 0x78, 0x00, 0x05, 0x00]);
      expect(r.min, -3.0);
      expect(r.max, 12.0);
      expect(r.step, 0.5);
    });
  });

  group('TreadmillData', () {
    test('Geschwindigkeit, Distanz, Steigung, Zeit', () {
      // Flags 0x040C: Distanz, Steigung, verstrichene Zeit
      final d = TreadmillData.parse([
        0x0C, 0x04, //
        0x52, 0x03, // 8,50 km/h
        0xD2, 0x04, 0x00, // 1234 m
        0x0F, 0x00, 0x00, 0x00, // 1,5 % und Rampenwinkel
        0x2C, 0x01, // 300 s
      ]);
      expect(d.speedKmh, 8.5);
      expect(d.totalDistanceM, 1234);
      expect(d.inclinationPercent, 1.5);
      expect(d.elapsedSeconds, 300);
      expect(d.heartRate, isNull);
    });

    test('gesetztes Bit 0 heißt: keine Geschwindigkeit im Paket', () {
      // Flags 0x0101: mehr Daten folgen, Herzfrequenz
      final d = TreadmillData.parse([0x01, 0x01, 0x8C]);
      expect(d.speedKmh, isNull);
      expect(d.heartRate, 140);
    });

    test('nicht verfügbare Energie wird zu null', () {
      // Flags 0x0080: Energie
      final d = TreadmillData.parse(
          [0x80, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
      expect(d.speedKmh, 0);
      expect(d.totalEnergyKcal, isNull);
    });
  });

  group('IndoorBikeData', () {
    test('Geschwindigkeit, Trittfrequenz, Widerstand, Leistung', () {
      // Flags 0x0064: Trittfrequenz, Widerstand, Leistung
      final d = IndoorBikeData.parse([
        0x64, 0x00, //
        0xC4, 0x09, // 25,00 km/h
        0xB4, 0x00, // 90 1/min
        0x08, 0x00, // Stufe 8
        0x96, 0x00, // 150 W
      ]);
      expect(d.speedKmh, 25.0);
      expect(d.cadenceRpm, 90.0);
      expect(d.resistanceLevel, 8);
      expect(d.powerWatt, 150);
      expect(d.totalDistanceM, isNull);
    });

    test('abgeschnittenes Paket wird abgelehnt', () {
      expect(() => IndoorBikeData.parse([0x64, 0x00, 0xC4, 0x09]),
          throwsFormatException);
    });
  });

  test('hex formatiert Bytes zweistellig', () {
    expect(hex([0, 10, 255]), '00 0a ff');
  });
}
