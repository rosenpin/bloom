import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/onboarding_answers.dart';
import 'onboarding_widgets.dart';

void _completeStep(
  WidgetRef ref,
  BuildContext context,
  int step,
  String nextPath,
) {
  ref.read(appEventsLoggerProvider).onboardingStepCompleted(step);
  context.go(nextPath);
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  late final Future<OnboardingAnswers> _profile;

  @override
  void initState() {
    super.initState();
    final locale = ref.read(deviceLocaleProvider);
    _profile = ref
        .read(onboardingRepositoryProvider)
        .ensureProfile(countryCode: locale.countryCode);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _profile,
      builder: (context, snapshot) {
        final answers = snapshot.data;
        if (answers == null) return const LoadingBloom();
        return Scaffold(
          backgroundColor: AppColors.paper,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BloomMark(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: AppRadii.largeBorder,
                          child: Image.asset(
                            'assets/images/goblet-squat-1.jpg',
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.55),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Your gym plan,\nmade for you.',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Seven quick questions, then a week of workouts built around you. Every move shown, every weight decided.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.inkSoft,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        key: const ValueKey('welcome-start'),
                        onPressed: () => context.go(answers.resumePath),
                        child: Text(
                          answers.ageBand == null
                              ? "Let's find your plan"
                              : 'Keep going',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AgeScreen extends ConsumerWidget {
  const AgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _withAnswers(ref, (answers) {
      final choices = <engine.AgeBand, String>{
        engine.AgeBand.age18To29: '18–29',
        engine.AgeBand.age30To39: '30–39',
        engine.AgeBand.age40To49: '40–49',
        engine.AgeBand.age50To59: '50–59',
        engine.AgeBand.age60Plus: '60+',
      };
      return QuizPage(
        step: 1,
        onBack: () => context.go('/onboarding'),
        title: 'How old are you?',
        subtitle:
            "Every decade starts differently. We'll pace your plan to yours.",
        onContinue: answers.ageBand == null
            ? null
            : () => _completeStep(ref, context, 1, '/onboarding/goal'),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final choice in choices.entries)
                  SquareChoice(
                    key: ValueKey('age-${choice.key.name}'),
                    value: choice.key,
                    label: choice.value,
                    selected: answers.ageBand == choice.key,
                    onSelected: (value) => ref
                        .read(onboardingRepositoryProvider)
                        .update((current) => current.copyWith(ageBand: value)),
                  ),
              ],
            ),
            if (answers.ageBand == engine.AgeBand.age60Plus) ...[
              const SizedBox(height: AppSpacing.md),
              const SoftNote(
                color: AppColors.sageSoft,
                iconColor: AppColors.sage,
                text:
                    'Machine-first moves, longer warm-ups, joint-friendly swaps. Strength is the best thing you can do for your bones.',
              ),
            ],
          ],
        ),
      );
    });
  }
}

class GoalScreen extends ConsumerWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const choices = <engine.Goal, (String, String)>{
      engine.Goal.tonedAndDefined: (
        'Toned & defined',
        'Firm up, build lean shape.',
      ),
      engine.Goal.stronger: ('Stronger', 'Lift more, carry more, ache less.'),
      engine.Goal.buildCurves: (
        'Build curves',
        'Grow specific areas, usually glutes.',
      ),
      engine.Goal.feelHealthier: (
        'Feel healthier',
        'Energy, mood, stronger bones.',
      ),
    };
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 2,
        onBack: () => context.go('/onboarding/age'),
        title: 'What are we working toward?',
        subtitle: 'You can change this anytime.',
        onContinue: answers.goal == null
            ? null
            : () => _completeStep(ref, context, 2, '/onboarding/days'),
        child: Column(
          children: [
            for (final choice in choices.entries)
              OptionCard(
                key: ValueKey('goal-${choice.key.name}'),
                title: choice.value.$1,
                description: choice.value.$2,
                selected: answers.goal == choice.key,
                onTap: () => ref
                    .read(onboardingRepositoryProvider)
                    .update((current) => current.copyWith(goal: choice.key)),
              ),
          ],
        ),
      ),
    );
  }
}

