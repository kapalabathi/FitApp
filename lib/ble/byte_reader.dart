import 'dart:typed_data';

/// Liest Little-Endian-Werte der Reihe nach aus einem Bluetooth-Paket.
///
/// Reicht das Paket nicht, wirft der Leser eine [FormatException]; so fällt
/// ein abgeschnittenes oder falsch verstandenes Paket auf, statt falsche
/// Werte zu liefern.
class ByteReader {
  ByteReader(List<int> bytes)
      : _data = ByteData.sublistView(Uint8List.fromList(bytes));

  final ByteData _data;
  int _pos = 0;

  int get remaining => _data.lengthInBytes - _pos;

  int _take(int n) {
    if (remaining < n) {
      throw FormatException(
          'Paket zu kurz: $n Byte ab Position $_pos erwartet, $remaining vorhanden');
    }
    final at = _pos;
    _pos += n;
    return at;
  }

  int u8() => _data.getUint8(_take(1));
  int u16() => _data.getUint16(_take(2), Endian.little);
  int s16() => _data.getInt16(_take(2), Endian.little);
  int u32() => _data.getUint32(_take(4), Endian.little);

  int u24() {
    final at = _take(3);
    return _data.getUint8(at) |
        (_data.getUint8(at + 1) << 8) |
        (_data.getUint8(at + 2) << 16);
  }

  void skip(int n) => _take(n);
}

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
