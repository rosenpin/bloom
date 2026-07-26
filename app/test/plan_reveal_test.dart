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
  testWidgets('reveal renders the generated plan contents', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
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
    expect(find.text('Strong & Toned — Core Focus'), findsOneWidget);
    expect(find.text('2 gym days · core focus'), findsOneWidget);
    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('Full Body B'), findsOneWidget);
    expect(
      find.textContaining(
        '${generated.plan.days.first.exercises.length} exercises',
      ),
      findsWidgets,
    );
    expect(find.text('Start my first workout'), findsOneWidget);
    expect(find.text('Tweak my plan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
