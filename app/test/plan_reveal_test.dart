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
import 'package:womens_gym/features/plan/domain/plan_presentation.dart';

import 'support/premium_entitlements.dart';

void main() {
  test('plan dose labels use ranges and timed seconds', () {
    expect(
      PlanPresentation.doseLabel(
        const engine.RepsDose(
          sets: 3,
          range: engine.RepRange(8, 10),
          effort: engine.EffortTarget.rpe7,
          targetReps: 8,
        ),
      ),
      '3 sets × 8-10',
    );
    expect(
      PlanPresentation.doseLabel(
        const engine.RepsDose(
          sets: 3,
          range: engine.RepRange(12, 12),
          effort: engine.EffortTarget.rpe7,
          targetReps: 12,
        ),
      ),
      '3 sets × 12',
    );
    expect(
      PlanPresentation.doseLabel(
        const engine.TimedDose(sets: 2, hold: Duration(seconds: 30)),
      ),
      '2 sets × 30 sec',
    );
  });

  testWidgets('reveal renders the generated plan contents', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        entitlementServiceProvider.overrideWithValue(
          const PremiumEntitlements(),
        ),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 7, 26, 10)),
        startupVersionGateProvider.overrideWith(
          (ref) async => const VersionGateDecision.allowed(),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await container
        .read(onboardingRepositoryProvider)
        .save(
          const OnboardingAnswers(
            unitSystem: engine.UnitSystem.metric,
            ageBand: engine.AgeBand.age30To39,
            goal: engine.Goal.tonedAndDefined,
            daysPerWeek: engine.TrainingDaysPerWeek.two,
            sessionMinutes: engine.SessionMinutes.thirty,
            experienceTier: engine.ProfileExperienceTier.beenAWhile,
            gymComfort: engine.GymComfort.mostlyFine,
            emphasis: engine.Emphasis.core,
          ),
        );
    final generated = await container
        .read(planGenerationServiceProvider)
        .generate();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/onboarding/reveal');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-reveal-screen')), findsOneWidget);
    expect(find.text('Strong & Toned · Core Focus'), findsOneWidget);
    expect(find.text('2 gym days · core focus'), findsOneWidget);
    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('Full Body B'), findsOneWidget);
    expect(
      find.textContaining(
        '${generated.plan.days.first.exercises.length} exercises',
      ),
      findsWidgets,
    );
    expect(find.text('Start my plan'), findsOneWidget);
    expect(find.text('Change my answers'), findsOneWidget);
    expect(find.text('Your six weeks'), findsOneWidget);
    expect(find.text('Easier week'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-day-card-1')));
    await tester.pumpAndSettle();

    final firstDay = generated.plan.days.first;
    expect(
      find.byKey(const ValueKey('plan-day-detail-screen')),
      findsOneWidget,
    );
    expect(find.text(PlanPresentation.dayName(firstDay, null)), findsOneWidget);
    expect(
      find.text(
        '30 min · ${firstDay.exercises.length} exercises · warm-up included',
      ),
      findsOneWidget,
    );
    expect(
      find.text(PlanPresentation.doseLabel(firstDay.exercises.first.baseDose)),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('plan-day-start-workout')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
