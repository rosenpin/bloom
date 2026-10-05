import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

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
  final _zoneKey = GlobalKey();
  double _zoneHeight = 0;

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
    WidgetsBinding.instance.addPostFrameCallback(_measureZone);
    final totalMilliseconds = _totalEntranceDuration(dayCount).inMilliseconds;

    return Scaffold(
      key: const ValueKey('plan-reveal-screen'),
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                // The last card can scroll clear of the pinned buttons.
                padding: EdgeInsets.only(bottom: _zoneHeight),
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
                                  end: 350,
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
                              _RevealItem(
                                animation: _entrance,
                                interval: _motionInterval(
                                  start: 150,
                                  end: 550,
                                  total: totalMilliseconds,
                                ),
                                child: _SixWeekArc(
                                  weeks: document.plan.mesocycleCalendar,
                                ),
                              ),
                              for (
                                var index = 0;
                                index < document.plan.days.length;
                                index++
                              )
                                _RevealItem(
                                  animation: _entrance,
                                  interval: _motionInterval(
                                    start: 250 + (index * 80),
                                    end: 650 + (index * 80),
                                    total: totalMilliseconds,
                                  ),
                                  child: PlanDayCard(
                                    day: document.plan.days[index],
                                    answers: answers,
                                    prominentImage: true,
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
          ),
          // The buttons and their surface rise together, over the plan, once
          // the first cards are in. There is never an empty box, and before
          // it arrives the plan runs to the bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _RevealItem(
              animation: _entrance,
              interval: _motionInterval(
                start: 450,
                end: 850,
                total: totalMilliseconds,
              ),
              rise: 1,
              child: Container(
                key: _zoneKey,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.bottomEdge(context),
                ),
                decoration: const BoxDecoration(
                  color: AppColors.paper,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          key: const ValueKey('reveal-start'),
                          onPressed: () => context.go('/today'),
                          child: const Text('Start my plan'),
                        ),
                        TextButton(
                          key: const ValueKey('reveal-tweak'),
                          onPressed: () => context.go('/onboarding/age'),
                          child: const Text('Change my answers'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _measureZone(Duration _) {
    final height = _zoneKey.currentContext?.size?.height;
    if (mounted && height != null && height != _zoneHeight) {
      setState(() => _zoneHeight = height);
    }
  }
}

class _SixWeekArc extends StatelessWidget {
  const _SixWeekArc({required this.weeks});

  final List<engine.PlanWeek> weeks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your six weeks',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final week in weeks) ...[
                if (week != weeks.first) const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: AppSpacing.sm,
                        decoration: BoxDecoration(
                          color: switch (week.kind) {
                            engine.MesocycleWeekKind.easier => AppColors.sage,
                            engine.MesocycleWeekKind.deload =>
                              AppColors.lavender,
                            _ => AppColors.rose,
                          },
                          borderRadius: AppRadii.smallBorder,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'W${week.weekIndex}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              for (final (index, label) in const [
                'Find your feet',
                'Easier week',
                'Lighter finish',
              ].indexed)
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: index == 0
                        ? TextAlign.left
                        : index == 2
                        ? TextAlign.right
                        : TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Duration _totalEntranceDuration(int dayCount) => Duration(
  milliseconds: math.max(850, 650 + (dayCount - 1).clamp(0, dayCount) * 80),
);

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
    this.rise,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  /// Rise from this fraction of its own height below, instead of 12 pt.
  final double? rise;

  @override
  Widget build(BuildContext context) {
    final reveal = CurvedAnimation(parent: animation, curve: interval);
    return AnimatedBuilder(
      animation: reveal,
      child: child,
      // Nothing is tappable before it can be seen.
      builder: (context, child) => IgnorePointer(
        ignoring: reveal.value < 0.5,
        // A rising surface stays opaque, so it covers the plan as it comes up
        // instead of showing the cards through it.
        child: rise == null
            ? Opacity(
                opacity: reveal.value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - reveal.value)),
                  child: child,
                ),
              )
            : FractionalTranslation(
                translation: Offset(0, rise! * (1 - reveal.value)),
                child: child,
              ),
      ),
    );
  }
}
