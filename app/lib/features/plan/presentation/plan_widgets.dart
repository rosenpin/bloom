import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/domain/onboarding_answers.dart';
import '../domain/plan_presentation.dart';

class PlanDayCard extends StatelessWidget {
  const PlanDayCard({
    required this.day,
    required this.answers,
    super.key,
    this.showImage = true,
  });

  final engine.PlanDay day;
  final OnboardingAnswers? answers;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final days = answers?.daysPerWeek?.value ?? 3;
    final minutes = answers?.sessionMinutes?.value ?? 45;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppRadii.mediumBorder,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          if (showImage) ...[
            ClipRRect(
              borderRadius: AppRadii.smallBorder,
              child: Container(
                width: AppSpacing.xxl,
                height: AppSpacing.xxl,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.blushSoft, AppColors.lavenderSoft],
                  ),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.roseDeep,
                ),
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
                  PlanPresentation.weekdayLabel(day.dayIndex, days),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.coral,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}
