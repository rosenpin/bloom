import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';
import '../../plan/domain/plan_presentation.dart';
import '../../plan/presentation/plan_widgets.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

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
      return SafeArea(
        key: const ValueKey('plan-screen'),
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: FilledButton(
            onPressed: () => context.go('/onboarding'),
            child: const Text('Build my plan'),
          ),
        ),
      );
    }

    return SafeArea(
      key: const ValueKey('plan-screen'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your plan',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        PlanPresentation.planName(answers),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
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
                        '${answers.daysPerWeek?.value ?? document.plan.days.length} days a week',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.roseDeep),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final day in document.plan.days)
                  PlanDayCard(day: day, answers: answers, showImage: false),
                TextButton(
                  key: const ValueKey('plan-adjust'),
                  onPressed: () => context.go('/onboarding/age'),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Adjust my plan →'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
