import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';
import '../../plan/domain/plan_presentation.dart';
import '../../session/application/session_controller.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _updateNudgeDismissed = false;

  @override
  Widget build(BuildContext context) {
    final documentState = ref.watch(latestPlanProvider);
    final answersState = ref.watch(onboardingAnswersProvider);
    final previewState = ref.watch(sessionPreviewProvider);
    final gateDecision = ref.watch(startupVersionGateProvider).value;
    if (documentState.isLoading ||
        answersState.isLoading ||
        previewState.isLoading) {
      return const LoadingBloom();
    }
    final document = documentState.value;
    final answers = answersState.value;
    if (document == null || answers == null) {
      return _NoPlanToday(
        onCreatePlan: () => context.go('/onboarding'),
        showUpdateNudge:
            gateDecision?.updateRecommended == true && !_updateNudgeDismissed,
        updateMessage: gateDecision?.message,
        onDismissUpdate: () => setState(() => _updateNudgeDismissed = true),
      );
    }

    final preview = previewState.value;
    final day = preview?.day ?? document.plan.days.first;
    final weekKind =
        preview?.state.weekKind ?? document.plan.mesocycleCalendar.first.kind;
    final weekExplanation = PlanPresentation.weekKindExplanation(weekKind);
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
                if (gateDecision?.updateRecommended == true &&
                    !_updateNudgeDismissed) ...[
                  const SizedBox(height: AppSpacing.md),
                  _VersionUpdateNudge(
                    message: gateDecision?.message,
                    onDismiss: () =>
                        setState(() => _updateNudgeDismissed = true),
                  ),
                ],
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
                if (weekExplanation != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.blushSoft,
                      borderRadius: AppRadii.mediumBorder,
                    ),
                    child: Text(
                      weekExplanation,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('start-workout'),
                  onPressed: preview == null
                      ? null
                      : () async {
                          final runtime = await ref
                              .read(sessionControllerProvider.notifier)
                              .start();
                          if (runtime != null && context.mounted) {
                            context.push('/session');
                          }
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start workout'),
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
  const _NoPlanToday({
    required this.onCreatePlan,
    required this.showUpdateNudge,
    required this.onDismissUpdate,
    this.updateMessage,
  });

  final VoidCallback onCreatePlan;
  final bool showUpdateNudge;
  final String? updateMessage;
  final VoidCallback onDismissUpdate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const ValueKey('today-screen'),
      minimum: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showUpdateNudge) ...[
                  _VersionUpdateNudge(
                    message: updateMessage,
                    onDismiss: onDismissUpdate,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
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
      ),
    );
  }
}

class _VersionUpdateNudge extends StatelessWidget {
  const _VersionUpdateNudge({required this.onDismiss, this.message});

  final String? message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('version-update-nudge'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.lavenderSoft,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppColors.lavender),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message ?? 'An app update is ready when you are.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            key: const ValueKey('dismiss-version-update-nudge'),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
