import 'byte_reader.dart';

/// Ein Messwert des Bluetooth-Herzfrequenzprofils (Merkmal 0x2A37).
class HeartRateSample {
  const HeartRateSample({
    required this.bpm,
    this.sensorContact,
    this.rrIntervalsMs = const [],
  });

  final int bpm;

  /// `null`, wenn der Sensor keinen Hautkontakt meldet oder melden kann.
  final bool? sensorContact;

  /// Abstände zwischen den Herzschlägen in Millisekunden.
  final List<int> rrIntervalsMs;

  static HeartRateSample parse(List<int> bytes) {
    final r = ByteReader(bytes);
    final flags = r.u8();
    final bpm = (flags & 0x01) != 0 ? r.u16() : r.u8();
    final contactSupported = (flags & 0x04) != 0;
    final contact = contactSupported ? (flags & 0x02) != 0 : null;
    if ((flags & 0x08) != 0) r.skip(2); // verbrauchte Energie
    final rr = <int>[];
    if ((flags & 0x10) != 0) {
      while (r.remaining >= 2) {
        rr.add((r.u16() * 1000 / 1024).round());
      }
    }
    return HeartRateSample(bpm: bpm, sensorContact: contact, rrIntervalsMs: rr);
  }
}
