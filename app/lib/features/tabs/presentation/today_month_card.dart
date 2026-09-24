import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/month_presentation.dart';

class TodayMonthCard extends StatelessWidget {
  const TodayMonthCard({
    required this.estimate,
    required this.onStartedToday,
    super.key,
  });

  final MonthEstimate estimate;
  final VoidCallback onStartedToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('today-month-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.lavenderSoft,
        borderRadius: AppRadii.largeBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR MONTH',
            style: theme.labelMedium?.copyWith(
              color: AppColors.lavender,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(estimate.title, style: theme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(estimate.observation, style: theme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Low energy? Life happened makes today lighter.',
            style: theme.bodyLarge?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            children: [
              TextButton(
                key: const ValueKey('month-started-today'),
                onPressed: onStartedToday,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.tapTarget),
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.lavender,
                ),
                child: const Text('Started today?'),
              ),
              TextButton(
                key: const ValueKey('month-research'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.paper,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  builder: (_) => const _ResearchSheet(),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.tapTarget),
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.lavender,
                ),
                child: const Text('What the research says'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResearchSheet extends StatelessWidget {
  const _ResearchSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('What the research says', style: theme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            const _ResearchPoint(
              text:
                  'Your month changes strength very little on average, and it varies a lot from woman to woman.',
              citation: 'McNulty et al., Sports Medicine, 2020',
            ),
            const _ResearchPoint(
              text:
                  'Symptoms like tiredness and cramps are common, and many women say they affect training.',
              citation:
                  'Bruinvels et al., British Journal of Sports Medicine, 2021',
            ),
            const _ResearchPoint(
              text: 'Exercise may ease period pain.',
              citation: 'Armour et al., Cochrane Review, 2019',
            ),
            Text(
              'Bloom does not change your plan by phase. We only say what the research supports.',
              style: theme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.lavenderSoft,
                borderRadius: AppRadii.mediumBorder,
              ),
              child: Text(
                "The honest truth: research on women's training across the month is still thin. It is finally getting real attention, and Bloom will grow with it as better studies arrive.",
                style: theme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchPoint extends StatelessWidget {
  const _ResearchPoint({required this.text, required this.citation});

  final String text;
  final String citation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            citation,
            style: theme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
