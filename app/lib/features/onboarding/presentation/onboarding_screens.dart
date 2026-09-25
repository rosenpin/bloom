import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
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

final _advancingSteps = <int>{};

Future<void> _selectAndAdvance(
  WidgetRef ref,
  BuildContext context,
  int step,
  String nextPath,
  OnboardingAnswers Function(OnboardingAnswers) selection,
) async {
  if (!_advancingSteps.add(step)) return;
  try {
    HapticFeedback.selectionClick();
    await ref.read(onboardingRepositoryProvider).update(selection);
    if (!context.mounted) return;
    await Future<void>.delayed(
      AppMotion.duration(context, const Duration(milliseconds: 280)),
    );
    // Going back during the pause wins: a step already leaving the screen
    // must not pull her forward again.
    if (context.mounted && (ModalRoute.isCurrentOf(context) ?? true)) {
      _completeStep(ref, context, step, nextPath);
    }
  } finally {
    _advancingSteps.remove(step);
  }
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  static const image = 'assets/images/goblet-squat-1.jpg';

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

  Future<void> _start() async {
    final answers = await _profile;
    if (mounted) context.go(answers.resumePath);
  }

  @override
  Widget build(BuildContext context) {
    // The screen lays out at once; only the button label waits for the saved
    // profile, which is a local read that lands during the page entrance.
    return FutureBuilder(
      future: _profile,
      builder: (context, snapshot) {
        final answers = snapshot.data;
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
                            WelcomeScreen.image,
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
                        'A few quick questions. Then a six-week plan built around you.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.inkSoft,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        key: const ValueKey('welcome-start'),
                        onPressed: _start,
                        child: Text(
                          answers?.ageBand == null
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
        subtitle: '',
        child: Column(
          children: [
            for (final choice in choices.entries)
              OptionCard(
                key: ValueKey('age-${choice.key.name}'),
                title: choice.value,
                selected: answers.ageBand == choice.key,
                onTap: () => _selectAndAdvance(
                  ref,
                  context,
                  1,
                  '/onboarding/goal',
                  (current) => current.copyWith(ageBand: choice.key),
                ),
              ),
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
        'Build a strong, lean shape.',
      ),
      engine.Goal.stronger: ('Stronger', 'Feel stronger every day.'),
      engine.Goal.buildCurves: ('Build curves', 'Grow the areas you choose.'),
      engine.Goal.feelHealthier: ('Feel healthier', 'Move well and feel good.'),
    };
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 2,
        onBack: () => context.go('/onboarding/age'),
        title: 'What are we working toward?',
        subtitle: 'You can change this anytime.',
        child: Column(
          children: [
            for (final choice in choices.entries)
              OptionCard(
                key: ValueKey('goal-${choice.key.name}'),
                title: choice.value.$1,
                description: choice.value.$2,
                selected: answers.goal == choice.key,
                onTap: () => _selectAndAdvance(
                  ref,
                  context,
                  2,
                  '/onboarding/days',
                  (current) => current.copyWith(goal: choice.key),
                ),
              ),
            if (answers.ageBand == engine.AgeBand.age60Plus)
              const SoftNote(
                color: AppColors.sageSoft,
                iconColor: AppColors.sage,
                text:
                    'We will start with comfortable setups and give you more warm-up time.',
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
        subtitle: '',
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
                      onSelected: (selection) => _selectAndAdvance(
                        ref,
                        context,
                        3,
                        '/onboarding/session-length',
                        (current) => current.copyWith(daysPerWeek: selection),
                      ),
                    ),
                  ),
                ],
              ],
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
        subtitle: '',
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
                      onSelected: (selection) => _selectAndAdvance(
                        ref,
                        context,
                        4,
                        '/onboarding/experience',
                        (current) =>
                            current.copyWith(sessionMinutes: selection),
                      ),
                    ),
                  ),
                ],
              ],
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
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 5,
        onBack: () => context.go('/onboarding/session-length'),
        title: 'Lifting experience',
        child: Column(
          children: [
            for (final choice in experienceLabels.entries)
              OptionCard(
                key: ValueKey('experience-${choice.key.name}'),
                title: choice.value,
                selected: answers.experienceTier == choice.key,
                onTap: () => _selectAndAdvance(
                  ref,
                  context,
                  5,
                  '/onboarding/comfort',
                  (current) => current.copyWith(experienceTier: choice.key),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ComfortScreen extends ConsumerWidget {
  const ComfortScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const choices = <engine.GymComfort, String>{
      engine.GymComfort.low: 'Still finding my feet',
      engine.GymComfort.mostlyFine: 'Mostly fine',
      engine.GymComfort.totallyAtHome: 'Totally at home',
    };
    // Decode the next step's photo tiles now, so they are ready as it slides
    // in instead of popping in one by one.
    for (final emphasis in engine.Emphasis.values) {
      precacheImage(AssetImage(_emphasisImage(emphasis)), context);
    }
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 6,
        onBack: () => context.go('/onboarding/experience'),
        title: 'On the gym floor, I feel…',
        child: Column(
          children: [
            for (final choice in choices.entries)
              OptionCard(
                key: ValueKey('comfort-${choice.key.name}'),
                title: choice.value,
                selected: answers.gymComfort == choice.key,
                onTap: () => _selectAndAdvance(
                  ref,
                  context,
                  6,
                  '/onboarding/emphasis',
                  (current) => current.copyWith(gymComfort: choice.key),
                ),
              ),
          ],
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
        step: 7,
        onBack: () => context.go('/onboarding/comfort'),
        title: 'Anywhere you want extra focus?',
        subtitle: "You'll train everything.",
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final choice in choices.entries)
              _EmphasisTile(
                key: ValueKey('emphasis-${choice.key.name}'),
                label: choice.value,
                image: _emphasisImage(choice.key),
                selected: answers.emphasis == choice.key,
                onTap: () => _selectAndAdvance(
                  ref,
                  context,
                  7,
                  '/onboarding/activities',
                  (current) => current.copyWith(emphasis: choice.key),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmphasisTile extends StatelessWidget {
  const _EmphasisTile({
    required this.label,
    required this.image,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressScale(
      child: AnimatedScale(
        scale: selected ? 1.02 : 1,
        duration: AppMotion.duration(context, AppMotion.state),
        curve: AppMotion.standardCurve,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.state),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? AppColors.rose : AppColors.paper,
            borderRadius: AppRadii.mediumBorder,
          ),
          child: Material(
            borderRadius: AppRadii.mediumBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(image, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA2B2028)],
                        stops: [0.48, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.paper,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.rose,
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.paper,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
      engine.ActivityKind.running: ('Cardio', 'Runs, spin, walks.'),
      engine.ActivityKind.yogaPilates: (
        'Yoga or pilates',
        'At home or in class.',
      ),
      engine.ActivityKind.groupClasses: (
        'Classes or sport',
        'Dance, climbing, team sports.',
      ),
    };
    return _withAnswers(
      ref,
      (answers) => QuizPage(
        step: 8,
        onBack: () => context.go('/onboarding/emphasis'),
        title: 'What else do you do?',
        subtitle: '',
        onContinue: () =>
            _completeStep(ref, context, 8, '/onboarding/menstrual'),
        child: Column(
          children: [
            for (final choice in choices.entries)
              _ActivityCard(
                kind: choice.key,
                title: choice.value.$1,
                description: choice.value.$2,
                frequency: answers.otherActivities[choice.key] ?? 0,
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final value in const [1, 2, 3])
                    PillChoice(
                      key: ValueKey('activity-${kind.name}-$value'),
                      value: value,
                      label: value == 3 ? '3×+' : '$value×',
                      selected: frequency == value,
                      onSelected: (selection) => _setFrequency(ref, selection),
                    ),
                  Text('a week', style: Theme.of(context).textTheme.bodySmall),
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
      final ready =
          answers.lastPeriodStart != null && answers.menstrualGap != null;
      void goBack() => context.go('/onboarding/activities');
      return OnboardingBackScope(
        onBack: goBack,
        child: Scaffold(
          backgroundColor: AppColors.paper,
          body: SafeArea(
            child: Column(
              children: [
                OnboardingProgress(step: 9, onBack: goBack),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'When did your last period start?',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _PeriodDateChoices(answers: answers),
                            const SizedBox(height: AppSpacing.xl),
                            const SectionLabel('Usual gap'),
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
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Private to you. Never used for ads.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton(
                          key: const ValueKey('menstrual-finish'),
                          onPressed: ready
                              ? () {
                                  _completeStep(
                                    ref,
                                    context,
                                    9,
                                    '/onboarding/generating',
                                  );
                                }
                              : null,
                          child: const Text('Build my plan'),
                        ),
                        TextButton(
                          key: const ValueKey('menstrual-not-applicable'),
                          onPressed: () => _finishWithoutMenstrualData(
                            context,
                            ref,
                            MenstrualPreference.notApplicable,
                          ),
                          child: const Text("This doesn't fit me"),
                        ),
                        TextButton(
                          key: const ValueKey('menstrual-skip'),
                          onPressed: () => _finishWithoutMenstrualData(
                            context,
                            ref,
                            MenstrualPreference.declined,
                          ),
                          child: const Text('Skip'),
                        ),
                      ],
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
    if (context.mounted) {
      _completeStep(ref, context, 9, '/onboarding/generating');
    }
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
      ('2 weeks', 'ago', now.subtract(const Duration(days: 14))),
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
  final _lineTimers = <Timer>[];
  int _visibleLines = 0;
  int _completedLines = 0;
  bool _linesScheduled = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    unawaited(_generate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_linesScheduled) {
      _linesScheduled = true;
      final minimum = ref.read(minimumGenerationDelayProvider);
      if (AppMotion.isReduced(context) || minimum == Duration.zero) {
        _visibleLines = 3;
        _completedLines = 3;
      } else {
        for (var index = 0; index < 3; index++) {
          _lineTimers.add(
            Timer(minimum * (index * 2 + 1) ~/ 7, () {
              if (mounted) setState(() => _visibleLines = index + 1);
            }),
          );
          _lineTimers.add(
            Timer(minimum * (index * 2 + 2) ~/ 7, () {
              if (mounted) setState(() => _completedLines = index + 1);
            }),
          );
        }
      }
    }
    if (_controller.isAnimating || _controller.isCompleted) return;
    _controller.duration = AppMotion.duration(context, AppMotion.entrance);
    _controller.forward();
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
    for (final timer in _lineTimers) {
      timer.cancel();
    }
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
                              builder: (context, child) {
                                final progress = AppMotion.entranceCurve
                                    .transform(_controller.value);
                                return Transform.scale(
                                  scale: 0.96 + (progress * 0.04),
                                  child: child,
                                );
                              },
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
                              'Building your plan…',
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
                                  answers?.emphasis == engine.Emphasis.balanced
                                  ? 'Planning strength for your whole body'
                                  : 'Balancing your ${_emphasisLabel(answers?.emphasis)} focus',
                              visible: _visibleLines >= 1,
                              done: _completedLines >= 1,
                            ),
                            _GenerationLine(
                              text:
                                  answers?.experienceTier ==
                                      engine.ProfileExperienceTier.newToIt
                                  ? 'Choosing a comfortable start'
                                  : 'Matching your lifting experience',
                              visible: _visibleLines >= 2,
                              done: _completedLines >= 2,
                            ),
                            _GenerationLine(
                              text: _activityGenerationLine(answers),
                              visible: _visibleLines >= 3,
                              done: _completedLines >= 3,
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
  const _GenerationLine({
    required this.text,
    required this.visible,
    required this.done,
  });

  final String text;
  final bool visible;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.25),
      duration: AppMotion.duration(context, AppMotion.state),
      curve: AppMotion.standardCurve,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.duration(context, AppMotion.state),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.state),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: done
                    ? const Icon(
                        key: ValueKey('generation-check'),
                        Icons.check_rounded,
                        color: AppColors.sage,
                        size: AppSpacing.lg,
                      )
                    : const SizedBox.square(
                        key: ValueKey('generation-spinner'),
                        dimension: AppSpacing.lg,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.rose,
                          backgroundColor: AppColors.blush,
                        ),
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
        ),
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

String _emphasisImage(engine.Emphasis emphasis) =>
    'assets/images/emphasis/${emphasis.name}.jpg';

String _emphasisLabel(engine.Emphasis? emphasis) => switch (emphasis) {
  engine.Emphasis.glutes => 'glute',
  engine.Emphasis.legs => 'leg',
  engine.Emphasis.core => 'core',
  engine.Emphasis.arms => 'arm',
  engine.Emphasis.back => 'back',
  _ => 'balanced',
};

String _generationSummary(OnboardingAnswers? answers) {
  if (answers == null) return 'Six weeks built around you.';
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
