import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';

class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.today,
    required this.completedAt,
    required this.plannedWeekdays,
    super.key,
  });

  final DateTime today;
  final Iterable<DateTime> completedAt;
  final Set<int> plannedWeekdays;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final completedWeekdays = {
      for (final completedDate in completedAt) completedDate.weekday,
    };

    return Row(
      key: const ValueKey('week-strip'),
      children: [
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        ) ...[
          if (weekday > DateTime.monday) const SizedBox(width: 6),
          Expanded(
            child: _WeekDay(
              weekday: weekday,
              letter: _dayLetters[weekday - 1],
              name: _dayNames[weekday - 1],
              isToday: weekday == today.weekday,
              isDone: completedWeekdays.contains(weekday),
              isPlanned: plannedWeekdays.contains(weekday),
              isFuture: weekday > today.weekday,
            ),
          ),
        ],
      ],
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.weekday,
    required this.letter,
    required this.name,
    required this.isToday,
    required this.isDone,
    required this.isPlanned,
    required this.isFuture,
  });

  final int weekday;
  final String letter;
  final String name;
  final bool isToday;
  final bool isDone;
  final bool isPlanned;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final isFuturePlanned = isFuture && isPlanned;
    final backgroundColor = isToday
        ? isDone
              ? AppColors.sageSoft
              : AppColors.blushSoft
        : Colors.transparent;
    final dotColor = isDone
        ? AppColors.sage
        : isToday && isPlanned
        ? AppColors.rose
        : isFuturePlanned
        ? AppColors.blush
        : AppColors.line;
    final semanticsLabel = switch ((
      isDone,
      isToday,
      isPlanned,
      isFuturePlanned,
    )) {
      (true, _, _, _) => '$name, done',
      (false, true, true, _) => '$name, today, planned',
      (false, true, false, _) => '$name, today, rest',
      (false, false, _, true) => '$name, planned',
      _ => '$name, rest',
    };

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('week-strip-day-$weekday'),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadii.smallBorder,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                letter,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isToday ? AppColors.ink : AppColors.inkFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                key: ValueKey('week-strip-dot-$weekday'),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
