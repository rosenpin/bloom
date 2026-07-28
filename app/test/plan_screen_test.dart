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
import 'package:womens_gym/features/plan/domain/plan_presentation.dart';
import 'package:womens_gym/features/session/data/session_event_codec.dart';

void main() {
  testWidgets('plan tab shows week states and opens read-only days', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.utc(2026, 7, 28, 10);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => now),
        startupVersionGateProvider.overrideWith(
          (ref) async => const VersionGateDecision.allowed(),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    const answers = OnboardingAnswers(
      unitSystem: engine.UnitSystem.metric,
      ageBand: engine.AgeBand.age30To39,
      goal: engine.Goal.tonedAndDefined,
      daysPerWeek: engine.TrainingDaysPerWeek.three,
      sessionMinutes: engine.SessionMinutes.fortyFive,
      experienceTier: engine.ProfileExperienceTier.newToIt,
      gymComfort: engine.GymComfort.low,
      emphasis: engine.Emphasis.glutes,
    );
    await container.read(onboardingRepositoryProvider).save(answers);
    final document = await container
        .read(planGenerationServiceProvider)
        .generate();
    await database
        .into(database.sessionRecords)
        .insert(
          SessionRecordRow(
            id: 'completed-day-1',
            planId: document.row.id,
            planRef: document.plan.reference,
            dayIndex: 1,
            mesocycleIndex: 1,
            mesocycleWeekIndex: 1,
            absoluteWeekIndex: 1,
            weekKind: engine.MesocycleWeekKind.build,
            startedAt: DateTime.utc(2026, 7, 27, 10),
            completedAt: DateTime.utc(2026, 7, 27, 10, 45),
          ),
        );
    final completedEvent = SessionEventCodec.encode(
      engine.EffortReported(
        exerciseId: document.plan.days.first.exercises.first.exerciseId,
        level: engine.EffortLevel.justRight,
      ),
    );
    await database
        .into(database.sessionEvents)
        .insert(
          SessionEventRow(
            id: 'completed-day-1-effort',
            sessionId: 'completed-day-1',
            seq: 0,
            type: completedEvent.type,
            payloadJson: completedEvent.payloadJson,
            recordedAt: DateTime.utc(2026, 7, 27, 10, 44),
            unitSystemAtEntry: engine.UnitSystem.metric,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-tab')));
    await tester.pumpAndSettle();

    expect(find.text(PlanPresentation.planName(answers)), findsOneWidget);
    expect(find.text('3 days a week'), findsOneWidget);
    expect(find.text('Glute focus'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('All weeks'), findsOneWidget);
    expect(find.text('MONDAY · DONE'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-all-weeks-view')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-week-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-week-6')), findsOneWidget);
    expect(find.text('Lighter week'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-week-view')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-day-card-3')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('plan-day-detail-screen')),
      findsOneWidget,
    );
    expect(
      find.text(PlanPresentation.dayName(document.plan.days[2], answers)),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-day-start-workout')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-day-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-day-card-2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-day-start-workout')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
