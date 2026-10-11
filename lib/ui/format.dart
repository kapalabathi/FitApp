import 'package:intl/intl.dart';

/// Anzeigeformate für Zeiten, Strecken und Daten.

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

final _km = NumberFormat('0.00', 'de');
final _oneDecimal = NumberFormat('0.0', 'de');

String formatKm(double meters) => _km.format(meters / 1000);

String formatDecimal(double value) => _oneDecimal.format(value);

/// Tempo als Minuten:Sekunden je [perMeters] Meter, z. B. je km oder je 500 m.
/// Gibt `null` zurück, wenn die Geschwindigkeit dafür zu klein ist.
String? formatPace(double? speedKmh, {int perMeters = 1000}) {
  if (speedKmh == null || speedKmh < 0.5) return null;
  final seconds = (perMeters / (speedKmh / 3.6)).round();
  return formatDuration(seconds);
}

final _date = DateFormat('EEE, d. MMM y', 'de');
final _time = DateFormat('HH:mm', 'de');

String formatDate(DateTime d) => _date.format(d);
String formatDateTime(DateTime d) => '${_date.format(d)}, ${_time.format(d)}';
