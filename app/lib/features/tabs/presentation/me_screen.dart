import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
                const SizedBox(height: AppSpacing.xl),
                const _MembershipSection(),
                const SizedBox(height: AppSpacing.xl),
                const _AboutSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipSection extends ConsumerWidget {
  const _MembershipSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(premiumStatusProvider).value ??
        ref.read(entitlementServiceProvider).currentStatus;
    final date = status.expirationDate == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(status.expirationDate!.toLocal());
    final statusText = !status.isPremium
        ? 'Not active'
        : status.isTrial
        ? 'Free trial until ${date ?? 'soon'}'
        : date == null
        ? 'Premium'
        : 'Premium · ${status.willRenew ? 'renews' : 'until'} $date';

    Future<void> restore() async {
      ref.read(appEventsLoggerProvider).restoreTapped();
      try {
        final restored = await ref.read(entitlementServiceProvider).restore();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restored.isPremium
                  ? 'Membership restored.'
                  : 'No active membership found yet.',
            ),
          ),
        );
      } on Object {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not restore right now. Try again.'),
            ),
          );
        }
      }
    }

    Future<void> redeem() async {
      ref.read(appEventsLoggerProvider).redeemCodeTapped();
      try {
        await ref.read(entitlementServiceProvider).redeemCode();
        await ref.read(entitlementServiceProvider).refresh();
      } on Object {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open codes right now. Try again.'),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Membership', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        _QuietGroup(
          children: [
            _QuietRow(title: statusText, icon: Icons.favorite_rounded),
            if (status.managementUrl != null)
              _QuietRow(
                title: 'Manage subscription',
                icon: Icons.open_in_new_rounded,
                onTap: () => _open(status.managementUrl!),
              ),
            _QuietRow(
              title: 'Restore purchases',
              icon: Icons.refresh_rounded,
              onTap: restore,
            ),
            _QuietRow(
              title: 'Redeem a code',
              icon: Icons.card_giftcard_rounded,
              onTap: redeem,
            ),
            _QuietRow(
              title: 'Support ID',
              subtitle: status.appUserId ?? 'Unavailable',
              icon: Icons.copy_rounded,
              onTap: status.appUserId == null
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: status.appUserId!),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support ID copied.')),
                        );
                      }
                    },
            ),
          ],
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('About', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.md),
      _QuietGroup(
        children: [
          _QuietRow(
            title: 'Privacy policy',
            icon: Icons.open_in_new_rounded,
            onTap: () =>
                _open('https://womensgym.github.io/bloom-site/privacy.html'),
          ),
          _QuietRow(
            title: 'Terms of use',
            icon: Icons.open_in_new_rounded,
            onTap: () => _open(
              'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Bloom gives general fitness guidance, not medical advice. Check with a doctor first if you are pregnant, injured, or managing a health condition.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
      ),
    ],
  );
}

class _QuietGroup extends StatelessWidget {
  const _QuietGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.paper,
      borderRadius: AppRadii.mediumBorder,
    ),
    child: Column(children: children),
  );
}

class _QuietRow extends StatelessWidget {
  const _QuietRow({
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadii.mediumBorder,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.roseDeep, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    ),
  );
}

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on Object {
    // External links can fail while offline.
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
