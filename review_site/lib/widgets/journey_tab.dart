import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart';

import '../models/journey_simulator.dart';
import '../models/review_form_state.dart';
import '../theme/app_colors.dart';
import 'ui_labels.dart';

final class JourneyTab extends StatelessWidget {
  const JourneyTab({
    required this.form,
    required this.weeks,
    required this.pattern,
    required this.result,
    required this.onWeeksChanged,
    required this.onPatternChanged,
    super.key,
  });

  final ReviewFormState form;
  final int weeks;
  final JourneyPattern pattern;
  final JourneyResult result;
  final ValueChanged<int> onWeeksChanged;
  final ValueChanged<JourneyPattern> onPatternChanged;

  @override
  Widget build(BuildContext context) {
    final series = result.series.entries.toList(growable: false)
      ..sort(
        (left, right) => left.value.first.exerciseName.compareTo(
          right.value.first.exerciseName,
        ),
      );
    final loadUnit = form.unitSystem.isMetric ? 'kg' : 'lb';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
      children: <Widget>[
        Text(
          'Progression journey',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Each point is a real resolveSession result after the scripted feel taps were folded into history.',
          style: TextStyle(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        Card(
          color: AppColors.blushSoft.withValues(alpha: 0.62),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 18,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 6, label: Text('6 weeks')),
                    ButtonSegment<int>(value: 12, label: Text('12 weeks')),
                  ],
                  selected: <int>{weeks},
                  onSelectionChanged: (selection) =>
                      onWeeksChanged(selection.single),
                ),
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<JourneyPattern>(
                    key: ValueKey<JourneyPattern>(pattern),
                    initialValue: pattern,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Scripted effort pattern',
                    ),
                    items: <DropdownMenuItem<JourneyPattern>>[
                      for (final value in JourneyPattern.values)
                        DropdownMenuItem<JourneyPattern>(
                          value: value,
                          child: Text(journeyPatternLabel(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onPatternChanged(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: Text(
                    journeyPatternDescription(pattern),
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              '${result.sessionCount} simulated sessions',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const _LineLegend(color: AppColors.roseDeep, label: 'Volume'),
            _LineLegend(
              color: AppColors.coral,
              label: 'Load ($loadUnit)',
              subtle: true,
            ),
            const _LineLegend(
              color: AppColors.lavender,
              label: 'Target reps / hold',
              subtle: true,
              dashed: true,
            ),
            const _ShadeLegend(
              color: AppColors.lavenderSoft,
              label: 'Easier · lighter on purpose',
            ),
            const _ShadeLegend(
              color: AppColors.sageSoft,
              label: 'Deload · lighter on purpose',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: <Widget>[
              for (var index = 0; index < series.length; index++) ...<Widget>[
                _SeriesRow(
                  points: series[index].value,
                  sessions: result.sessions,
                  unitSystem: form.unitSystem,
                ),
                if (index < series.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

final class _LineLegend extends StatelessWidget {
  const _LineLegend({
    required this.color,
    required this.label,
    this.subtle = false,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool subtle;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 22,
          height: 8,
          child: CustomPaint(
            painter: _LegendLinePainter(
              color: color,
              subtle: subtle,
              dashed: dashed,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.inkFaint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({
    required this.color,
    required this.subtle,
    required this.dashed,
  });

  final Color color;
  final bool subtle;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = subtle ? color.withValues(alpha: 0.66) : color
      ..strokeWidth = subtle ? 1.4 : 3
      ..strokeCap = StrokeCap.round;
    if (dashed) {
      _drawDashedSegment(
        canvas,
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.subtle != subtle ||
      oldDelegate.dashed != dashed;
}

final class _ShadeLegend extends StatelessWidget {
  const _ShadeLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.inkFaint, fontSize: 11),
        ),
      ],
    );
  }
}

final class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    required this.points,
    required this.sessions,
    required this.unitSystem,
  });

  final List<JourneyPoint> points;
  final List<JourneySession> sessions;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final hasLoad = points.first.hasExternalLoad;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          points.first.exerciseName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (!hasLoad) ...<Widget>[
          const SizedBox(height: 3),
          const Text(
            'No external load · volume is sets × reps / hold',
            style: TextStyle(
              color: AppColors.inkFaint,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          journeyProgressSummary(points, unitSystem),
          key: ValueKey<String>('journey-summary-${points.first.exerciseId}'),
          style: const TextStyle(color: AppColors.inkSoft, height: 1.35),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final chart = SizedBox(
            height: 126,
            child: _JourneyChart(
              points: points,
              sessions: sessions,
              hasLoad: hasLoad,
              unitSystem: unitSystem,
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[details, const SizedBox(height: 10), chart],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(width: 310, child: details),
              const SizedBox(width: 18),
              Expanded(child: chart),
            ],
          );
        },
      ),
    );
  }
}

final class _JourneyChart extends StatefulWidget {
  const _JourneyChart({
    required this.points,
    required this.sessions,
    required this.hasLoad,
    required this.unitSystem,
  });

  final List<JourneyPoint> points;
  final List<JourneySession> sessions;
  final bool hasLoad;
  final UnitSystem unitSystem;

  @override
  State<_JourneyChart> createState() => _JourneyChartState();
}

final class _JourneyChartState extends State<_JourneyChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void selectNearest(double dx) {
          final plot = _plotRect(
            Size(constraints.maxWidth, constraints.maxHeight),
          );
          var nearestIndex = 0;
          var nearestDistance = double.infinity;
          for (var index = 0; index < widget.points.length; index++) {
            final pointX = _xForSession(
              widget.points[index].session,
              widget.sessions.length,
              plot,
            );
            final distance = (pointX - dx).abs();
            if (distance < nearestDistance) {
              nearestIndex = index;
              nearestDistance = distance;
            }
          }
          if (_hoveredIndex != nearestIndex) {
            setState(() => _hoveredIndex = nearestIndex);
          }
        }

        final hovered = _hoveredIndex == null
            ? null
            : widget.points[_hoveredIndex!];
        return MouseRegion(
          onHover: (event) => selectNearest(event.localPosition.dx),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => selectNearest(details.localPosition.dx),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ProgressChartPainter(
                      points: widget.points,
                      sessions: widget.sessions,
                      hasLoad: widget.hasLoad,
                      unitSystem: widget.unitSystem,
                      hoveredPoint: hovered,
                    ),
                  ),
                ),
                if (hovered != null)
                  Positioned(
                    top: 0,
                    left: 49,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.paper.withValues(alpha: 0.94),
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        child: Text(
                          _pointTooltip(hovered, widget.unitSystem),
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _ProgressChartPainter extends CustomPainter {
  const _ProgressChartPainter({
    required this.points,
    required this.sessions,
    required this.hasLoad,
    required this.unitSystem,
    required this.hoveredPoint,
  });

  final List<JourneyPoint> points;
  final List<JourneySession> sessions;
  final bool hasLoad;
  final UnitSystem unitSystem;
  final JourneyPoint? hoveredPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size);
    _drawWeekShading(canvas, plot);
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1,
    );

    if (hasLoad) {
      final loadValues = <double>[
        for (final point in points) _displayValue(point.load, unitSystem),
      ];
      final loadOffsets = _offsets(loadValues, plot);
      final path = Path();
      for (var index = 0; index < loadOffsets.length; index++) {
        final offset = loadOffsets[index];
        if (index == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.coral.withValues(alpha: 0.58)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      for (final offset in loadOffsets) {
        canvas.drawCircle(
          offset,
          1.8,
          Paint()..color = AppColors.coral.withValues(alpha: 0.7),
        );
      }
    }

    final targetValues = <double>[
      for (final point in points) point.target.toDouble(),
    ];
    final targetOffsets = _offsets(targetValues, plot);
    final targetPaint = Paint()
      ..color = AppColors.lavender.withValues(alpha: 0.66)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var index = 1; index < targetOffsets.length; index++) {
      _drawDashedSegment(
        canvas,
        targetOffsets[index - 1],
        targetOffsets[index],
        targetPaint,
      );
    }
    for (final offset in targetOffsets) {
      canvas.drawCircle(
        offset,
        1.8,
        Paint()..color = AppColors.lavender.withValues(alpha: 0.72),
      );
    }
    _drawAxisLabels(
      canvas,
      plot,
      targetValues,
      side: _AxisSide.right,
      formatter: _number,
    );

    final volumeValues = <double>[
      for (final point in points) point.volume(unitSystem),
    ];
    final volumeOffsets = _offsets(volumeValues, plot);
    final volumePath = Path();
    for (var index = 0; index < volumeOffsets.length; index++) {
      final offset = volumeOffsets[index];
      if (index == 0) {
        volumePath.moveTo(offset.dx, offset.dy);
      } else {
        volumePath.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      volumePath,
      Paint()
        ..color = AppColors.roseDeep
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (final offset in volumeOffsets) {
      canvas.drawCircle(offset, 2.8, Paint()..color = AppColors.roseDeep);
    }
    _drawAxisLabels(
      canvas,
      plot,
      volumeValues,
      side: _AxisSide.left,
      formatter: _number,
    );

    final hovered = hoveredPoint;
    if (hovered != null) {
      final x = _xForSession(hovered.session, sessions.length, plot);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = AppColors.inkFaint.withValues(alpha: 0.48)
          ..strokeWidth = 1,
      );
    }
  }

  List<Offset> _offsets(List<double> values, Rect plot) {
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final range = maximum - minimum;
    return <Offset>[
      for (var index = 0; index < points.length; index++)
        Offset(
          _xForSession(points[index].session, sessions.length, plot),
          range == 0
              ? plot.center.dy
              : plot.bottom - (values[index] - minimum) / range * plot.height,
        ),
    ];
  }

  void _drawWeekShading(Canvas canvas, Rect plot) {
    var start = 0;
    while (start < sessions.length) {
      var end = start;
      while (end + 1 < sessions.length &&
          sessions[end + 1].absoluteWeek == sessions[start].absoluteWeek) {
        end++;
      }
      final kind = sessions[start].weekKind;
      final color = switch (kind) {
        MesocycleWeekKind.easier => AppColors.lavenderSoft,
        MesocycleWeekKind.deload => AppColors.sageSoft,
        MesocycleWeekKind.build || MesocycleWeekKind.push => null,
      };
      if (color != null) {
        final firstX = _xForSession(
          sessions[start].session,
          sessions.length,
          plot,
        );
        final lastX = _xForSession(
          sessions[end].session,
          sessions.length,
          plot,
        );
        final left = start == 0
            ? plot.left
            : (firstX +
                      _xForSession(
                        sessions[start - 1].session,
                        sessions.length,
                        plot,
                      )) /
                  2;
        final right = end == sessions.length - 1
            ? plot.right
            : (lastX +
                      _xForSession(
                        sessions[end + 1].session,
                        sessions.length,
                        plot,
                      )) /
                  2;
        canvas.drawRect(
          Rect.fromLTRB(left, plot.top, right, plot.bottom),
          Paint()..color = color.withValues(alpha: 0.72),
        );
      }
      if (end < sessions.length - 1) {
        final boundary =
            (_xForSession(sessions[end].session, sessions.length, plot) +
                _xForSession(
                  sessions[end + 1].session,
                  sessions.length,
                  plot,
                )) /
            2;
        canvas.drawLine(
          Offset(boundary, plot.top),
          Offset(boundary, plot.bottom),
          Paint()
            ..color = AppColors.line.withValues(alpha: 0.72)
            ..strokeWidth = 0.8,
        );
      }
      start = end + 1;
    }
  }

  @override
  bool shouldRepaint(_ProgressChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.sessions != sessions ||
      oldDelegate.hasLoad != hasLoad ||
      oldDelegate.unitSystem != unitSystem ||
      oldDelegate.hoveredPoint != hoveredPoint;
}

enum _AxisSide { left, right }

void _drawAxisLabels(
  Canvas canvas,
  Rect plot,
  List<double> values, {
  required _AxisSide side,
  required String Function(double) formatter,
}) {
  final minimum = values.reduce(math.min);
  final maximum = values.reduce(math.max);
  if (minimum == maximum) {
    _drawAxisLabel(canvas, formatter(minimum), plot.center.dy, plot, side);
    return;
  }
  _drawAxisLabel(canvas, formatter(maximum), plot.top, plot, side);
  _drawAxisLabel(canvas, formatter(minimum), plot.bottom, plot, side);
}

void _drawAxisLabel(
  Canvas canvas,
  String text,
  double centerY,
  Rect plot,
  _AxisSide side,
) {
  final painter =
      TextPainter(
          text: const TextSpan(
            style: TextStyle(color: AppColors.inkFaint, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )
        ..text = TextSpan(
          text: text,
          style: const TextStyle(color: AppColors.inkFaint, fontSize: 9),
        );
  painter.layout();
  final x = switch (side) {
    _AxisSide.left => plot.left - painter.width - 5,
    _AxisSide.right => plot.right + 5,
  };
  painter.paint(canvas, Offset(x, centerY - painter.height / 2));
}

Rect _plotRect(Size size) =>
    Rect.fromLTRB(46, 22, size.width - 42, size.height - 14);

double _xForSession(int session, int sessionCount, Rect plot) =>
    plot.left + (session - 1) / math.max(1, sessionCount - 1) * plot.width;

void _drawDashedSegment(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dashLength = 4.0;
  const gapLength = 3.0;
  final delta = end - start;
  final distance = delta.distance;
  if (distance == 0) return;
  final direction = delta / distance;
  var traveled = 0.0;
  while (traveled < distance) {
    final dashEnd = math.min(traveled + dashLength, distance);
    canvas.drawLine(
      start + direction * traveled,
      start + direction * dashEnd,
      paint,
    );
    traveled += dashLength + gapLength;
  }
}

String _pointTooltip(JourneyPoint point, UnitSystem unitSystem) {
  final parts = <String>[
    'Session ${point.session}',
    'week ${point.absoluteWeek}',
    'volume ${_number(point.volume(unitSystem))}',
    '${point.sets} sets',
  ];
  if (point.hasExternalLoad) {
    parts.add(
      '${_number(_displayValue(point.load, unitSystem))} '
      '${unitSystem.isMetric ? 'kg' : 'lb'}',
    );
  }
  parts.add(
    point.targetKind == JourneyTargetKind.hold
        ? '${point.target} sec hold'
        : '${point.target} reps',
  );
  return parts.join(' · ');
}

String journeyProgressSummary(
  List<JourneyPoint> points,
  UnitSystem unitSystem,
) {
  assert(points.isNotEmpty);
  final volumeValues = <double>[
    for (final point in points) point.volume(unitSystem),
  ];
  final volumeStart = volumeValues.first;
  final volumePeak = volumeValues.reduce(math.max);
  final volumeLatest = volumeValues.last;
  final volume = StringBuffer(
    'volume ${_number(volumeStart)} -> ${_number(volumePeak)} (peak)',
  );
  if (!_sameNumber(volumeLatest, volumePeak)) {
    volume.write(' · latest ${_number(volumeLatest)}');
  }

  final details = <String>[];
  if (points.first.hasExternalLoad) {
    final values = <double>[
      for (final point in points) _displayValue(point.load, unitSystem),
    ];
    final start = values.first;
    final peak = values.reduce(math.max);
    final unit = unitSystem.isMetric ? 'kg' : 'lb';
    details.add('load ${_number(start)} -> ${_number(peak)} $unit');
  }

  final targetValues = <int>[for (final point in points) point.target];
  final targetStart = targetValues.first;
  final targetPeak = targetValues.reduce(math.max);
  final isHold = points.first.targetKind == JourneyTargetKind.hold;
  final targetLabel = isHold ? 'hold' : 'reps';
  final targetUnit = isHold ? ' sec' : '';
  details.add('$targetLabel $targetStart -> $targetPeak$targetUnit');

  switch (points.last.weekKind) {
    case MesocycleWeekKind.easier:
      details.add('ends in easier week');
    case MesocycleWeekKind.deload:
      details.add('ends in deload week');
    case MesocycleWeekKind.build:
    case MesocycleWeekKind.push:
      break;
  }
  return '$volume\n${details.join(' · ')}';
}

double _displayValue(Kg load, UnitSystem unitSystem) =>
    unitSystem.isMetric ? load.value : load.inLb;

bool _sameNumber(double left, double right) => (left - right).abs() < 0.001;

String _number(double value) {
  final rounded = value.roundToDouble();
  return value == rounded
      ? rounded.toInt().toString()
      : value.toStringAsFixed(1);
}
