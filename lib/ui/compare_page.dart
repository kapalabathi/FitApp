import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../stats/compare.dart';
import 'format.dart';

/// Legt mehrere Trainings als Kurven übereinander, etwa alle Durchgänge
/// desselben Workouts.
class ComparePage extends StatefulWidget {
  const ComparePage({
    super.key,
    required this.db,
    required this.workouts,
    this.title = 'Vergleich',
  });

  final AppDatabase db;

  /// Die Trainings, neueste zuerst.
  final List<Workout> workouts;
  final String title;

  /// Mehr Durchgänge lädt die Seite nicht.
  static const maxWorkouts = 30;

  /// So viele Kurven sind am Anfang sichtbar; mehr wird unübersichtlich.
  static const initiallyVisible = 8;

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  static const _colors = [
    Color(0xFFE57373),
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFF4DB6AC),
    Color(0xFFF06292),
    Color(0xFFAED581),
    Color(0xFF7986CB),
    Color(0xFFA1887F),
  ];

  late final List<Workout> _workouts =
      widget.workouts.take(ComparePage.maxWorkouts).toList();
  late final Map<int, List<Sample>> _samples = {
    for (final w in _workouts) w.id: widget.db.samples(w.id),
  };
  late final Set<int> _visible =
      _workouts.take(ComparePage.initiallyVisible).map((w) => w.id).toSet();

  late CompareMetric _metric = _metrics.firstOrNull ?? CompareMetric.heartRate;
  CompareAxis _axis = CompareAxis.time;

  /// Die gewählte Stelle als Sekunde oder Meter.
  double? _cursor;

  List<CompareMetric> get _metrics => [
        for (final m in CompareMetric.values)
          if (_samples.values.any((s) => s.any((x) => m.of(x) != null))) m,
      ];

  bool get _hasDistance =>
      _workouts.every((w) => w.distanceM > 0) && _workouts.isNotEmpty;

  Color _colorOf(int index) => _colors[index % _colors.length];

  String _write(double v) => _metric == CompareMetric.pace
      ? formatDuration(v.round())
      : v.round().toString();

  String _writeX(double x) => _axis == CompareAxis.time
      ? formatDuration(x.round())
      : '${formatKm(x)} km';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _metrics;
    final curves = {
      for (final w in _workouts)
        w.id: compareCurve(_samples[w.id]!, _metric, _axis),
    };
    final shown = [
      for (var i = 0; i < _workouts.length; i++)
        if (_visible.contains(_workouts[i].id) &&
            !curves[_workouts[i].id]!.isEmpty)
          (curve: curves[_workouts[i].id]!, color: _colorOf(i), newest: i == 0),
    ];
    final cursor = _cursor;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (metrics.isEmpty)
            const Text('Diese Trainings enthalten keine Messwerte.')
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in metrics)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: m == _metric,
                    onSelected: (_) => setState(() => _metric = m),
                  ),
              ],
            ),
            if (_hasDistance) ...[
              const SizedBox(height: 8),
              SegmentedButton<CompareAxis>(
                segments: [
                  for (final a in CompareAxis.values)
                    ButtonSegment(value: a, label: Text(a.label)),
                ],
                selected: {_axis},
                onSelectionChanged: (s) => setState(() {
                  _axis = s.first;
                  _cursor = null;
                }),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              cursor == null
                  ? '${_metric.label} in ${_metric.unit}'
                  : 'bei ${_writeX(cursor)}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _CompareChart(
              curves: shown,
              lowerIsBetter: _metric.lowerIsBetter,
              cursor: cursor,
              write: _write,
              writeX: _writeX,
              onSelect: (x) => setState(() => _cursor = x),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_workouts.length} Durchgänge'
                  '${widget.workouts.length > _workouts.length ? ', die neuesten' : ''}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  final all = _visible.length == _workouts.length;
                  _visible.clear();
                  if (!all) _visible.addAll(_workouts.map((w) => w.id));
                }),
                child: Text(_visible.length == _workouts.length
                    ? 'Alle aus'
                    : 'Alle an'),
              ),
            ],
          ),
          for (var i = 0; i < _workouts.length; i++)
            _legendRow(i, curves[_workouts[i].id]!, cursor),
        ],
      ),
    );
  }

  Widget _legendRow(int index, CompareCurve curve, double? cursor) {
    final w = _workouts[index];
    final at = cursor == null ? null : curve.at(cursor);
    final average = curve.average;
    final value = cursor != null
        ? (at == null ? '–' : '${_write(at)} ${_metric.unit}')
        : average == null
            ? 'keine Werte'
            : 'Ø ${_write(average)} ${_metric.unit}';
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: _colorOf(index),
      value: _visible.contains(w.id),
      onChanged: (on) => setState(
          () => on == true ? _visible.add(w.id) : _visible.remove(w.id)),
      title: Text(formatDateTime(w.startedAt)),
      subtitle: Text([
        formatDuration(w.durationS),
        if (w.distanceM > 0) '${formatKm(w.distanceM)} km',
      ].join('  ·  ')),
      secondary: Text(value),
    );
  }
}

