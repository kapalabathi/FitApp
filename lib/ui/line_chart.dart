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
    required this.values,
    required this.color,
  });

  final String title;
  final List<double?> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return const SizedBox.shrink();
    final min = present.reduce((a, b) => a < b ? a : b);
    final max = present.reduce((a, b) => a > b ? a : b);
    final avg = present.reduce((a, b) => a + b) / present.length;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            Text(
              'Ø ${formatDecimal(avg)}  ·  max ${formatDecimal(max)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(
            painter: _LinePainter(
              values: values,
              min: min,
              max: max,
              line: color,
              grid: theme.colorScheme.outlineVariant,
            ),
          ),
        ),
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
    required this.line,
    required this.grid,
  });

  final List<double?> values;
  final double min;
  final double max;
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
    double yOf(double v) => span == 0
        ? size.height / 2
        : size.height - (v - min) / span * size.height;
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
      old.values != values || old.line != line || old.grid != grid;
}
