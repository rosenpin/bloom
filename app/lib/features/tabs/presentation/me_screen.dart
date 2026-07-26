import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/presentation/onboarding_widgets.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const ValueKey('me-screen'),
      minimum: const EdgeInsets.all(AppSpacing.lg),
      child: Align(
        alignment: const Alignment(0, -0.24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BloomMark(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Me',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your preferences and progress will live here, quietly remembered.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