typedef _ShownCurve = ({CompareCurve curve, Color color, bool newest});

class _CompareChart extends StatelessWidget {
  const _CompareChart({
    required this.curves,
    required this.lowerIsBetter,
    required this.cursor,
    required this.write,
    required this.writeX,
    required this.onSelect,
  });

  final List<_ShownCurve> curves;
  final bool lowerIsBetter;
  final double? cursor;
  final String Function(double) write;
  final String Function(double) writeX;
  final void Function(double) onSelect;

  static const _height = 240.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = [
      for (final c in curves) ...c.curve.values.whereType<double>(),
    ];
    if (present.isEmpty) {
      return const SizedBox(
        height: _height,
        child: Center(child: Text('Keine Kurve ausgewählt.')),
      );
    }
    final min = present.reduce((a, b) => a < b ? a : b);
    final max = present.reduce((a, b) => a > b ? a : b);
    final end = curves.map((c) => c.curve.end).reduce((a, b) => a > b ? a : b);
    final axis = theme.textTheme.labelSmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(write(lowerIsBetter ? min : max), style: axis),
        SizedBox(
          height: _height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) {
              void select(Offset local) => onSelect(
                  (local.dx / box.maxWidth).clamp(0.0, 1.0) * end);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => select(d.localPosition),
                onHorizontalDragStart: (d) => select(d.localPosition),
                onHorizontalDragUpdate: (d) => select(d.localPosition),
                child: CustomPaint(
                  size: Size(box.maxWidth, _height),
                  painter: _ComparePainter(
                    curves: curves,
                    min: min,
                    max: max,
                    end: end,
                    inverted: lowerIsBetter,
                    grid: theme.colorScheme.outlineVariant,
                    cursor: cursor,
                    cursorColor: theme.colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
        ),
        Text(write(lowerIsBetter ? max : min), style: axis),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(writeX(0), style: axis),
            Text(writeX(end), style: axis),
          ],
        ),
      ],
    );
  }
}

class _ComparePainter extends CustomPainter {
  _ComparePainter({
    required this.curves,
    required this.min,
    required this.max,
    required this.end,
    required this.inverted,
    required this.grid,
    required this.cursor,
    required this.cursorColor,
  });

  final List<_ShownCurve> curves;
  final double min;
  final double max;
  final double end;
  final bool inverted;
  final Color grid;
  final double? cursor;
  final Color cursorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final span = max - min;
    double yOf(double v) {
      if (span == 0) return size.height / 2;
      final fromBottom = (v - min) / span * size.height;
      return inverted ? fromBottom : size.height - fromBottom;
    }

    double xOf(double x) => end == 0 ? 0 : x / end * size.width;

    // Das neueste Training liegt obenauf und ist kräftiger.
    for (final c in curves.reversed) {
      final path = Path();
      var penDown = false;
      for (var i = 0; i < c.curve.values.length; i++) {
        final v = c.curve.values[i];
        if (v == null) {
          penDown = false;
          continue;
        }
        final point = Offset(xOf(i * c.curve.step), yOf(v));
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
          ..color = c.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = c.newest ? 3 : 1.5
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final at = cursor;
    if (at == null) return;
    final x = xOf(at);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = cursorColor
        ..strokeWidth = 1,
    );
    for (final c in curves) {
      final v = c.curve.at(at);
      if (v != null) canvas.drawCircle(Offset(x, yOf(v)), 4, Paint()..color = c.color);
    }
  }

  @override
  bool shouldRepaint(_ComparePainter old) => true;
}
