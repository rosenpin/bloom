import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../history/domain/history_presentation.dart';
import '../../onboarding/domain/onboarding_answers.dart';
import '../../plan/domain/plan_presentation.dart';
import '../../session/application/session_lifecycle_service.dart';
import '../../session/domain/session_presentation.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingAnswersProvider).value;
    final sessions = ref.watch(completedSessionsProvider);
    return SafeArea(
      key: const ValueKey('me-screen'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Me', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: AppSpacing.md),
                if (answers case final profile?) _ProfileCard(answers: profile),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Your sessions',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A quiet record of the work you have done.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: AppSpacing.md),
                sessions.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => const _EmptySessions(),
                  data: (values) => values.isEmpty
                      ? const _EmptySessions()
                      : Column(
                          children: [
                            for (final session in values)
                              _SessionRow(
                                session: session,
                                onTap: () => context.push(
                                  '/history/session/${session.record.id}',
                                ),
                              ),
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
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.answers});

  final OnboardingAnswers answers;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (answers.daysPerWeek case final days?) '${days.value} days a week',
      if (answers.sessionMinutes case final minutes?)
        '${minutes.value} min sessions',
      '${PlanPresentation.emphasisLabel(answers.emphasis)} focus',
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.blushSoft,
        borderRadius: AppRadii.largeBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR PLAN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.roseDeep,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PlanPresentation.planName(answers),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final label in chips)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.78),
                    borderRadius: AppRadii.largeBorder,
                  ),
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final CompletedSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completedAt = session.record.completedAt!;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        key: ValueKey('history-session-${session.record.id}'),
        onTap: onTap,
        borderRadius: AppRadii.mediumBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.sageSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.sage),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${HistoryPresentation.weekday(completedAt, uppercase: true)} · ${HistoryPresentation.shortDate(completedAt).toUpperCase()}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.sage,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      PlanPresentation.dayName(session.day, session.answers),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${HistoryPresentation.duration(session.duration)} · ${SessionPresentation.formatLoad(session.totalLoad, session.answers.unitSystem)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('history-empty'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.local_florist_outlined,
            color: AppColors.rose,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your first workout will land here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
