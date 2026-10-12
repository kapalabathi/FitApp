import 'package:flutter/material.dart';

import 'format.dart';

/// Verlaufskurve einer Messgröße über die Trainingszeit.
///
/// [values] enthält einen Wert je Sekunde; `null` steht für eine Lücke und
/// unterbricht die Linie.
///
/// Mit [position] lässt sich die Kurve abfahren: Der Schieber unter der Kurve
/// oder ein Tipp in die Kurve wählt eine Stelle, und darüber stehen Zeit und
/// Wert an dieser Stelle. Mehrere Kurven mit derselben [position] bewegen
/// sich gemeinsam.
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
    this.position,
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

  /// Die gewählte Stelle als Sekunde ab 0, oder `null`, wenn keine gewählt
  /// ist. Ohne Angabe hat die Kurve keinen Schieber.
  final ValueNotifier<int?>? position;

  @override
  Widget build(BuildContext context) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return const SizedBox.shrink();
    final min = present.reduce((a, b) => a < b ? a : b);
    final max = present.reduce((a, b) => a > b ? a : b);
    final avg = average ?? present.reduce((a, b) => a + b) / present.length;
    final theme = Theme.of(context);
    String withUnit(double v) => '${(format ?? formatDecimal)(v)} $unit'.trim();
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final position = this.position;
    if (position != null) {
      return ValueListenableBuilder<int?>(
        valueListenable: position,
        builder: (context, at, _) => _layout(
          theme: theme,
          axisStyle: axisStyle,
          withUnit: withUnit,
          min: min,
          max: max,
          avg: avg,
          at: at?.clamp(0, values.length - 1),
        ),
      );
    }
    return _layout(
      theme: theme,
      axisStyle: axisStyle,
      withUnit: withUnit,
      min: min,
      max: max,
      avg: avg,
      at: null,
    );
  }

  Widget _layout({
    required ThemeData theme,
    required TextStyle? axisStyle,
    required String Function(double) withUnit,
    required double min,
    required double max,
    required double avg,
    required int? at,
  }) {
    final top = lowerIsBetter ? min : max;
    final bottom = lowerIsBetter ? max : min;
    final position = this.position;
    final valueAt = at == null ? null : values[at];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            Text('Ø ${withUnit(avg)}', style: theme.textTheme.bodySmall),
          ],
        ),
        if (at != null)
          // Zeit und Wert an der gewählten Stelle
          Text(
            'bei ${formatDuration(at + 1)}:  '
            '${valueAt == null ? 'kein Wert' : withUnit(valueAt)}',
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        const SizedBox(height: 4),
        // Die Werte der oberen und unteren Linie, mit Einheit.
        Text(
          '${lowerIsBetter ? 'min' : 'max'} ${withUnit(top)}',
          style: axisStyle,
        ),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) {
              final painted = CustomPaint(
                size: Size(box.maxWidth, 120),
                painter: _LinePainter(
                  values: values,
                  min: min,
                  max: max,
                  inverted: lowerIsBetter,
                  line: color,
                  grid: theme.colorScheme.outlineVariant,
                  cursor: at,
                  cursorColor: theme.colorScheme.onSurface,
                ),
              );
              if (position == null) return painted;
              // Ein Tipp oder Wischen in der Kurve wählt die Stelle darunter.
              void select(Offset local) {
                final share = (local.dx / box.maxWidth).clamp(0.0, 1.0);
                position.value = (share * (values.length - 1)).round();
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => select(d.localPosition),
                onHorizontalDragStart: (d) => select(d.localPosition),
                onHorizontalDragUpdate: (d) => select(d.localPosition),
                child: painted,
              );
            },
          ),
        ),
        Text(
          '${lowerIsBetter ? 'max' : 'min'} ${withUnit(bottom)}',
          style: axisStyle,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0:00', style: theme.textTheme.bodySmall),
            Text(
              formatDuration(values.length),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        if (position != null && values.length > 1)
          Slider(
            min: 0,
            max: (values.length - 1).toDouble(),
            value: (at ?? 0).toDouble(),
            label: at == null ? null : formatDuration(at + 1),
            onChanged: (v) => position.value = v.round(),
          ),
      ],
    );
  }
}

/// Eine kleine Kurve für die Trainingsansicht: der Verlauf der letzten
/// Minuten mit dem aktuellen Wert und den Grenzen des Ausschnitts.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.title,
    required this.unit,
    required this.values,
    required this.color,
    this.format,
    this.lowerIsBetter = false,
  });

  final String title;
  final String unit;
  final List<double?> values;
  final Color color;
  final String Function(double value)? format;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = values.whereType<double>();
    final write = format ?? formatDecimal;
    if (present.isEmpty) return const SizedBox.shrink();
    final min = present.reduce((a, b) => a < b ? a : b);
    final max = present.reduce((a, b) => a > b ? a : b);
    final small = theme.textTheme.labelSmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('$title in $unit', style: small)),
            Text(
              '${write(lowerIsBetter ? max : min)} – '
              '${write(lowerIsBetter ? min : max)}',
              style: small,
            ),
          ],
        ),
        SizedBox(
          height: 44,
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
    this.cursor,
    this.cursorColor,
  });

  final List<double?> values;
  final double min;
  final double max;

  /// Der kleinste Wert liegt oben statt unten.
  final bool inverted;
  final Color line;
  final Color grid;

  /// Die gewählte Stelle; dort stehen eine senkrechte Linie und ein Punkt.
  final int? cursor;
  final Color? cursorColor;

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

    final at = cursor;
    if (at == null || at < 0 || at >= values.length) return;
    final x = at * dx;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = cursorColor ?? line
        ..strokeWidth = 1,
    );
    final value = values[at];
    if (value != null) {
      canvas.drawCircle(Offset(x, yOf(value)), 5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.cursor != cursor ||
      old.inverted != inverted ||
      old.line != line ||
      old.grid != grid;
}