class DaysScreen extends ConsumerWidget {
  const DaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 3,
        onBack: () => context.go('/onboarding/goal'),
        title: 'How often can you get to the gym?',
        subtitle: 'Be honest, not ambitious.',
        onContinue: answers.daysPerWeek == null
            ? null
            : () =>
                  _completeStep(ref, context, 3, '/onboarding/session-length'),
        child: Column(
          children: [
            Row(
              children: [
                for (final value in engine.TrainingDaysPerWeek.values) ...[
                  if (value != engine.TrainingDaysPerWeek.two)
                    const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SquareChoice(
                      key: ValueKey('days-${value.value}'),
                      value: value,
                      label: '${value.value}',
                      caption: 'days',
                      selected: answers.daysPerWeek == value,
                      onSelected: (selection) => ref
                          .read(onboardingRepositoryProvider)
                          .update(
                            (current) =>
                                current.copyWith(daysPerWeek: selection),
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SoftNote(
              icon: Icons.schedule_rounded,
              text: switch (answers.daysPerWeek) {
                engine.TrainingDaysPerWeek.two =>
                  'Two steady days can build real strength without taking over your week.',
                engine.TrainingDaysPerWeek.four =>
                  'Four gym days gives each session a little more breathing room.',
                _ => 'Three days is the sweet spot on a busy schedule.',
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SessionLengthScreen extends ConsumerWidget {
  const SessionLengthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 4,
        onBack: () => context.go('/onboarding/days'),
        title: 'How long have you got?',
        subtitle: 'Workouts should fit your life, not the other way around.',
        onContinue: answers.sessionMinutes == null
            ? null
            : () => _completeStep(ref, context, 4, '/onboarding/experience'),
        child: Column(
          children: [
            Row(
              children: [
                for (final value in engine.SessionMinutes.values) ...[
                  if (value != engine.SessionMinutes.thirty)
                    const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SquareChoice(
                      key: ValueKey('minutes-${value.value}'),
                      value: value,
                      label: '${value.value}',
                      caption: 'minutes',
                      selected: answers.sessionMinutes == value,
                      onSelected: (selection) => ref
                          .read(onboardingRepositoryProvider)
                          .update(
                            (current) =>
                                current.copyWith(sessionMinutes: selection),
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SoftNote(
              text:
                  "30 focused minutes is genuinely enough. On loud days we'll shrink any workout to its core moves.",
            ),
          ],
        ),
      ),
    );
  }
}

class ExperienceScreen extends ConsumerWidget {
  const ExperienceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const experienceLabels = <engine.ProfileExperienceTier, String>{
      engine.ProfileExperienceTier.newToIt: 'New to it',
      engine.ProfileExperienceTier.beenAWhile: 'Been a while',
      engine.ProfileExperienceTier.trainsRegularly: 'I train regularly',
    };
    const comfortChoices = <engine.GymComfort, (String, String)>{
      engine.GymComfort.low: (
        'Still finding my feet',
        'Machine setups, quiet corners, busy-gym swaps.',
      ),
      engine.GymComfort.mostlyFine: (
        'Mostly fine',
        'Guidance one tap away when you want it.',
      ),
      engine.GymComfort.totallyAtHome: (
        'Totally at home',
        "We'll keep the tips out of your way.",
      ),
    };
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 5,
        onBack: () => context.go('/onboarding/session-length'),
        title: 'Where are you starting from?',
        subtitle: 'This shapes how much guidance we build in.',
        onContinue: answers.experienceTier == null || answers.gymComfort == null
            ? null
            : () => _completeStep(ref, context, 5, '/onboarding/emphasis'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Lifting experience'),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              decoration: const BoxDecoration(
                color: AppColors.blushSoft,
                borderRadius: AppRadii.smallBorder,
              ),
              child: Row(
                children: [
                  for (final choice in experienceLabels.entries)
                    Expanded(
                      child: _SegmentChoice(
                        key: ValueKey('experience-${choice.key.name}'),
                        label: choice.value,
                        selected: answers.experienceTier == choice.key,
                        onTap: () => ref
                            .read(onboardingRepositoryProvider)
                            .update(
                              (current) =>
                                  current.copyWith(experienceTier: choice.key),
                            ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('On the gym floor, I feel…'),
            for (final choice in comfortChoices.entries)
              OptionCard(
                key: ValueKey('comfort-${choice.key.name}'),
                title: choice.value.$1,
                description: choice.value.$2,
                selected: answers.gymComfort == choice.key,
                onTap: () => ref
                    .read(onboardingRepositoryProvider)
                    .update(
                      (current) => current.copyWith(gymComfort: choice.key),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentChoice extends StatelessWidget {
  const _SegmentChoice({
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
      color: selected ? AppColors.paper : AppColors.blushSoft,
      borderRadius: AppRadii.smallBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.smallBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? AppColors.ink : AppColors.inkSoft,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class EmphasisScreen extends ConsumerWidget {
  const EmphasisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const choices = <engine.Emphasis, String>{
      engine.Emphasis.glutes: 'Glutes',
      engine.Emphasis.legs: 'Legs',
      engine.Emphasis.core: 'Core',
      engine.Emphasis.arms: 'Arms',
      engine.Emphasis.back: 'Back',
      engine.Emphasis.balanced: 'Keep it balanced',
    };
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 6,
        onBack: () => context.go('/onboarding/experience'),
        title: 'Anywhere you want extra focus?',
        subtitle: "You'll train everything. This just tilts the balance.",
        onContinue: answers.emphasis == null
            ? null
            : () => _completeStep(ref, context, 6, '/onboarding/activities'),
        child: Column(
          children: [
            _BodyMap(emphasis: answers.emphasis),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final choice in choices.entries)
                  PillChoice(
                    key: ValueKey('emphasis-${choice.key.name}'),
                    value: choice.key,
                    label: choice.value,
                    selected: answers.emphasis == choice.key,
                    onSelected: (selection) => ref
                        .read(onboardingRepositoryProvider)
                        .update(
                          (current) => current.copyWith(emphasis: selection),
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyMap extends StatelessWidget {
  const _BodyMap({required this.emphasis});

  final engine.Emphasis? emphasis;

  @override
  Widget build(BuildContext context) {
    final accentAlignment = switch (emphasis) {
      engine.Emphasis.back => Alignment.topCenter,
      engine.Emphasis.arms => Alignment.centerLeft,
      engine.Emphasis.core => Alignment.center,
      engine.Emphasis.legs => Alignment.bottomCenter,
      _ => const Alignment(0, 0.35),
    };
    return Center(
      child: SizedBox(
        width: AppSpacing.xxl * 3,
        height: AppSpacing.xxl * 4,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 0,
              child: Container(
                width: AppSpacing.xl,
                height: AppSpacing.xl,
                decoration: const BoxDecoration(
                  color: AppColors.line,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.xl,
              bottom: AppSpacing.sm,
              child: Container(
                width: AppSpacing.xxl,
                decoration: const BoxDecoration(
                  color: AppColors.line,
                  borderRadius: AppRadii.largeBorder,
                ),
              ),
            ),
            Align(
              alignment: accentAlignment,
              child: Container(
                width: AppSpacing.xxl,
                height: AppSpacing.lg,
                decoration: BoxDecoration(
                  color:
                      emphasis == null || emphasis == engine.Emphasis.balanced
                      ? AppColors.blush
                      : AppColors.coral,
                  borderRadius: AppRadii.largeBorder,
                  border: Border.all(color: AppColors.rose),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const choices = <engine.ActivityKind, (String, String)>{
      engine.ActivityKind.running: ('Cardio', 'Runs, spin, incline walks.'),
      engine.ActivityKind.yogaPilates: (
        'Yoga or pilates',
        'Studio or at home.',
      ),
      engine.ActivityKind.groupClasses: (
        'Classes or sport',
        'Netball, spin, climbing, dance.',
      ),
    };
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 7,
        onBack: () => context.go('/onboarding/emphasis'),
        title: 'What else do you do?',
        subtitle: "So your gym days land where you've got the energy for them.",
        onContinue: () =>
            _completeStep(ref, context, 7, '/onboarding/menstrual'),
        child: Column(
          children: [
            for (final choice in choices.entries)
              _ActivityCard(
                kind: choice.key,
                title: choice.value.$1,
                description: choice.value.$2,
                frequency: answers.otherActivities[choice.key] ?? 0,
              ),
            const SoftNote(
              icon: Icons.arrow_upward_rounded,
              text:
                  "Three sessions a week already? We'll keep your whole week in view so nothing feels like a slog.",
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({
    required this.kind,
    required this.title,
    required this.description,
    required this.frequency,
  });

  final engine.ActivityKind kind;
  final String title;
  final String description;
  final int frequency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = frequency > 0;
    return OptionCard(
      key: ValueKey('activity-${kind.name}'),
      title: title,
      description: description,
      selected: enabled,
      trailing: BloomToggle(
        value: enabled,
        onChanged: (value) => _setFrequency(ref, value ? 1 : 0),
      ),
      onTap: () => _setFrequency(ref, enabled ? 0 : 1),
      child: enabled
          ? Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final value in const [1, 2, 3])
                    PillChoice(
                      key: ValueKey('activity-${kind.name}-$value'),
                      value: value,
                      label: value == 3
                          ? '3×+'
                          : '$value×${value == 2 ? ' a week' : ''}',
                      selected: frequency == value,
                      onSelected: (selection) => _setFrequency(ref, selection),
                    ),
                ],
              ),
            )
          : null,
    );
  }

  Future<void> _setFrequency(WidgetRef ref, int value) {
    return ref.read(onboardingRepositoryProvider).update((current) {
      final activities = Map<engine.ActivityKind, int>.from(
        current.otherActivities,
      );
      if (value == 0) {
        activities.remove(kind);
      } else {
        activities[kind] = value;
      }
      return current.copyWith(otherActivities: activities);
    });
  }
}

class MenstrualScreen extends ConsumerWidget {
  const MenstrualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _withAnswers(ref, (answers) {
      final enabled =
          answers.menstrualPreference != MenstrualPreference.declined &&
          answers.menstrualPreference != MenstrualPreference.notApplicable;
      final ready =
          !enabled ||
          (answers.lastPeriodStart != null && answers.menstrualGap != null);
      void goBack() => context.go('/onboarding/activities');
      return OnboardingBackScope(
        onBack: goBack,
        child: Scaffold(
          backgroundColor: AppColors.paper,
          body: SafeArea(
            child: Column(
              children: [
                OnboardingProgress(optional: true, onBack: goBack),
                Expanded(
                  child: SingleChildScrollView(
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: const BoxDecoration(
                                color: AppColors.lavenderSoft,
                                borderRadius: AppRadii.mediumBorder,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.nightlight_round,
                                    color: AppColors.lavender,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Work with your menstrual cycle',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text(
                                          'Two questions. No tracking, ever.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.inkSoft,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  BloomToggle(
                                    key: const ValueKey('menstrual-toggle'),
                                    value: enabled,
                                    onChanged: (value) => ref
                                        .read(onboardingRepositoryProvider)
                                        .update(
                                          (current) => current.copyWith(
                                            menstrualPreference: value
                                                ? MenstrualPreference.undecided
                                                : MenstrualPreference.declined,
                                            lastPeriodStart: value
                                                ? current.lastPeriodStart
                                                : null,
                                            menstrualGap: value
                                                ? current.menstrualGap
                                                : null,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (enabled) ...[
                              const SizedBox(height: AppSpacing.lg),
                              const SectionLabel(
                                'When did your last period start?',
                              ),
                              _PeriodDateChoices(answers: answers),
                              const SizedBox(height: AppSpacing.lg),
                              const SectionLabel('Usual gap between periods'),
                              SlidingSegmentedPicker<MenstrualGap>(
                                options: const {
                                  MenstrualGap.days26: '26 days',
                                  MenstrualGap.days28: '28 days',
                                  MenstrualGap.days30Plus: '30+',
                                  MenstrualGap.notSure: 'Not sure',
                                },
                                value: answers.menstrualGap,
                                segmentKeyBuilder: (gap) =>
                                    ValueKey('menstrual-gap-${gap.name}'),
                                onChanged: (value) => ref
                                    .read(onboardingRepositoryProvider)
                                    .update(
                                      (current) => current.copyWith(
                                        menstrualPreference:
                                            MenstrualPreference.optedIn,
                                        menstrualGap: value,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              OptionCard(
                                key: const ValueKey('menstrual-not-applicable'),
                                title: 'None of this fits me',
                                description:
                                    "On the pill, irregular, or no periods? We'll just ask how you feel instead.",
                                selected:
                                    answers.menstrualPreference ==
                                    MenstrualPreference.notApplicable,
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.inkFaint,
                                ),
                                onTap: () => _finishWithoutMenstrualData(
                                  context,
                                  ref,
                                  MenstrualPreference.notApplicable,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: AppSpacing.lg),
                              const SoftNote(
                                color: AppColors.lavenderSoft,
                                iconColor: AppColors.lavender,
                                icon: Icons.favorite_border_rounded,
                                text:
                                    "That's completely fine. This will never change the plan we build today.",
                              ),
                            ],
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
                            key: const ValueKey('menstrual-finish'),
                            onPressed: ready
                                ? () => context.go('/onboarding/generating')
                                : null,
                            child: const Text("That's everything"),
                          ),
                          TextButton(
                            key: const ValueKey('menstrual-skip'),
                            onPressed: () => _finishWithoutMenstrualData(
                              context,
                              ref,
                              MenstrualPreference.declined,
                            ),
                            child: const Text("Skip this for now"),
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
      );
    });
  }

  Future<void> _finishWithoutMenstrualData(
    BuildContext context,
    WidgetRef ref,
    MenstrualPreference preference,
  ) async {
    await ref
        .read(onboardingRepositoryProvider)
        .update(
          (current) => current.copyWith(
            menstrualPreference: preference,
            lastPeriodStart: null,
            menstrualGap: null,
          ),
        );
    if (context.mounted) context.go('/onboarding/generating');
  }
}

class _PeriodDateChoices extends ConsumerWidget {
  const _PeriodDateChoices({required this.answers});

  final OnboardingAnswers answers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider)();
    final choices = <(String, String?, DateTime)>[
      ('Today', null, now),
      ('5 days', 'ago', now.subtract(const Duration(days: 5))),
      ('2 wks', 'ago', now.subtract(const Duration(days: 14))),
    ];
    return Row(
      children: [
        for (final (index, choice) in choices.indexed) ...[
          if (index != 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: SizedBox(
              height: 72,
              child: SquareChoice(
                key: ValueKey('menstrual-date-$index'),
                value: choice.$3,
                label: choice.$1,
                caption: choice.$2,
                compact: true,
                selected: _sameDay(answers.lastPeriodStart, choice.$3),
                onSelected: (date) => _saveDate(ref, date),
              ),
            ),
          ),
        ],
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: SizedBox(
            height: 72,
            child: SquareChoice(
              key: const ValueKey('menstrual-date-pick'),
              value: now,
              label: 'Pick',
              caption: 'a date',
              compact: true,
              selected:
                  answers.lastPeriodStart != null &&
                  !choices.any(
                    (choice) => _sameDay(answers.lastPeriodStart, choice.$3),
                  ),
              onSelected: (_) => _pickDate(context, ref, now),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime now,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: answers.lastPeriodStart ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: AppColors.paper,
            headerBackgroundColor: AppColors.blushSoft,
            headerForegroundColor: AppColors.ink,
            todayForegroundColor: WidgetStatePropertyAll(AppColors.roseDeep),
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null) await _saveDate(ref, selected);
  }

  Future<void> _saveDate(WidgetRef ref, DateTime date) {
    return ref
        .read(onboardingRepositoryProvider)
        .update(
          (current) => current.copyWith(
            menstrualPreference: MenstrualPreference.optedIn,
            lastPeriodStart: DateTime(date.year, date.month, date.day),
          ),
        );
  }

  bool _sameDay(DateTime? left, DateTime right) =>
      left?.year == right.year &&
      left?.month == right.month &&
      left?.day == right.day;
}

class GeneratingScreen extends ConsumerStatefulWidget {
  const GeneratingScreen({super.key});

  @override
  ConsumerState<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends ConsumerState<GeneratingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    unawaited(_generate());
  }

  Future<void> _generate() async {
    final minimum = Future<void>.delayed(
      ref.read(minimumGenerationDelayProvider),
    );
    try {
      await ref.read(planGenerationServiceProvider).generate();
      await minimum;
      if (mounted) context.go('/onboarding/reveal');
    } on Object catch (error) {
      await minimum;
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(onboardingAnswersProvider).value;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - (AppSpacing.xl * 2),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: _error == null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) => Transform.scale(
                                scale: 0.96 + (_controller.value * 0.08),
                                child: child,
                              ),
                              child: Container(
                                width: AppSpacing.xxl * 4,
                                height: AppSpacing.xxl * 4,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: Alignment.topLeft,
                                    colors: [
                                      AppColors.paper,
                                      AppColors.blushSoft,
                                      AppColors.blush,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.blush,
                                      blurRadius: AppSpacing.xl,
                                      spreadRadius: AppSpacing.xs,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: BloomMark(showWordmark: false),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Designing your week…',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _generationSummary(answers),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _GenerationLine(
                              text:
                                  'Balancing your ${_emphasisLabel(answers?.emphasis)} focus',
                              done: true,
                            ),
                            const _GenerationLine(
                              text: 'Choosing beginner-friendly setups',
                              done: true,
                            ),
                            _GenerationLine(
                              text: _activityGenerationLine(answers),
                              done: false,
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BloomMark(),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              "We couldn't finish your plan just yet.",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Your answers are safe. Give it one more try.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton(
                              onPressed: () {
                                setState(() => _error = null);
                                unawaited(_generate());
                              },
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerationLine extends StatelessWidget {
  const _GenerationLine({required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          done
              ? const Icon(
                  Icons.check_rounded,
                  color: AppColors.sage,
                  size: AppSpacing.lg,
                )
              : const SizedBox.square(
                  dimension: AppSpacing.lg,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.rose,
                    backgroundColor: AppColors.blush,
                  ),
                ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: done ? AppColors.ink : AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _withAnswers(
  WidgetRef ref,
  Widget Function(OnboardingAnswers answers) builder,
) {
  final state = ref.watch(onboardingAnswersProvider);
  return state.when(
    data: (answers) =>
        answers == null ? const LoadingBloom() : builder(answers),
    error: (error, stackTrace) => const LoadingBloom(),
    loading: () => const LoadingBloom(),
  );
}

String _emphasisLabel(engine.Emphasis? emphasis) => switch (emphasis) {
  engine.Emphasis.glutes => 'glute',
  engine.Emphasis.legs => 'leg',
  engine.Emphasis.core => 'core',
  engine.Emphasis.arms => 'arm',
  engine.Emphasis.back => 'back',
  _ => 'balanced',
};

String _generationSummary(OnboardingAnswers? answers) {
  if (answers == null) return 'A week built around you.';
  final days = answers.daysPerWeek?.value;
  return '${days ?? 'Your'} gym days, ${_emphasisLabel(answers.emphasis)} focus, built around real life.';
}

String _activityGenerationLine(OnboardingAnswers? answers) {
  if (answers?.otherActivities.containsKey(engine.ActivityKind.yogaPilates) ??
      false) {
    return 'Keeping yoga and pilates in view';
  }
  if (answers?.otherActivities.isNotEmpty ?? false) {
    return 'Keeping the rest of your week in view';
  }
  return 'Giving every session room to breathe';
}
