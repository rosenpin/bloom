import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../plan/domain/plan_presentation.dart';
import '../../session/application/session_lifecycle_service.dart';
import '../../session/domain/session_presentation.dart';
import '../domain/history_presentation.dart';

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(completedSessionProvider(sessionId));
    return Scaffold(
      key: const ValueKey('session-summary-screen'),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _MissingSession(onBack: () => _back(context)),
        data: (value) => value == null
            ? _MissingSession(onBack: () => _back(context))
            : _SessionSummary(session: value, onBack: () => _back(context)),
      ),
    );
  }

  static void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/today');
    }
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session, required this.onBack});

  final CompletedSession session;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final completedAt = session.record.completedAt!;
    final unitSystem = session.answers.unitSystem;
    final logs = _exerciseLogs(session);
    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: const ValueKey('session-summary-back'),
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          Text(
                            'Your session',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        HistoryPresentation.weekday(
                          completedAt,
                          uppercase: true,
                        ),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.sage,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        PlanPresentation.dayName(session.day, session.answers),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${HistoryPresentation.monthDay(completedAt)} · ${HistoryPresentation.duration(session.duration)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: const BoxDecoration(
                          color: AppColors.blushSoft,
                          borderRadius: AppRadii.mediumBorder,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              SessionPresentation.formatLoad(
                                session.totalLoad,
                                unitSystem,
                              ),
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'moved, ${SessionPresentation.dayComparison(session.totalLoad)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadii.large),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'WHAT YOU DID',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.inkFaint,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (logs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: Text(
                            'Your session is saved.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        )
                      else
                        for (final log in logs)
                          _LoggedExercise(log: log, unitSystem: unitSystem),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<_ExerciseLog> _exerciseLogs(CompletedSession session) {
    final setsByExercise = <String, List<engine.SetCompleted>>{};
    for (final set in session.latestSets.values) {
      (setsByExercise[set.exerciseId] ??= []).add(set);
    }
    return [
      for (final entry in setsByExercise.entries)
        _ExerciseLog(
          exerciseId: entry.key,
          name: session.exerciseName(entry.key),
          sets: [...entry.value]
            ..sort((left, right) => left.setIndex.compareTo(right.setIndex)),
          isPerSide:
              session.exerciseLaterality(entry.key) ==
              engine.Laterality.perSide,
          wasSwapped: session.swappedExerciseIds.contains(entry.key),
        ),
    ];
  }
}

class _ExerciseLog {
  const _ExerciseLog({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.isPerSide,
    required this.wasSwapped,
  });

  final String exerciseId;
  final String name;
  final List<engine.SetCompleted> sets;
  final bool isPerSide;
  final bool wasSwapped;

  bool get isUniform => sets
      .skip(1)
      .every(
        (set) => set.reps == sets.first.reps && set.load == sets.first.load,
      );
}

class _LoggedExercise extends StatelessWidget {
  const _LoggedExercise({required this.log, required this.unitSystem});

  final _ExerciseLog log;
  final engine.UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('logged-exercise-${log.exerciseId}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.wasSwapped) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: const BoxDecoration(
                color: AppColors.blushSoft,
                borderRadius: AppRadii.largeBorder,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 15,
                    color: AppColors.roseDeep,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    'Swapped in · ${log.name}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.roseDeep),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(log.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          if (log.isUniform)
            Text(
              _uniformSummary(log, unitSystem),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            )
          else
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.cream,
                borderRadius: AppRadii.smallBorder,
              ),
              child: Column(
                children: [
                  for (final set in log.sets)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 58,
                            child: Text(
                              'Set ${set.setIndex + 1}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _setSummary(set, log.isPerSide, unitSystem),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _uniformSummary(
    _ExerciseLog log,
    engine.UnitSystem unitSystem,
  ) {
    final first = log.sets.first;
    final reps = '${first.reps}${log.isPerSide ? ' each side' : ''}';
    final load = first.load.value > 0
        ? ' · ${SessionPresentation.formatLoad(first.load, unitSystem)}'
        : '';
    return '${log.sets.length} × $reps$load';
  }

  static String _setSummary(
    engine.SetCompleted set,
    bool isPerSide,
    engine.UnitSystem unitSystem,
  ) {
    final reps = '${set.reps} reps${isPerSide ? ' each side' : ''}';
    final load = set.load.value > 0
        ? ' · ${SessionPresentation.formatLoad(set.load, unitSystem)}'
        : '';
    return '$reps$load';
  }
}

class _MissingSession extends StatelessWidget {
  const _MissingSession({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_florist_rounded,
                color: AppColors.rose,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This session is not here yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: onBack, child: const Text('Back to today')),
            ],
          ),
        ),
      ),
    );
  }
}
