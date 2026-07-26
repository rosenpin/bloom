import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/app.dart';
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/core/version_gate.dart';
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/features/onboarding/domain/onboarding_answers.dart';

void main() {
  testWidgets('first run redirects to onboarding', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 7, 26, 10)),
          startupVersionGateProvider.overrideWith(
            (ref) async => const VersionGateDecision.allowed(),
          ),
        ],
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your gym plan,\nmade for you.'), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-screen')), findsNothing);
    await _disposeWidgetTree(tester);
  });

  testWidgets('completed profile opens three-tab shell and switches branches', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 7, 26, 10)),
        startupVersionGateProvider.overrideWith(
          (ref) async => const VersionGateDecision.allowed(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(onboardingRepositoryProvider)
        .save(_completeAnswers(completed: true));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-screen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-screen')), findsOneWidget);
    expect(find.text('Build my plan'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-screen')), findsOneWidget);
    expect(
      find.text(
        'Your preferences and progress will live here, quietly remembered.',
      ),
      findsOneWidget,
    );
    await _disposeWidgetTree(tester);
  });
}

OnboardingAnswers _completeAnswers({required bool completed}) =>
    OnboardingAnswers(
      unitSystem: engine.UnitSystem.metric,
      ageBand: engine.AgeBand.age30To39,
      goal: engine.Goal.tonedAndDefined,
      daysPerWeek: engine.TrainingDaysPerWeek.three,
      sessionMinutes: engine.SessionMinutes.fortyFive,
      experienceTier: engine.ProfileExperienceTier.newToIt,
      gymComfort: engine.GymComfort.low,
      emphasis: engine.Emphasis.glutes,
      completed: completed,
    );

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
