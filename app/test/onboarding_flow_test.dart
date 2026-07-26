import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/app.dart';
import 'package:womens_gym/core/navigation/app_router.dart';
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/core/version_gate.dart';
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/features/onboarding/domain/onboarding_answers.dart';

void main() {
  testWidgets(
    'quiz navigation persists each answer and stores generated plan',
    (tester) async {
      _usePhoneSurface(tester);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          deviceLocaleProvider.overrideWithValue(const Locale('en', 'US')),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 7, 26, 10)),
          minimumGenerationDelayProvider.overrideWithValue(Duration.zero),
          startupVersionGateProvider.overrideWith(
            (ref) async => const VersionGateDecision.allowed(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const WomensGymApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weights in lb'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('unit-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Weights in kg'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('unit-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Weights in lb'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-start')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('age-age30To39')));
      await tester.pumpAndSettle();
      expect(
        (await container.read(onboardingRepositoryProvider).load())?.ageBand,
        engine.AgeBand.age30To39,
      );
      await _continue(tester);

      await tester.tap(find.byKey(const ValueKey('goal-tonedAndDefined')));
      await tester.pumpAndSettle();
      await _continue(tester);

      await tester.tap(find.byKey(const ValueKey('days-3')));
      await tester.pumpAndSettle();
      await _continue(tester);

      await tester.tap(find.byKey(const ValueKey('minutes-45')));
      await tester.pumpAndSettle();
      await _continue(tester);

      await tester.tap(find.byKey(const ValueKey('experience-newToIt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('comfort-low')));
      await tester.pumpAndSettle();
      await _continue(tester);

      await tester.tap(find.byKey(const ValueKey('emphasis-glutes')));
      await tester.pumpAndSettle();
      await _continue(tester);

      await tester.tap(find.byKey(const ValueKey('activity-yogaPilates')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('activity-yogaPilates-2')));
      await tester.pumpAndSettle();
      await _continue(tester);

      await tester.tap(find.byKey(const ValueKey('menstrual-skip')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan-reveal-screen')), findsOneWidget);
      expect(find.textContaining('Strong & Toned'), findsOneWidget);
      expect(find.text('Start my first workout'), findsOneWidget);

      final answers = await container.read(onboardingRepositoryProvider).load();
      expect(answers?.unitSystem, engine.UnitSystem.imperial);
      expect(answers?.goal, engine.Goal.tonedAndDefined);
      expect(answers?.daysPerWeek, engine.TrainingDaysPerWeek.three);
      expect(answers?.sessionMinutes, engine.SessionMinutes.fortyFive);
      expect(answers?.experienceTier, engine.ProfileExperienceTier.newToIt);
      expect(answers?.gymComfort, engine.GymComfort.low);
      expect(answers?.emphasis, engine.Emphasis.glutes);
      expect(answers?.otherActivities[engine.ActivityKind.yogaPilates], 2);
      expect(answers?.menstrualPreference, MenstrualPreference.declined);
      expect(answers?.completed, isTrue);
      expect(await database.select(database.plans).get(), hasLength(1));
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets('menstrual opt-in stores only the two optional profile values', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 7, 26, 10)),
        minimumGenerationDelayProvider.overrideWithValue(Duration.zero),
        startupVersionGateProvider.overrideWith(
          (ref) async => const VersionGateDecision.allowed(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(onboardingRepositoryProvider)
        .save(
          const OnboardingAnswers(
            unitSystem: engine.UnitSystem.metric,
            ageBand: engine.AgeBand.age40To49,
            goal: engine.Goal.stronger,
            daysPerWeek: engine.TrainingDaysPerWeek.two,
            sessionMinutes: engine.SessionMinutes.thirty,
            experienceTier: engine.ProfileExperienceTier.beenAWhile,
            gymComfort: engine.GymComfort.mostlyFine,
            emphasis: engine.Emphasis.balanced,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/onboarding/menstrual');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('menstrual-date-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menstrual-gap-days28')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menstrual-finish')));
    await tester.pumpAndSettle();

    final profile = await database.select(database.profiles).getSingle();
    final answers = await container.read(onboardingRepositoryProvider).load();
    expect(profile.lastPeriodStart, DateTime(2026, 7, 21));
    expect(profile.usualGapDays, 28);
    expect(answers?.menstrualPreference, MenstrualPreference.optedIn);
    expect(find.byKey(const ValueKey('plan-reveal-screen')), findsOneWidget);
    await _disposeWidgetTree(tester);
  });
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
