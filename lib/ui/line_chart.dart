import 'package:flutter/material.dart';

import 'format.dart';

/// Verlaufskurve einer Messgröße über die Trainingszeit.
///
/// [values] enthält einen Wert je Sekunde; `null` steht für eine Lücke und
/// unterbricht die Linie.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.title,
    required this.unit,
    required this.values,
    required this.color,
    this.format,
    this.lowerIsBetter = false,
    this.average,
  });

  final String title;

  /// Einheit der Werte, z. B. „km/h"; steht an Achse und Durchschnitt.
  final String unit;
  final List<double?> values;
  final Color color;

  /// Wie ein Wert geschrieben wird; ohne Angabe mit einer Nachkommastelle.
  final String Function(double value)? format;

  /// Bei Zeiten wie der Pace ist der kleinere Wert der bessere. Dann steht
  /// er oben, damit „schneller" in der Kurve nach oben zeigt.
  final bool lowerIsBetter;

  /// Der Mittelwert, wenn er sich nicht als Mittel der Einzelwerte ergibt.
  final double? average;

  @override
  Widget build(BuildContext context) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return const SizedBox.shrink();
    final min = present.reduce((a, b) => a < b ? a : b);
    final max = present.reduce((a, b) => a > b ? a : b);
    final avg = average ?? present.reduce((a, b) => a + b) / present.length;
    final theme = Theme.of(context);
    String withUnit(double v) =>
        '${(format ?? formatDecimal)(v)} $unit'.trim();
    final top = lowerIsBetter ? min : max;
    final bottom = lowerIsBetter ? max : min;
    final axisStyle = theme.textTheme.labelSmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            Text('Ø ${withUnit(avg)}', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        // Die Werte der oberen und unteren Linie, mit Einheit.
        Text('${lowerIsBetter ? 'min' : 'max'} ${withUnit(top)}',
            style: axisStyle),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(
            painter: _LinePainter(
              values: values,
              min: min,
              max: max,
              inverted: lowerIsBetter,
              line: color,
              grid: theme.colorScheme.outlineVariant,
            ),
          ),
        ),
        Text('${lowerIsBetter ? 'max' : 'min'} ${withUnit(bottom)}',
            style: axisStyle),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0:00', style: theme.textTheme.bodySmall),
            Text(formatDuration(values.length),
                style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.min,
    required this.max,
    required this.inverted,
    required this.line,
    required this.grid,
  });

  final List<double?> values;
  final double min;
  final double max;

  /// Der kleinste Wert liegt oben statt unten.
  final bool inverted;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Bei konstanten Werten liegt die Linie in der Mitte statt am Rand.
    final span = max - min;
    double yOf(double v) {
      if (span == 0) return size.height / 2;
      final fromBottom = (v - min) / span * size.height;
      return inverted ? fromBottom : size.height - fromBottom;
    }
    final dx = values.length > 1 ? size.width / (values.length - 1) : 0.0;

    final path = Path();
    var penDown = false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        penDown = false;
        continue;
      }
      final point = Offset(i * dx, yOf(v));
      if (penDown) {
        path.lineTo(point.dx, point.dy);
      } else {
        path.moveTo(point.dx, point.dy);
        penDown = true;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.inverted != inverted ||
      old.line != line ||
      old.grid != grid;
}
