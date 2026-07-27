import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/app.dart';
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/core/version_gate.dart';
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/data/db/schema.dart';
import 'package:womens_gym/features/session/application/rest_timer_foundation.dart';
import 'package:womens_gym/features/session/data/session_event_codec.dart';

import 'support/session_test_support.dart';

void main() {
  testWidgets(
    'scripted 390x844 session calibrates, logs, swaps, shortens and keeps swap',
    (tester) async {
      final harness = await _SessionHarness.create(tester);
      addTearDown(harness.dispose);

      await _tap(tester, const ValueKey('start-workout'));
      expect(
        find.byKey(const ValueKey('session-start-heading')),
        findsOneWidget,
      );
      await _tap(tester, const ValueKey('session-lets-go'));

      expect(find.byKey(const ValueKey('calibration-card')), findsOneWidget);
      await _tap(tester, const ValueKey('calibration-done'));
      expect(find.byKey(const ValueKey('rest-countdown')), findsOneWidget);
      await _tap(tester, const ValueKey('effort-justRight'));

      expect(find.byKey(const ValueKey('set-done')), findsOneWidget);
      await _tap(tester, const ValueKey('set-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      await _tap(tester, const ValueKey('rest-skip'));

      expect(find.text('Dumbbell Lateral Raise'), findsWidgets);
      await _tap(tester, const ValueKey('life-happened-link'));
      await _tap(tester, const ValueKey('life-busy'));
      expect(find.text('Choose a swap'), findsOneWidget);
      await _tap(tester, const ValueKey('swap-candidate-dumbbell-curl'));
      expect(find.text('Dumbbell Curl'), findsWidgets);

      await _tap(tester, const ValueKey('life-happened-link'));
      await _tap(tester, const ValueKey('life-shorten'));
      await _tap(tester, const ValueKey('shorten-15'));

      expect(
        find.byKey(const ValueKey('session-complete-heading')),
        findsOneWidget,
      );
      expect(find.text("Keep today's swap?"), findsOneWidget);
      await _tap(tester, const ValueKey('keep-swap-yes'));
      await _tap(tester, const ValueKey('session-complete-done'));
      expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);

      final editedDocument = await harness.container
          .read(planRepositoryProvider)
          .loadLatest();
      expect(
        editedDocument!.plan.days.single.exercises[1].exerciseId,
        'dumbbell-curl',
      );
      expect(editedDocument.plan.editStamps, hasLength(1));

      final records = await harness.database
          .select(harness.database.sessionRecords)
          .get();
      final events = await harness.database.sessionEventLog(records.single.id);
      expect(records.single.completedAt, isNot(equals(null)));
      expect(records.single.planRef, editedDocument.plan.reference);
      expect(
        events.map((row) => row.type),
        containsAll([
          StoredSessionEventType.setCompleted,
          StoredSessionEventType.effortReported,
          StoredSessionEventType.swapRequested,
          StoredSessionEventType.shorten,
        ]),
      );
    },
  );

  testWidgets(
    'first session converts the rendered load after switching units',
    (tester) async {
      final harness = await _SessionHarness.create(tester);
      addTearDown(harness.dispose);

      await _tap(tester, const ValueKey('start-workout'));
      await _tap(tester, const ValueKey('session-lets-go'));
      expect(find.textContaining('2 kg × 8 easy reps'), findsOneWidget);
      expect(find.byKey(const ValueKey('unit-prompt')), findsOneWidget);

      await _tap(tester, const ValueKey('switch-units'));
      expect(find.textContaining('4.4 lb × 8 easy reps'), findsOneWidget);

      await _tap(tester, const ValueKey('calibration-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      expect(find.text('8 × 4.4 lb'), findsOneWidget);

      final profile = await harness.database
          .select(harness.database.profiles)
          .getSingle();
      expect(profile.unitSystem, engine.UnitSystem.imperial);
      expect(profile.unitPromptSeen, isTrue);
    },
  );

  testWidgets('a two-week layoff renders the comeback start variant', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(
      tester,
      seedCompletedSessionDaysAgo: 14,
    );
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    expect(find.byKey(const ValueKey('comeback-heading')), findsOneWidget);
    expect(find.text('Where were we?'), findsOneWidget);
    expect(find.byKey(const ValueKey('use-usual-weights')), findsOneWidget);
    expect(find.textContaining('down about 10%'), findsOneWidget);

    await _tap(tester, const ValueKey('use-usual-weights'));
    expect(find.text('10 kg · 10 reps'), findsOneWidget);
  });

  testWidgets('the first layoff tier gets a quiet comeback start', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(
      tester,
      seedCompletedSessionDaysAgo: 8,
    );
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    expect(find.byKey(const ValueKey('comeback-heading')), findsOneWidget);
    expect(find.textContaining('usual weights are ready'), findsWidgets);
    expect(find.byKey(const ValueKey('use-usual-weights')), findsNothing);
  });

  testWidgets('pain stops the exercise, persists it and offers a warm swap', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(tester);
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    await _tap(tester, const ValueKey('session-lets-go'));
    await _tap(tester, const ValueKey('pain-affordance'));
    expect(find.text('Leave that movement there.'), findsOneWidget);
    await _tap(tester, const ValueKey('pain-knee'));

    expect(find.text('Choose a swap'), findsOneWidget);
    await _tap(tester, const ValueKey('swap-candidate-bodyweight-squat'));
    expect(find.text('Bodyweight Squat'), findsWidgets);

    final preference = await harness.database
        .select(harness.database.userExercisePrefs)
        .getSingle();
    expect(preference.exerciseId, 'dumbbell-goblet-squat');
    expect(preference.excluded, isTrue);
    expect(preference.source, UserExercisePreferenceSource.pain);
  });
}

