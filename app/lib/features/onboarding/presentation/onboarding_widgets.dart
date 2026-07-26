import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

class BloomMark extends StatelessWidget {
  const BloomMark({super.key, this.showWordmark = true});

  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CustomPaint(
          size: Size.square(AppSpacing.lg),
          painter: _BloomFlowerPainter(),
        ),
        if (showWordmark) ...[
          const SizedBox(width: AppSpacing.xs),
          Text('bloom', style: Theme.of(context).textTheme.headlineSmall),
        ],
      ],
    );
  }
}

/// The brand mark: a five-petal bloom. (Replaced the earlier single-drop mark,
/// which read as a drop of blood: a bad accidental connotation for this app.)
class _BloomFlowerPainter extends CustomPainter {
  const _BloomFlowerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final petal = Paint()..color = AppColors.rose;
    final petalLength = size.height * 0.42;
    final petalWidth = size.width * 0.30;

    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * 2 * math.pi / 5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -petalLength / 2 - size.height * 0.06),
          width: petalWidth,
          height: petalLength,
        ),
        petal,
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      size.width * 0.14,
      Paint()..color = AppColors.cream,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QuizPage extends StatelessWidget {
  const QuizPage({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onContinue,
    super.key,
    this.continueLabel = 'Continue',
    this.footer,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onContinue;
  final String continueLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingProgress(step: step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.inkSoft,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        child,
                      ],
                    ),
                  ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: onContinue,
                        child: Text(continueLabel),
                      ),
                      ?footer,
                    ],
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

class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({super.key, this.step, this.optional = false})
    : assert(step != null || optional);

  final int? step;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.smallBorder,
              child: LinearProgressIndicator(
                minHeight: AppSpacing.xxs,
                value: optional ? 1 : step! / 7,
                backgroundColor: AppColors.blushSoft,
                valueColor: const AlwaysStoppedAnimation(AppColors.rose),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            optional ? 'Optional' : '$step of 7',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.inkFaint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class OptionCard extends StatelessWidget {
  const OptionCard({
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
    this.description,
    this.trailing,
    this.child,
  });

  final String title;
  final String? description;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.blushSoft : AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mediumBorder,
          side: BorderSide(
            color: selected ? AppColors.rose : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.mediumBorder,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (description != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              description!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.inkSoft,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    trailing ?? SelectionRadio(selected: selected),
                  ],
                ),
                if (child != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  child!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SelectionRadio extends StatelessWidget {
  const SelectionRadio({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: AppSpacing.lg,
      height: AppSpacing.lg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.rose : AppColors.paper,
        border: Border.all(
          color: selected ? AppColors.rose : AppColors.line,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(
              Icons.circle,
              color: AppColors.paper,
              size: AppSpacing.sm,
            )
          : null,
    );
  }
}

class SquareChoice<T> extends StatelessWidget {
  const SquareChoice({
    required this.value,
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
    this.caption,
  });

  final T value;
  final String label;
  final String? caption;
  final bool selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.blushSoft : AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mediumBorder,
        side: BorderSide(
          color: selected ? AppColors.rose : AppColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: AppRadii.mediumBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: AppTheme.displayFontFamily,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SoftNote extends StatelessWidget {
  const SoftNote({
    required this.text,
    super.key,
    this.icon = Icons.favorite_border_rounded,
    this.color = AppColors.blushSoft,
    this.iconColor = AppColors.roseDeep,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: AppSpacing.lg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.inkFaint,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class BloomToggle extends StatelessWidget {
  const BloomToggle({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: AppRadii.largeBorder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: AppSpacing.xxl,
          height: AppSpacing.xl,
          padding: const EdgeInsets.all(AppSpacing.xxs),
          decoration: BoxDecoration(
            color: value ? AppColors.rose : AppColors.line,
            borderRadius: AppRadii.largeBorder,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.paper,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: AppSpacing.lg),
            ),
          ),
        ),
      ),
    );
  }
}

class PillChoice<T> extends StatelessWidget {
  const PillChoice({
    required this.value,
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final T value;
  final String label;
  final bool selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.rose : AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.largeBorder,
        side: BorderSide(color: selected ? AppColors.rose : AppColors.line),
      ),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: AppRadii.largeBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? AppColors.paper : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingBloom extends StatelessWidget {
  const LoadingBloom({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.rose,
          backgroundColor: AppColors.blushSoft,
        ),
      ),
    );
  }
}
