import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../history/domain/history_presentation.dart';
import '../../onboarding/domain/onboarding_answers.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';
import '../../plan/domain/plan_presentation.dart';
import '../../session/application/session_controller.dart';
import '../../session/application/session_lifecycle_service.dart';
import '../../session/data/exercise_visual_source.dart';
import '../../session/domain/session_presentation.dart';
import '../domain/month_presentation.dart';
import 'today_month_card.dart';
import 'week_strip.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with SingleTickerProviderStateMixin {
  bool _updateNudgeDismissed = false;
  // Created eagerly: a lazy controller first built in dispose() looks up
  // TickerMode on a deactivated element.
  late final AnimationController _entrance;
  bool _entranceQueued = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this);
  }

  void _queueEntrance() {
    if (_entranceQueued) return;
    _entranceQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entrance.duration = AppMotion.duration(
        context,
        const Duration(milliseconds: 850),
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
    final documentState = ref.watch(latestPlanProvider);
    final answersState = ref.watch(onboardingAnswersProvider);
    final previewState = ref.watch(sessionPreviewProvider);
    final gateDecision = ref.watch(startupVersionGateProvider).value;
    // Refreshes (starting or ending a workout) keep showing the last values;
    // only a first load with nothing to show gets the loading screen.
    if ([
      documentState,
      answersState,
      previewState,
    ].any((state) => state.isLoading && !state.hasValue)) {
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

    _queueEntrance();

    final preview = previewState.value;
    final completed = preview?.completedToday;
    final day = completed?.day ?? preview?.day ?? document.plan.days.first;
    final currentWeek = preview?.state.mesocycleWeekIndex ?? 1;
    final week = document.plan.mesocycleCalendar.firstWhere(
      (entry) => entry.weekIndex == currentWeek,
      orElse: () => document.plan.mesocycleCalendar.first,
    );
    final weekKind = week.kind;
    final weekExplanation = PlanPresentation.weekKindExplanation(weekKind);
    final absoluteWeek = preview?.state.absoluteWeekIndex ?? 1;
    final completedSessions = ref.watch(
      completedSessionsForWeekProvider((
        planId: document.row.id,
        mesocycleWeekIndex: currentWeek,
        absoluteWeekIndex: absoluteWeek,
      )),
    );
    final daysPerWeek = answers.daysPerWeek?.value ?? document.plan.days.length;
    final plannedDays = {
      for (final planDay in document.plan.days)
        _weekdayFromPlanLabel(
          PlanPresentation.weekdayLabel(planDay.dayIndex, daysPerWeek),
        ): WeekStripPlanDay(
          dayIndex: planDay.dayIndex,
          label: PlanPresentation.shortDayName(planDay).split(' ').first,
        ),
    };
    final weeklyCompletedAt =
        completedSessions.value
            ?.map((session) => session.completedAt)
            .nonNulls ??
        const Iterable<DateTime>.empty();
    final completedAt = <DateTime>[
      ...weeklyCompletedAt,
      ?completed?.record.completedAt,
    ];
    final today = ref.watch(clockProvider)();
    final isTrainingDay =
        plannedDays.containsKey(today.weekday) ||
        completed != null ||
        (preview?.hasOpenSessionToday ?? false);
    final nextWeekday = plannedDays.keys.reduce((a, b) {
      final aDistance = (a - today.weekday + 7) % 7;
      final bDistance = (b - today.weekday + 7) % 7;
      return (aDistance == 0 ? 7 : aDistance) < (bDistance == 0 ? 7 : bDistance)
          ? a
          : b;
    });
    final nextDay = document.plan.days.firstWhere(
      (entry) => entry.dayIndex == plannedDays[nextWeekday]!.dayIndex,
    );
    final headerLine = completed != null
        ? 'Done for today. Nice and steady.'
        : preview?.hasOpenSessionToday ?? false
        ? 'Your workout is waiting. No rush.'
        : !isTrainingDay
        ? 'Rest day. ${_weekdayName(nextWeekday)} is ${PlanPresentation.shortDayName(nextDay).toLowerCase()}.'
        : '${PlanPresentation.shortDayName(day)} today. About ${answers.sessionMinutes?.value ?? 45} minutes.';
    final showMonth =
        answers.menstrualPreference == MenstrualPreference.optedIn &&
        answers.lastPeriodStart != null;
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
                _TodayReveal(
                  animation: _entrance,
                  interval: const Interval(
                    0,
                    0.48,
                    curve: AppMotion.entranceCurve,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dateKicker(today),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: AppColors.inkSoft,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              headerLine,
                              key: const ValueKey('today-state-line'),
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const BloomMark(showWordmark: false),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.state),
                  reverseDuration: AppMotion.exitDuration(
                    context,
                    AppMotion.state,
                  ),
                  switchInCurve: AppMotion.entranceCurve,
                  switchOutCurve: AppMotion.standardCurve,
                  transitionBuilder: _softStateTransition,
                  child:
                      gateDecision?.updateRecommended == true &&
                          !_updateNudgeDismissed
                      ? Padding(
                          key: const ValueKey('version-nudge-visible'),
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: _VersionUpdateNudge(
                            message: gateDecision?.message,
                            onDismiss: () =>
                                setState(() => _updateNudgeDismissed = true),
                          ),
                        )
                      : const SizedBox(key: ValueKey('version-nudge-hidden')),
                ),
                const SizedBox(height: AppSpacing.lg),
                _TodayReveal(
                  animation: _entrance,
                  interval: const Interval(
                    0.18,
                    0.72,
                    curve: AppMotion.entranceCurve,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.state),
                    reverseDuration: AppMotion.exitDuration(
                      context,
                      AppMotion.state,
                    ),
                    switchInCurve: AppMotion.entranceCurve,
                    switchOutCurve: AppMotion.standardCurve,
                    transitionBuilder: _softStateTransition,
                    child: _TodayHeroCard(
                      key: ValueKey(
                        completed != null
                            ? 'today-hero-done'
                            : preview?.hasOpenSessionToday ?? false
                            ? 'today-hero-resume'
                            : preview?.isComeback ?? false
                            ? 'today-hero-comeback'
                            : 'today-hero-normal',
                      ),
                      dayName: PlanPresentation.dayName(day, answers),
                      firstExerciseId: day.exercises.firstOrNull?.exerciseId,
                      weekKind: weekKind,
                      exerciseCount: day.exercises.length,
                      plannedMinutes: answers.sessionMinutes?.value ?? 45,
                      completed: completed,
                      hasOpenSession: preview?.hasOpenSessionToday ?? false,
                      isComeback: preview?.isComeback ?? false,
                      onStart: preview == null
                          ? null
                          : () => _startSession(context),
                      onSummary: completed == null
                          ? null
                          : () => context.push(
                              '/history/session/${completed.record.id}',
                            ),
                    ),
                  ),
                ),
                if (completed case final session?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _NextSessionLine(session: session, today: today),
                ],
                SizedBox(
                  height: completed == null ? AppSpacing.lg : AppSpacing.xs,
                ),
                _TodayReveal(
                  animation: _entrance,
                  interval: const Interval(
                    0.42,
                    0.9,
                    curve: AppMotion.entranceCurve,
                  ),
                  child: Container(
                    key: const ValueKey('today-six-weeks'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: AppRadii.largeBorder,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR SIX WEEKS',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.inkSoft,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Week ${week.weekIndex} of ${document.plan.mesocycleCalendar.length} · ${PlanPresentation.weekKindLabel(weekKind)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (weekExplanation != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            weekExplanation,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        WeekStrip(
                          today: today,
                          completedAt: completedAt,
                          plannedDays: plannedDays,
                          onOpenDay: (dayIndex) =>
                              context.push('/plan/day/$dayIndex'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showMonth) ...[
                  const SizedBox(height: AppSpacing.md),
                  _TodayReveal(
                    animation: _entrance,
                    interval: const Interval(
                      0.58,
                      1,
                      curve: AppMotion.entranceCurve,
                    ),
                    child: TodayMonthCard(
                      estimate: estimateMonth(
                        today: today,
                        lastPeriodStart: answers.lastPeriodStart!,
                        gap: answers.menstrualGap,
                      ),
                      onStartedToday: () =>
                          _markPeriodStarted(today, answers.lastPeriodStart!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startSession(BuildContext context) async {
    final runtime = await ref.read(sessionControllerProvider.notifier).start();
    if (runtime != null && context.mounted) context.push('/session');
  }

  Future<void> _markPeriodStarted(DateTime today, DateTime previous) async {
    final date = DateTime(today.year, today.month, today.day);
    await ref
        .read(onboardingRepositoryProvider)
        .update((current) => current.copyWith(lastPeriodStart: date));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Updated your month.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref
              .read(onboardingRepositoryProvider)
              .update((current) => current.copyWith(lastPeriodStart: previous)),
        ),
      ),
    );
  }
}

String _dateKicker(DateTime date) {
  const weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  const months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

String _weekdayName(int weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[weekday - 1];
}

class _TodayReveal extends StatelessWidget {
  const _TodayReveal({
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

int _weekdayFromPlanLabel(String label) => switch (label) {
  'MONDAY' => DateTime.monday,
  'TUESDAY' => DateTime.tuesday,
  'WEDNESDAY' => DateTime.wednesday,
  'THURSDAY' => DateTime.thursday,
  'FRIDAY' => DateTime.friday,
  'SATURDAY' => DateTime.saturday,
  'SUNDAY' => DateTime.sunday,
  _ => throw ArgumentError.value(label, 'label', 'Unknown weekday label'),
};

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.dayName,
    required this.firstExerciseId,
    required this.weekKind,
    required this.exerciseCount,
    required this.plannedMinutes,
    required this.hasOpenSession,
    required this.isComeback,
    required this.onStart,
    required this.onSummary,
    this.completed,
    super.key,
  });

  final String dayName;
  final String? firstExerciseId;
  final engine.MesocycleWeekKind weekKind;
  final int exerciseCount;
  final int plannedMinutes;
  final CompletedSession? completed;
  final bool hasOpenSession;
  final bool isComeback;
  final VoidCallback? onStart;
  final VoidCallback? onSummary;

  @override
  Widget build(BuildContext context) {
    final done = completed != null;
    final summary = completed;
    final detail = summary == null
        ? '$exerciseCount exercises · $plannedMinutes min'
        : [
            HistoryPresentation.duration(summary.duration),
            if (summary.lastEffort case final effort?)
              HistoryPresentation.feel(effort),
          ].join(' · ');
    final source = firstExerciseId == null
        ? null
        : resolveExerciseVisualSource(firstExerciseId!);
    final image = switch (source) {
      BundledStillsSource(:final pos2Asset) => pos2Asset,
      BundledExerciseVideoSource()
          when exercisesWithStills.contains(firstExerciseId) =>
        'assets/images/exercises/$firstExerciseId-2.jpg',
      _ => 'assets/images/hip-thrust-2.jpg',
    };
    return ClipRRect(
      borderRadius: AppRadii.largeBorder,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          AspectRatio(
            aspectRatio: AppSizes.exerciseVisualAspect,
            child: Image.asset(
              image,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/hip-thrust-2.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.ink.withValues(alpha: 0.02),
                    AppColors.ink.withValues(alpha: 0.88),
                  ],
                  stops: const [0.3, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: done ? AppColors.sageSoft : AppColors.blushSoft,
                      borderRadius: AppRadii.largeBorder,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (done) ...[
                          const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: AppColors.sage,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                        ],
                        Text(
                          done
                              ? 'DONE · ${HistoryPresentation.weekday(summary!.record.completedAt!, uppercase: true)}'
                              : isComeback
                              ? 'EASING BACK IN'
                              : PlanPresentation.weekKindLabel(weekKind),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: done
                                    ? AppColors.sage
                                    : AppColors.roseDeep,
                                letterSpacing: done ? 0.7 : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  dayName,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: AppColors.paper),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.paper),
                ),
                const SizedBox(height: AppSpacing.md),
                if (done)
                  FilledButton(
                    key: const ValueKey('see-what-you-did'),
                    onPressed: onSummary,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sageSoft,
                      foregroundColor: AppColors.sage,
                    ),
                    child: const Text('See what you did'),
                  )
                else
                  FilledButton.icon(
                    key: ValueKey(
                      hasOpenSession ? 'resume-workout' : 'start-workout',
                    ),
                    onPressed: onStart,
                    icon: Icon(
                      hasOpenSession
                          ? Icons.refresh_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      hasOpenSession
                          ? 'Pick up where you left off'
                          : isComeback
                          ? 'Start gently'
                          : 'Start workout',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextSessionLine extends StatelessWidget {
  const _NextSessionLine({required this.session, required this.today});

  final CompletedSession session;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = session.document.plan.days;
    final currentIndex = days.indexWhere(
      (day) => day.dayIndex == session.record.dayIndex,
    );
    final next = days[currentIndex < 0 ? 0 : (currentIndex + 1) % days.length];
    final daysPerWeek = session.answers.daysPerWeek?.value ?? days.length;
    final plannedWeekday = SessionPresentation.plannedWeekdayLabel(
      dayIndex: next.dayIndex,
      daysPerWeek: daysPerWeek,
      date: today,
    );
    final weekday = plannedWeekday == null
        ? null
        : '${plannedWeekday[0]}${plannedWeekday.substring(1).toLowerCase()}';
    final nextLabel = [
      ?weekday,
      PlanPresentation.dayName(next, session.answers),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Next up · $nextLabel',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
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
                AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.state),
                  reverseDuration: AppMotion.exitDuration(
                    context,
                    AppMotion.state,
                  ),
                  switchInCurve: AppMotion.entranceCurve,
                  switchOutCurve: AppMotion.standardCurve,
                  transitionBuilder: _softStateTransition,
                  child: showUpdateNudge
                      ? Padding(
                          key: const ValueKey('empty-version-nudge-visible'),
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: _VersionUpdateNudge(
                            message: updateMessage,
                            onDismiss: onDismissUpdate,
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('empty-version-nudge-hidden'),
                        ),
                ),
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
                  'A few quick questions. Then a six-week plan built around you.',
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

Widget _softStateTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
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
