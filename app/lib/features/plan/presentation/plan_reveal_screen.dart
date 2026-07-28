import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';
import '../domain/plan_presentation.dart';
import 'plan_widgets.dart';

class PlanRevealScreen extends ConsumerStatefulWidget {
  const PlanRevealScreen({super.key});

  @override
  ConsumerState<PlanRevealScreen> createState() => _PlanRevealScreenState();
}

class _PlanRevealScreenState extends ConsumerState<PlanRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(vsync: this);
  bool _entranceQueued = false;

  void _queueEntrance(int dayCount) {
    if (_entranceQueued) return;
    _entranceQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entrance.duration = AppMotion.duration(
        context,
        _totalEntranceDuration(dayCount),
      );
      _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(latestPlanProvider);
    final answersState = ref.watch(onboardingAnswersProvider);
    final document = planState.value;
    final answers = answersState.value;
    if (document == null || answers == null) return const LoadingBloom();
    final dayCount = document.plan.days.length;
    _queueEntrance(dayCount);
    final totalMilliseconds = _totalEntranceDuration(dayCount).inMilliseconds;

    return Scaffold(
      key: const ValueKey('plan-reveal-screen'),
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.blushSoft, AppColors.paper],
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RevealItem(
                                animation: _entrance,
                                interval: _motionInterval(
                                  start: 0,
                                  end: 400,
                                  total: totalMilliseconds,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: AppColors.paper,
                                        borderRadius: AppRadii.largeBorder,
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          BloomMark(showWordmark: false),
                                          SizedBox(width: AppSpacing.xs),
                                          Text(
                                            'Made for you',
                                            style: TextStyle(
                                              color: AppColors.roseDeep,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      PlanPresentation.planName(answers),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineLarge,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      PlanPresentation.profileSummary(answers),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(color: AppColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < document.plan.days.length;
                                index++
                              )
                                _RevealItem(
                                  animation: _entrance,
                                  interval: _motionInterval(
                                    start: 420 + (index * 110),
                                    end: 870 + (index * 110),
                                    total: totalMilliseconds,
                                  ),
                                  child: PlanDayCard(
                                    day: document.plan.days[index],
                                    answers: answers,
                                    onTap: () => context.push(
                                      '/plan/day/${document.plan.days[index].dayIndex}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _RevealItem(
                    animation: _entrance,
                    interval: _motionInterval(
                      start: 900 + ((dayCount - 1) * 110),
                      end: 1300 + ((dayCount - 1) * 110),
                      total: totalMilliseconds,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          key: const ValueKey('reveal-start'),
                          onPressed: () => context.go('/today'),
                          child: const Text('Start my first workout'),
                        ),
                        TextButton(
                          key: const ValueKey('reveal-tweak'),
                          onPressed: () => context.go('/onboarding/age'),
                          child: const Text('Create new plan'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Duration _totalEntranceDuration(int dayCount) =>
    Duration(milliseconds: 1300 + ((dayCount - 1).clamp(0, dayCount) * 110));

Interval _motionInterval({
  required int start,
  required int end,
  required int total,
}) => Interval(
  (start / total).clamp(0, 1),
  (end / total).clamp(0, 1),
  curve: AppMotion.entranceCurve,
);

class _RevealItem extends StatelessWidget {
  const _RevealItem({
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reveal = CurvedAnimation(parent: animation, curve: interval);
    return AnimatedBuilder(
      animation: reveal,
      child: child,
      builder: (context, child) => Opacity(
        opacity: reveal.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - reveal.value)),
          child: child,
        ),
      ),
    );
  }
}