Future<void> _tap(WidgetTester tester, ValueKey<String> key) async {
  final finder = find.byKey(key);
  expect(
    finder,
    findsOneWidget,
    reason: 'Missing widget with key ${key.value}',
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle(const Duration(milliseconds: 20));
}

final class _SessionHarness {
  _SessionHarness(this.database, this.container, this.tester);

  final AppDatabase database;
  final ProviderContainer container;
  final WidgetTester tester;

  static Future<_SessionHarness> create(
    WidgetTester tester, {
    int? seedCompletedSessionDaysAgo,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.utc(2026, 7, 26, 10);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => now),
        startupVersionGateProvider.overrideWith(
          (ref) async => const VersionGateDecision.allowed(),
        ),
        restNotificationSchedulerProvider.overrideWithValue(_SilentScheduler()),
      ],
    );
    final document = await storeSessionTestPlan(container);
    if (seedCompletedSessionDaysAgo case final days?) {
      await _seedCompletedSession(
        database,
        document.row.id,
        document.plan.reference,
        now.subtract(Duration(days: days)),
      );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();
    return _SessionHarness(database, container, tester);
  }

  Future<void> dispose() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await database.close();
  }

  static Future<void> _seedCompletedSession(
    AppDatabase database,
    String planId,
    String planRef,
    DateTime startedAt,
  ) async {
    const sessionId = '01K1COMEBACK00000000000000';
    await database
        .into(database.sessionRecords)
        .insert(
          SessionRecordsCompanion.insert(
            id: sessionId,
            planId: planId,
            planRef: Value(planRef),
            dayIndex: 1,
            mesocycleIndex: const Value(1),
            mesocycleWeekIndex: const Value(1),
            absoluteWeekIndex: const Value(1),
            weekKind: const Value(engine.MesocycleWeekKind.build),
            startedAt: startedAt,
            completedAt: Value(startedAt.add(const Duration(minutes: 30))),
          ),
        );
    final event = engine.SetCompleted(
      exerciseId: 'dumbbell-goblet-squat',
      setIndex: 1,
      load: engine.Kg(10),
      reps: 10,
      unitSystem: engine.UnitSystem.metric,
      targetReps: 10,
      targetRpe: 7,
      prescribedLoad: engine.Kg(10),
    );
    final encoded = SessionEventCodec.encode(event);
    await database.appendSessionEvent(
      SessionEventsCompanion.insert(
        id: '01K1COMEBACKEVENT0000000000',
        sessionId: sessionId,
        seq: 0,
        type: encoded.type,
        payloadJson: encoded.payloadJson,
        recordedAt: startedAt.add(const Duration(minutes: 29)),
        unitSystemAtEntry: engine.UnitSystem.metric,
      ),
    );
  }
}

final class _SilentScheduler implements RestNotificationScheduler {
  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {}
}
