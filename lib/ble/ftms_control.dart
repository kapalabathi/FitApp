import '../interval/interval_models.dart';

/// Befehle und Antworten der FTMS-Steuerung (Merkmal 0x2AD9).

/// Bittet das Gerät um die Erlaubnis, es zu steuern. Muss einmal je
/// Verbindung vor dem ersten Zielwert gesendet werden.
const List<int> ftmsRequestControl = [0x00];

/// Der Befehl, der [value] als Zielwert setzt, oder `null`, wenn [kind]
/// keinen Zielwert hat.
List<int>? ftmsSetTarget(TargetKind kind, double value) {
  List<int> u16(int opCode, int v) =>
      [opCode, v & 0xFF, (v >> 8) & 0xFF];

  return switch (kind) {
    TargetKind.none => null,
    // km/h in Hundertsteln
    TargetKind.speed => u16(0x02, (value * 100).round().clamp(0, 0xFFFF)),
    // Stufe in Zehnteln, ein Byte
    TargetKind.resistance => [0x04, (value * 10).round().clamp(0, 0xFF)],
    // Watt, vorzeichenbehaftet
    TargetKind.power => u16(0x05, value.round().clamp(-0x8000, 0x7FFF)),
  };
}

/// Die Antwort des Geräts auf einen Befehl.
class FtmsResponse {
  const FtmsResponse(this.requestOpCode, this.resultCode);

  final int requestOpCode;
  final int resultCode;

  bool get success => resultCode == 0x01;

  String get message => switch (resultCode) {
        0x01 => 'ausgeführt',
        0x02 => 'vom Gerät nicht unterstützt',
        0x03 => 'Wert außerhalb des erlaubten Bereichs',
        0x04 => 'fehlgeschlagen',
        0x05 => 'Steuerung vom Gerät nicht erlaubt',
        _ => 'unbekannte Antwort $resultCode',
      };

  /// `null`, wenn [bytes] keine Antwort auf einen Befehl ist.
  static FtmsResponse? parse(List<int> bytes) =>
      bytes.length >= 3 && bytes[0] == 0x80
          ? FtmsResponse(bytes[1], bytes[2])
          : null;
}
