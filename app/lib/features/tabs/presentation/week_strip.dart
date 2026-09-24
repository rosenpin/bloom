import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';

final class WeekStripPlanDay {
  const WeekStripPlanDay({required this.dayIndex, required this.label});

  final int dayIndex;
  final String label;
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.today,
    required this.completedAt,
    required this.plannedDays,
    required this.onOpenDay,
    super.key,
  });

  final DateTime today;
  final Iterable<DateTime> completedAt;
  final Map<int, WeekStripPlanDay> plannedDays;
  final ValueChanged<int> onOpenDay;

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
      for (final completedDate in completedAt)
        if (_sameWeek(completedDate, today)) completedDate.weekday,
    };
    return Row(
      key: const ValueKey('week-strip'),
      children: [
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        )
          Expanded(
            child: _WeekDay(
              weekday: weekday,
              letter: _dayLetters[weekday - 1],
              name: _dayNames[weekday - 1],
              isToday: weekday == today.weekday,
              isDone: completedWeekdays.contains(weekday),
              planDay: plannedDays[weekday],
              onOpenDay: onOpenDay,
            ),
          ),
      ],
    );
  }
}

bool _sameWeek(DateTime a, DateTime b) {
  final aDate = DateTime.utc(a.year, a.month, a.day);
  final bDate = DateTime.utc(b.year, b.month, b.day);
  return aDate.subtract(Duration(days: a.weekday - 1)) ==
      bDate.subtract(Duration(days: b.weekday - 1));
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.weekday,
    required this.letter,
    required this.name,
    required this.isToday,
    required this.isDone,
    required this.planDay,
    required this.onOpenDay,
  });

  final int weekday;
  final String letter;
  final String name;
  final bool isToday;
  final bool isDone;
  final WeekStripPlanDay? planDay;
  final ValueChanged<int> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final semanticsLabel =
        '$name, ${isToday ? 'today, ' : ''}'
        '${isDone
            ? 'done'
            : planDay == null
            ? 'rest'
            : '${planDay!.label} planned'}';
    return Semantics(
      button: planDay != null,
      label: semanticsLabel,
      child: InkWell(
        key: ValueKey('week-strip-day-$weekday'),
        onTap: planDay == null ? null : () => onOpenDay(planDay!.dayIndex),
        borderRadius: AppRadii.smallBorder,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                letter,
                style: theme.labelMedium?.copyWith(
                  color: isToday ? AppColors.roseDeep : AppColors.inkSoft,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isToday ? AppColors.rose : AppColors.line,
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.sage,
                        size: AppSizes.iconSmall,
                      )
                    : null,
              ),
              const SizedBox(height: 5),
              Text(
                planDay?.label ?? ' ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.labelMedium?.copyWith(
                  color: planDay == null
                      ? AppColors.inkFaint
                      : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
