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
import '../../plan/domain/plan_presentation.dart';
import '../../plan/presentation/plan_widgets.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _showAllWeeks = false;

  @override
  Widget build(BuildContext context) {
    final documentState = ref.watch(latestPlanProvider);
    final answersState = ref.watch(onboardingAnswersProvider);
    final previewState = ref.watch(sessionPreviewProvider);
    if (documentState.isLoading ||
        answersState.isLoading ||
        previewState.isLoading) {
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

    final preview = previewState.value;
    final currentWeek = preview?.state.mesocycleWeekIndex ?? 1;
    final absoluteWeek = preview?.state.absoluteWeekIndex ?? 1;
    final completedSessions = ref.watch(
      completedSessionsForWeekProvider((
        planId: document.row.id,
        mesocycleWeekIndex: currentWeek,
        absoluteWeekIndex: absoluteWeek,
      )),
    );
    final completedDayIndices = {
      for (final session in completedSessions.value ?? const [])
        session.dayIndex,
    };
    final todayDayIndex = preview?.day.dayIndex;

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
                  PlanPresentation.planName(answers),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _PlanChip(
                      label:
                          '${answers.daysPerWeek?.value ?? document.plan.days.length} '
                          'days a week',
                    ),
                    _PlanChip(
                      label:
                          '${_capitalize(PlanPresentation.emphasisLabel(answers.emphasis))} '
                          'focus',
                    ),
                    _PlanChip(
                      label: '${answers.sessionMinutes?.value ?? 45} min',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _PlanViewToggle(
                  currentWeek: currentWeek,
                  showAllWeeks: _showAllWeeks,
                  onChanged: (showAllWeeks) =>
                      setState(() => _showAllWeeks = showAllWeeks),
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.layout),
                  reverseDuration: AppMotion.exitDuration(
                    context,
                    AppMotion.layout,
                  ),
                  switchInCurve: AppMotion.entranceCurve,
                  switchOutCurve: AppMotion.standardCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.025),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _showAllWeeks
                      ? Column(
                          key: const ValueKey('plan-all-weeks-list'),
                          children: [
                            for (final week in document.plan.mesocycleCalendar)
                              _MesocycleWeekCard(
                                week: week,
                                isCurrent: week.weekIndex == currentWeek,
                              ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('plan-current-week-list'),
                          children: [
                            for (final day in document.plan.days)
                              PlanDayCard(
                                day: day,
                                answers: answers,
                                state:
                                    completedDayIndices.contains(day.dayIndex)
                                    ? PlanDayCardState.done
                                    : day.dayIndex == todayDayIndex
                                    ? PlanDayCardState.today
                                    : PlanDayCardState.upcoming,
                                onTap: () =>
                                    context.push('/plan/day/${day.dayIndex}'),
                              ),
                          ],
                        ),
                ),
                TextButton(
                  key: const ValueKey('plan-adjust'),
                  onPressed: () => context.go('/onboarding/age'),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Create new plan →'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.blushSoft,
        borderRadius: AppRadii.largeBorder,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.roseDeep),
      ),
    );
  }
}

class _PlanViewToggle extends StatelessWidget {
  const _PlanViewToggle({
    required this.currentWeek,
    required this.showAllWeeks,
    required this.onChanged,
  });

  final int currentWeek;
  final bool showAllWeeks;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blushSoft,
      borderRadius: AppRadii.mediumBorder,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: AnimatedAlign(
                    alignment: showAllWeeks
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    duration: AppMotion.duration(context, AppMotion.state),
                    curve: AppMotion.standardCurve,
                    child: SizedBox(
                      width: constraints.maxWidth / 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: AppRadii.smallBorder,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _PlanViewToggleItem(
                        key: const ValueKey('plan-week-view'),
                        label: 'Week $currentWeek',
                        selected: !showAllWeeks,
                        onTap: () => onChanged(false),
                      ),
                    ),
                    Expanded(
                      child: _PlanViewToggleItem(
                        key: const ValueKey('plan-all-weeks-view'),
                        label: 'All weeks',
                        selected: showAllWeeks,
                        onTap: () => onChanged(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanViewToggleItem extends StatelessWidget {
  const _PlanViewToggleItem({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.smallBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? AppColors.roseDeep : AppColors.inkSoft,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MesocycleWeekCard extends StatelessWidget {
  const _MesocycleWeekCard({required this.week, required this.isCurrent});

  final engine.PlanWeek week;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final explanation = PlanPresentation.weekKindExplanation(week.kind);
    return Container(
      key: ValueKey('plan-week-${week.weekIndex}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.blushSoft : AppColors.paper,
        borderRadius: AppRadii.mediumBorder,
        border: Border.all(color: isCurrent ? AppColors.rose : AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xxl,
            height: AppSpacing.xxl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.rose : AppColors.cream,
              borderRadius: AppRadii.smallBorder,
            ),
            child: Text(
              '${week.weekIndex}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isCurrent ? AppColors.paper : AppColors.roseDeep,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week ${week.weekIndex}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  PlanPresentation.weekKindLabel(week.kind),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isCurrent ? AppColors.roseDeep : AppColors.inkSoft,
                  ),
                ),
                if (explanation != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    explanation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
