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
import 'package:womens_gym/features/session/application/session_controller.dart';
import 'package:womens_gym/core/theme/app_colors.dart';
import 'package:womens_gym/features/session/data/exercise_visual_source.dart';
import 'package:womens_gym/features/session/data/session_event_codec.dart';
import 'package:womens_gym/features/session/presentation/exercise_visual.dart';

import 'support/session_test_support.dart';
import 'support/premium_entitlements.dart';

void main() {
  testWidgets('exercise actions stay visible on a small phone', (tester) async {
    final harness = await _SessionHarness.create(tester);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(320, 568);

    await _tap(tester, const ValueKey('start-workout'));
    await _tap(tester, const ValueKey('session-lets-go'));
    _expectPinnedActions(tester, const ValueKey('calibration-done'));

    await _tap(tester, const ValueKey('calibration-done'));
    expect(
      (await harness.database.select(harness.database.profiles).getSingle())
          .unitPromptSeen,
      isTrue,
    );
    await _tap(tester, const ValueKey('effort-justRight'));
    await _tap(tester, const ValueKey('rest-skip'));
    _expectPinnedActions(tester, const ValueKey('set-done'));
  });

  for (final level in engine.EffortLevel.values) {
    testWidgets('feel step ${level.value} records ${level.name}', (
      tester,
    ) async {
      final harness = await _SessionHarness.create(tester);
      addTearDown(harness.dispose);

      await _tap(tester, const ValueKey('start-workout'));
      await _tap(tester, const ValueKey('session-lets-go'));
      await _tap(tester, const ValueKey('calibration-done'));
      await _tap(tester, ValueKey('effort-${level.name}'));
      expect(find.textContaining('${level.value}'), findsWidgets);
      final selectedMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(ValueKey('effort-${level.name}')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(selectedMaterial.color, AppColors.rose);
      await _tap(tester, const ValueKey('rest-skip'));
      final events = harness.container
          .read(sessionControllerProvider)
          .value!
          .state
          .events;
      expect(events.whereType<engine.EffortReported>().last.level, level);
    });
  }

  testWidgets(
    'seen exercise uses the compact learn strip and opens the teach view',
    (tester) async {
      final harness = await _SessionHarness.create(
        tester,
        seedCompletedSessionDaysAgo: 1,
      );
      addTearDown(harness.dispose);

      await _tap(tester, const ValueKey('start-workout'));
      await _tap(tester, const ValueKey('session-lets-go'));

      expect(find.byKey(const ValueKey('learn-strip')), findsOneWidget);
      expect(find.byKey(const ValueKey('new-move-card')), findsNothing);
      expect(find.text('Show me how'), findsOneWidget);
      expect(find.text('Movement, setup and where to find it'), findsOneWidget);
      expect(find.byKey(const ValueKey('watch-movement')), findsNothing);
      expect(find.text('How do I set up?'), findsNothing);
      expect(find.text('Up next · Dumbbell Lateral Raise'), findsOneWidget);

      await _tap(tester, const ValueKey('ambient-session-overview'));
      expect(
        find.byKey(const ValueKey('session-overview-sheet')),
        findsOneWidget,
      );
      await _tap(tester, const ValueKey('close-session-overview'));

      await _tap(tester, const ValueKey('show-me-how'));
      expect(
        find.byKey(const ValueKey('exercise-teach-screen')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('teach-visual')), findsOneWidget);
      expect(find.text('Beginner friendly'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
      expect(find.text('How it feels'), findsOneWidget);
      expect(find.text('Swaps'), findsOneWidget);
    },
  );

  testWidgets('unseen active exercise uses the expanded new move card', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(tester);
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    await _tap(tester, const ValueKey('session-lets-go'));
    expect(find.byKey(const ValueKey('calibration-heading')), findsOneWidget);

    await _tap(tester, const ValueKey('life-happened-link'));
    await _tap(tester, const ValueKey('life-busy'));
    await _tap(tester, const ValueKey('swap-candidate-bodyweight-squat'));

    expect(find.byKey(const ValueKey('new-move-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-move-chip')), findsOneWidget);
    expect(find.text('NEW MOVE'), findsOneWidget);
    expect(
      find.text('Show me how · movement, setup and where to find it'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('learn-strip')), findsNothing);
    expect(find.byKey(const ValueKey('prescription-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('watch-movement')), findsNothing);
  });

  testWidgets('last exercise uses the E1 final copy in calibration mode', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(tester);
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    await _tap(tester, const ValueKey('session-lets-go'));
    await _tap(tester, const ValueKey('calibration-done'));
    await _tap(tester, const ValueKey('effort-justRight'));
    await _tap(tester, const ValueKey('rest-skip'));
    await _tap(tester, const ValueKey('set-done'));
    await _tap(tester, const ValueKey('effort-justRight'));
    await _tap(tester, const ValueKey('rest-skip'));

    expect(find.byKey(const ValueKey('calibration-heading')), findsOneWidget);
    expect(find.text("Last one · then you're done"), findsOneWidget);
    expect(find.byKey(const ValueKey('exercise-action-zone')), findsOneWidget);
  });

  testWidgets(
    'session overview shows current upcoming and completed exercise states',
    (tester) async {
      final harness = await _SessionHarness.create(
        tester,
        seedCompletedSessionDaysAgo: 1,
      );
      addTearDown(harness.dispose);

      await _tap(tester, const ValueKey('start-workout'));
      await _tap(tester, const ValueKey('session-lets-go'));
      await _tap(tester, const ValueKey('exercise-progress'));

      expect(
        find.byKey(const ValueKey('session-overview-sheet')),
        findsOneWidget,
      );
      expect(find.text('Your session'), findsOneWidget);
      expect(
        find.text('A little look back, and what is waiting for you.'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('overview-current')), findsOneWidget);
      expect(find.text('NOW'), findsOneWidget);
      expect(find.text('set 1 of 2 · 10 kg'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('overview-upcoming-dumbbell-lateral-raise')),
        findsOneWidget,
      );
      expect(find.textContaining('2 sets × '), findsOneWidget);
      expect(find.byKey(const ValueKey('session-overview-note')), findsNothing);

      await _tap(
        tester,
        const ValueKey('overview-upcoming-dumbbell-lateral-raise'),
      );
      expect(
        find.byKey(const ValueKey('session-overview-sheet')),
        findsOneWidget,
      );
      await _tap(tester, const ValueKey('close-session-overview'));

      await _tap(tester, const ValueKey('set-done'));
      await _tap(tester, const ValueKey('rest-skip'));
      await _tap(tester, const ValueKey('set-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      await _tap(tester, const ValueKey('rest-skip'));
      await _tap(tester, const ValueKey('exercise-progress'));

      expect(
        find.byKey(const ValueKey('overview-completed-dumbbell-goblet-squat')),
        findsOneWidget,
      );
      expect(find.text('2 sets done · 10 kg'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview-current')), findsOneWidget);

      await _tap(
        tester,
        const ValueKey('overview-completed-dumbbell-goblet-squat'),
      );
      expect(
        find.byKey(const ValueKey('completed-exercise-review')),
        findsOneWidget,
      );
      expect(
        find.text('2 sets logged. Tap one if the numbers need a correction.'),
        findsOneWidget,
      );
      expect(find.text('Set 1'), findsOneWidget);
      expect(find.text('Set 2'), findsOneWidget);
      expect(find.text('10 reps · 10 kg'), findsNWidgets(2));
    },
  );

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
      expect(find.byKey(const ValueKey('rest-countdown')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-done')), findsNothing);
      await _tap(tester, const ValueKey('rest-skip'));

      expect(find.byKey(const ValueKey('set-done')), findsOneWidget);
      await _tap(tester, const ValueKey('set-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      await _tap(tester, const ValueKey('rest-skip'));

      expect(find.byKey(const ValueKey('calibration-heading')), findsOneWidget);
      expect(find.textContaining('Dumbbell Lateral Raise'), findsOneWidget);
      await _tap(tester, const ValueKey('life-happened-link'));
      await _tap(tester, const ValueKey('life-busy'));
      expect(find.text('Choose a swap'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
      expect(find.textContaining('Tier '), findsNothing);
      await _tap(tester, const ValueKey('swap-candidate-dumbbell-curl'));
      expect(find.text('Dumbbell Curl'), findsOneWidget);

      await _tap(tester, const ValueKey('life-happened-link'));
      await _tap(tester, const ValueKey('life-shorten'));
      await _tap(tester, const ValueKey('shorten-15'));
      expect(
        find.text('Trimmed to the essentials. About 15 minutes.'),
        findsOneWidget,
      );

      expect(
        find.byKey(const ValueKey('session-complete-heading')),
        findsOneWidget,
      );
      expect(find.text("Keep today's swap?"), findsOneWidget);
      await _tap(tester, const ValueKey('keep-swap-yes'));
      expect(find.text("That's your workout."), findsOneWidget);
      expect(find.text('Show me my recap'), findsOneWidget);
      await _tap(tester, const ValueKey('session-complete-recap'));
      expect(find.byKey(const ValueKey('share-recap-screen')), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      await _tap(tester, const ValueKey('share-recap-later'));
      expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('start-workout')),
        findsNothing,
        reason: 'Today must not offer the completed session again.',
      );
      expect(find.textContaining('DONE ·'), findsOneWidget);
      expect(find.textContaining('felt just right'), findsOneWidget);
      expect(find.byKey(const ValueKey('see-what-you-did')), findsOneWidget);

      await _tap(tester, const ValueKey('see-what-you-did'));
      expect(
        find.byKey(const ValueKey('session-summary-screen')),
        findsOneWidget,
      );
      expect(find.text('WHAT YOU DID'), findsOneWidget);
      expect(find.text('Set 1'), findsOneWidget);
      await _tap(tester, const ValueKey('session-summary-back'));
      final completedSessionId =
          (await harness.database
                  .select(harness.database.sessionRecords)
                  .getSingle())
              .id;
      await _tap(tester, const ValueKey('me-tab'));
      expect(
        find.byKey(ValueKey('history-session-$completedSessionId')),
        findsOneWidget,
      );
      await _tap(tester, ValueKey('history-session-$completedSessionId'));
      expect(
        find.byKey(const ValueKey('session-summary-screen')),
        findsOneWidget,
      );

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
      expect(find.text('8 reps · 2 kg'), findsOneWidget);
      expect(find.byKey(const ValueKey('unit-prompt')), findsOneWidget);

      await _tap(tester, const ValueKey('unit-lb'));
      expect(find.text('8 reps · 4.4 lb'), findsOneWidget);

      await _tap(tester, const ValueKey('calibration-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      expect(find.byKey(const ValueKey('rest-countdown')), findsOneWidget);
      await _tap(tester, const ValueKey('rest-skip'));
      expect(find.text('8 × 4.4 lb'), findsOneWidget);

      final profile = await harness.database
          .select(harness.database.profiles)
          .getSingle();
      expect(profile.unitSystem, engine.UnitSystem.imperial);
      expect(profile.unitPromptSeen, isTrue);
    },
  );

  testWidgets('a same-day unfinished session gets the warm resume path', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(tester);
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    await tester.tap(find.widgetWithText(TextButton, 'Today'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('start-workout')), findsNothing);
    expect(find.byKey(const ValueKey('resume-workout')), findsOneWidget);
    expect(find.text('Pick up where you left off'), findsOneWidget);

    await _tap(tester, const ValueKey('resume-workout'));
    expect(find.byKey(const ValueKey('session-start-heading')), findsOneWidget);
  });

  testWidgets(
    'a partial equipment swap keeps completed work and shows one remaining set',
    (tester) async {
      final harness = await _SessionHarness.create(tester);
      addTearDown(harness.dispose);

      await _tap(tester, const ValueKey('start-workout'));
      await _tap(tester, const ValueKey('session-lets-go'));
      await _tap(tester, const ValueKey('calibration-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      await _tap(tester, const ValueKey('rest-skip'));

      await _tap(tester, const ValueKey('life-happened-link'));
      await _tap(tester, const ValueKey('life-busy'));
      await _tap(tester, const ValueKey('swap-candidate-bodyweight-squat'));

      expect(find.byKey(const ValueKey('saved-swap-work')), findsOneWidget);
      expect(
        find.text(
          'Your 1 Goblet Squat set is saved. Only the remaining work moved here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Set 1 of 1'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);

      await _tap(tester, const ValueKey('set-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      await _tap(tester, const ValueKey('rest-skip'));
      await _tap(tester, const ValueKey('calibration-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      await _tap(tester, const ValueKey('rest-skip'));
      await _tap(tester, const ValueKey('set-done'));
      await _tap(tester, const ValueKey('effort-justRight'));
      await _tap(tester, const ValueKey('rest-skip'));

      expect(find.byKey(const ValueKey('mixed-swap-recap')), findsOneWidget);
      expect(
        find.text('1 Goblet Squat set + 1 Bodyweight Squat set'),
        findsOneWidget,
      );
    },
  );

  testWidgets('low energy is visible and a second tap still answers', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(
      tester,
      seedCompletedSessionDaysAgo: 1,
    );
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    await _tap(tester, const ValueKey('session-lets-go'));
    expect(find.text('10 kg · 10 reps'), findsOneWidget);
    await _tap(tester, const ValueKey('life-happened-link'));
    await _tap(tester, const ValueKey('life-low-energy'));

    expect(
      find.text('We made today lighter. Same moves, friendlier weights.'),
      findsOneWidget,
    );
    expect(find.text('8 kg · 10 reps'), findsOneWidget);

    await _tap(tester, const ValueKey('life-happened-link'));
    await _tap(tester, const ValueKey('life-low-energy'));
    expect(find.text('Today is already lighter.'), findsOneWidget);
  });

  testWidgets('shorten is visible, idempotent, and setup swaps use medals', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(tester);
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    await _tap(tester, const ValueKey('session-lets-go'));
    await _tap(tester, const ValueKey('watch-movement'));
    expect(find.byKey(const ValueKey('exercise-teach-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('teach-visual')), findsOneWidget);
    expect(find.text('Beginner friendly'), findsOneWidget);
    await tester.tap(find.text('Swaps'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel(RegExp('Gold match medal')), findsWidgets);
    } finally {
      semantics.dispose();
    }
    expect(find.textContaining('Tier '), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tap(tester, const ValueKey('life-happened-link'));
    await _tap(tester, const ValueKey('life-shorten'));
    await _tap(tester, const ValueKey('shorten-20'));
    expect(
      find.text('Trimmed to the essentials. About 20 minutes.'),
      findsOneWidget,
    );

    await _tap(tester, const ValueKey('life-happened-link'));
    await _tap(tester, const ValueKey('life-shorten'));
    await _tap(tester, const ValueKey('shorten-20'));
    expect(
      find.text('Today is already trimmed to about 20 minutes.'),
      findsOneWidget,
    );
  });

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
    expect(find.textContaining('down about 5%'), findsOneWidget);

    await _tap(tester, const ValueKey('use-usual-weights'));
    expect(find.text('10 kg · 10 reps'), findsOneWidget);
  });

  testWidgets('the first day after grace gets the continuous adjustment', (
    tester,
  ) async {
    final harness = await _SessionHarness.create(
      tester,
      seedCompletedSessionDaysAgo: 8,
    );
    addTearDown(harness.dispose);

    await _tap(tester, const ValueKey('start-workout'));
    expect(find.byKey(const ValueKey('comeback-heading')), findsOneWidget);
    expect(find.textContaining('down about 1%'), findsOneWidget);
    expect(find.byKey(const ValueKey('use-usual-weights')), findsOneWidget);
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

void _expectPinnedActions(WidgetTester tester, ValueKey<String> primaryKey) {
  final primary = find.byKey(primaryKey);
  expect(primary, findsOneWidget);
  expect(tester.getRect(primary).bottom, lessThanOrEqualTo(568));
  expect(
    tester.getRect(find.byKey(const ValueKey('pain-affordance'))).bottom,
    lessThanOrEqualTo(568),
  );
  expect(
    find.ancestor(of: primary, matching: find.byType(SingleChildScrollView)),
    findsNothing,
  );
  expect(tester.takeException(), equals(null));
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
        entitlementServiceProvider.overrideWithValue(
          const PremiumEntitlements(),
        ),
        clockProvider.overrideWithValue(() => now),
        startupVersionGateProvider.overrideWith(
          (ref) async => const VersionGateDecision.allowed(),
        ),
        restNotificationSchedulerProvider.overrideWithValue(_SilentScheduler()),
        exerciseVisualPlaybackBuilderProvider.overrideWith(
          (ref) => _silentVisualPlaybackBuilder,
        ),
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

Widget _silentVisualPlaybackBuilder({
  required Key key,
  required ExerciseVisualSource source,
  required Widget placeholder,
}) => ColoredBox(key: key, color: Colors.transparent);
