import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../history/domain/history_presentation.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';
import '../../plan/domain/plan_presentation.dart';
import '../../session/application/session_controller.dart';
import '../../session/application/session_lifecycle_service.dart';
import 'week_strip.dart';

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
    final completed = preview?.completedToday;
    final day = completed?.day ?? preview?.day ?? document.plan.days.first;
    final weekKind =
        preview?.state.weekKind ?? document.plan.mesocycleCalendar.first.kind;
    final weekExplanation = PlanPresentation.weekKindExplanation(weekKind);
    final currentWeek = preview?.state.mesocycleWeekIndex ?? 1;
    final absoluteWeek = preview?.state.absoluteWeekIndex ?? 1;
    final completedSessions = ref.watch(
      completedSessionsForWeekProvider((
        planId: document.row.id,
        mesocycleWeekIndex: currentWeek,
        absoluteWeekIndex: absoluteWeek,
      )),
    );
    final daysPerWeek = answers.daysPerWeek?.value ?? document.plan.days.length;
    final plannedWeekdays = {
      for (final planDay in document.plan.days)
        _weekdayFromPlanLabel(
          PlanPresentation.weekdayLabel(planDay.dayIndex, daysPerWeek),
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
                AnimatedSwitcher(
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
                          : 'today-hero-normal',
                    ),
                    dayName: PlanPresentation.dayName(day, answers),
                    weekKind: weekKind,
                    exerciseCount: day.exercises.length,
                    plannedMinutes: answers.sessionMinutes?.value ?? 45,
                    completed: completed,
                    hasOpenSession: preview?.hasOpenSessionToday ?? false,
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
                if (completed case final session?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _NextSessionLine(session: session),
                ],
                SizedBox(
                  height: completed == null ? AppSpacing.lg : AppSpacing.xs,
                ),
                WeekStrip(
                  today: today,
                  completedAt: completedAt,
                  plannedWeekdays: plannedWeekdays,
                ),
                if (weekExplanation != null) ...[
                  const SizedBox(height: AppSpacing.md),
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
    required this.weekKind,
    required this.exerciseCount,
    required this.plannedMinutes,
    required this.hasOpenSession,
    required this.onStart,
    required this.onSummary,
    this.completed,
    super.key,
  });

  final String dayName;
  final engine.MesocycleWeekKind weekKind;
  final int exerciseCount;
  final int plannedMinutes;
  final CompletedSession? completed;
  final bool hasOpenSession;
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
    return ClipRRect(
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
  const _NextSessionLine({required this.session});

  final CompletedSession session;

  @override
  Widget build(BuildContext context) {
    final days = session.document.plan.days;
    final currentIndex = days.indexWhere(
      (day) => day.dayIndex == session.record.dayIndex,
    );
    final next = days[currentIndex < 0 ? 0 : (currentIndex + 1) % days.length];
    final daysPerWeek = session.answers.daysPerWeek?.value ?? days.length;
    final uppercaseWeekday = PlanPresentation.weekdayLabel(
      next.dayIndex,
      daysPerWeek,
    );
    final weekday =
        '${uppercaseWeekday[0]}${uppercaseWeekday.substring(1).toLowerCase()}';
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
              'Next up · $weekday · ${PlanPresentation.dayName(next, session.answers)}',
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
