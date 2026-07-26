import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';
import '../../plan/domain/plan_presentation.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentState = ref.watch(latestPlanProvider);
    final answersState = ref.watch(onboardingAnswersProvider);
    if (documentState.isLoading || answersState.isLoading) {
      return const LoadingBloom();
    }
    final document = documentState.value;
    final answers = answersState.value;
    if (document == null || answers == null) {
      return _NoPlanToday(onCreatePlan: () => context.go('/onboarding'));
    }

    final day = document.plan.days.first;
    final weekKind = document.plan.mesocycleCalendar.first.kind;
    return SafeArea(
      key: const ValueKey('today-screen'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          Text(
                            'Walk in knowing exactly what to do.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const BloomMark(showWordmark: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: AppRadii.largeBorder,
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      AspectRatio(
                        aspectRatio: 0.92,
                        child: Image.asset(
                          'assets/images/hip-thrust-2.jpg',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.ink.withValues(alpha: 0),
                                AppColors.ink.withValues(alpha: 0.84),
                              ],
                              stops: const [0.35, 1],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.blushSoft,
                                borderRadius: AppRadii.largeBorder,
                              ),
                              child: Text(
                                PlanPresentation.weekKindLabel(weekKind),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: AppColors.roseDeep),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              PlanPresentation.dayName(day, answers),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: AppColors.paper),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${day.exercises.length} exercises · ${answers.sessionMinutes?.value ?? 45} min',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.paper),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('workout-player-milestone'),
                  onPressed: null,
                  icon: const Icon(Icons.lock_clock_outlined),
                  label: const Text('Workout player coming soon'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPlanToday extends StatelessWidget {
  const _NoPlanToday({required this.onCreatePlan});

  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const ValueKey('today-screen'),
      minimum: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: const BoxDecoration(
                  color: AppColors.blushSoft,
                  shape: BoxShape.circle,
                ),
                child: const BloomMark(showWordmark: false),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Walk in knowing exactly what to do.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Seven quick questions, then your first week is ready.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const ValueKey('today-create-plan'),
                onPressed: onCreatePlan,
                child: const Text('Make my plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
