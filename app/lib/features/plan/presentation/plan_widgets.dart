import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/domain/onboarding_answers.dart';
import '../domain/plan_presentation.dart';

enum PlanDayCardState { done, today, upcoming }

class PlanDayCard extends StatelessWidget {
  const PlanDayCard({
    required this.day,
    required this.answers,
    super.key,
    this.showImage = true,
    this.state = PlanDayCardState.upcoming,
    this.onTap,
  });

  final engine.PlanDay day;
  final OnboardingAnswers? answers;
  final bool showImage;
  final PlanDayCardState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final days = answers?.daysPerWeek?.value ?? 3;
    final minutes = answers?.sessionMinutes?.value ?? 45;
    final weekday = PlanPresentation.weekdayLabel(day.dayIndex, days);
    final eyebrow = switch (state) {
      PlanDayCardState.done => '$weekday · DONE',
      PlanDayCardState.today => 'TODAY',
      PlanDayCardState.upcoming => weekday,
    };
    final surfaceColor = switch (state) {
      PlanDayCardState.done => AppColors.sageSoft,
      _ => AppColors.paper,
    };
    final borderColor = switch (state) {
      PlanDayCardState.done => AppColors.sageSoft,
      PlanDayCardState.today => AppColors.rose,
      PlanDayCardState.upcoming => AppColors.line,
    };
    final eyebrowColor = switch (state) {
      PlanDayCardState.done => AppColors.sage,
      PlanDayCardState.today => AppColors.roseDeep,
      PlanDayCardState.upcoming => AppColors.coral,
    };
    final trailingColor = state == PlanDayCardState.today
        ? AppColors.rose
        : AppColors.inkFaint;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        key: ValueKey('plan-day-card-${day.dayIndex}'),
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mediumBorder,
          side: BorderSide(
            color: borderColor,
            width: state == PlanDayCardState.today ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                if (state == PlanDayCardState.done) ...[
                  Container(
                    width: AppSpacing.xxl,
                    height: AppSpacing.xxl,
                    decoration: BoxDecoration(
                      color: AppColors.paper.withValues(alpha: 0.72),
                      borderRadius: AppRadii.smallBorder,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.sage,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ] else if (showImage) ...[
                  ClipRRect(
                    borderRadius: AppRadii.smallBorder,
                    child: Image.asset(
                      _imageFor(day.dayIndex),
                      width: AppSpacing.xxl,
                      height: AppSpacing.xxl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ] else ...[
                  Container(
                    width: AppSpacing.xxl,
                    height: AppSpacing.xxl,
                    decoration: const BoxDecoration(
                      color: AppColors.blushSoft,
                      borderRadius: AppRadii.smallBorder,
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.roseDeep,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: eyebrowColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        PlanPresentation.dayName(day, answers),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '$minutes min · ${day.exercises.length} exercises',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: trailingColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _imageFor(int index) => switch (index % 3) {
    1 => 'assets/images/hip-thrust-2.jpg',
    2 => 'assets/images/lateral-raise-2.jpg',
    _ => 'assets/images/goblet-squat-2.jpg',
  };
}
