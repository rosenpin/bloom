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
        Row(
          children: <Widget>[
            Text(
              '${result.sessionCount} simulated sessions',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              'LOAD (${form.unitSystem.isMetric ? 'KG' : 'LB'})',
              style: const TextStyle(
                color: AppColors.inkFaint,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
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
                  sessionCount: result.sessionCount,
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

final class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    required this.points,
    required this.sessionCount,
    required this.unitSystem,
  });

  final List<JourneyPoint> points;
  final int sessionCount;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final hasLoad = points.first.hasExternalLoad;
    final values = <double>[
      for (final point in points) _displayValue(point.load, unitSystem),
    ];
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final latest = values.last;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final chart = SizedBox(
            height: 52,
            width: compact ? constraints.maxWidth : 270,
            child: hasLoad
                ? CustomPaint(
                    painter: _SparklinePainter(
                      points: points,
                      values: values,
                      sessionCount: sessionCount,
                    ),
                  )
                : const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Rep / duration progression · no external load',
                      style: TextStyle(
                        color: AppColors.inkFaint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
          );
          final details = SizedBox(
            width: compact ? constraints.maxWidth : 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  points.first.exerciseName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  hasLoad
                      ? '${_number(minValue)} → ${_number(maxValue)} · latest ${_number(latest)}'
                      : '${points.length} exposures',
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ],
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[details, const SizedBox(height: 8), chart],
            );
          }
          return Row(
            children: <Widget>[
              details,
              const SizedBox(width: 14),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: chart),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.points,
    required this.values,
    required this.sessionCount,
  });

  final List<JourneyPoint> points;
  final List<double> values;
  final int sessionCount;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 4.0;
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final range = maximum - minimum;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x =
          padding +
          (points[index].session - 1) /
              math.max(1, sessionCount - 1) *
              (size.width - padding * 2);
      final normalized = range == 0 ? 0.5 : (values[index] - minimum) / range;
      final y =
          size.height - padding - normalized * (size.height - padding * 2);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.roseDeep
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (var index = 0; index < points.length; index++) {
      final x =
          padding +
          (points[index].session - 1) /
              math.max(1, sessionCount - 1) *
              (size.width - padding * 2);
      final normalized = range == 0 ? 0.5 : (values[index] - minimum) / range;
      final y =
          size.height - padding - normalized * (size.height - padding * 2);
      canvas.drawCircle(Offset(x, y), 2.1, Paint()..color = AppColors.coral);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.values != values ||
      oldDelegate.sessionCount != sessionCount;
}

double _displayValue(Kg load, UnitSystem unitSystem) =>
    unitSystem.isMetric ? load.value : load.inLb;

String _number(double value) {
  final rounded = value.roundToDouble();
  return value == rounded
      ? rounded.toInt().toString()
      : value.toStringAsFixed(1);
}
