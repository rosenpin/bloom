import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_sizes.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';
import '../../session/application/session_controller.dart';
import '../../session/data/exercise_visual_source.dart';
import '../domain/plan_presentation.dart';

class PlanDayDetailScreen extends ConsumerWidget {
  const PlanDayDetailScreen({required this.dayIndex, super.key});

  final int dayIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentState = ref.watch(latestPlanProvider);
    final answersState = ref.watch(onboardingAnswersProvider);
    final previewState = ref.watch(sessionPreviewProvider);
    if (documentState.isLoading ||
        answersState.isLoading ||
        previewState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(child: LoadingBloom()),
      );
    }

    final document = documentState.value;
    final answers = answersState.value;
    final day = document?.plan.days
        .where((candidate) => candidate.dayIndex == dayIndex)
        .firstOrNull;
    if (document == null || answers == null || day == null) {
      return const _MissingPlanDay();
    }

    final preview = previewState.value;
    final isToday = preview?.day.dayIndex == day.dayIndex;
    final isStarting = ref.watch(sessionControllerProvider).isLoading;
    final minutes = answers.sessionMinutes?.value ?? 45;
    final subtitle = <String>[
      '$minutes min',
      '${day.exercises.length} exercises',
      if (day.warmUpMinutes > 0) 'warm-up included',
    ].join(' · ');

    return Scaffold(
      key: const ValueKey('plan-day-detail-screen'),
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: !isToday,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        key: const ValueKey('plan-day-back'),
                        onPressed: context.pop,
                        tooltip: 'Back',
                        icon: const Icon(Icons.chevron_left_rounded, size: 30),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                PlanPresentation.dayName(day, answers),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: const BoxDecoration(
                      color: AppColors.blushSoft,
                      borderRadius: AppRadii.mediumBorder,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.roseDeep,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Machines busy on the day? You can swap any '
                            'exercise during your workout.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.inkSoft,
                                  height: 1.45,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: AppRadii.mediumBorder,
                      border: Border.all(color: AppColors.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < day.exercises.length;
                          index++
                        )
                          _ExerciseRow(
                            exercise: day.exercises[index],
                            showDivider: index < day.exercises.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: !isToday
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('plan-day-start-workout'),
                      onPressed: isStarting
                          ? null
                          : () async {
                              final runtime = await ref
                                  .read(sessionControllerProvider.notifier)
                                  .start();
                              if (runtime != null && context.mounted) {
                                context.push('/session');
                              }
                            },
                      child: Text(isStarting ? 'Starting...' : 'Start workout'),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.showDivider});

  final engine.PlanExercise exercise;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('plan-day-exercise-${exercise.exerciseId}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.line))
            : null,
      ),
      child: Row(
        children: [
          _ExerciseThumbnail(exerciseId: exercise.exerciseId),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  PlanPresentation.doseLabel(exercise.baseDose),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseThumbnail extends StatelessWidget {
  const _ExerciseThumbnail({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final hasStills = exercisesWithStills.contains(exerciseId);
    return ClipRRect(
      borderRadius: AppRadii.smallBorder,
      child: SizedBox(
        width: AppSizes.thumbnailMd,
        height: AppSizes.thumbnailMd,
        child: !hasStills
            ? const _ExerciseThumbnailFallback()
            : Image.asset(
                'assets/images/exercises/$exerciseId-1.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.15),
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) =>
                    const _ExerciseThumbnailFallback(),
              ),
      ),
    );
  }
}

class _ExerciseThumbnailFallback extends StatelessWidget {
  const _ExerciseThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.blushSoft,
      child: Icon(Icons.fitness_center_rounded, color: AppColors.roseDeep),
    );
  }
}

class _MissingPlanDay extends StatelessWidget {
  const _MissingPlanDay();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: context.pop,
                tooltip: 'Back',
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
              ),
              const Expanded(
                child: Center(
                  child: Text('This workout is not in your latest plan.'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
