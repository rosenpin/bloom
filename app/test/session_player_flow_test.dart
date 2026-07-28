import 'dart:io';

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
import 'package:womens_gym/features/session/data/exercise_video_cache.dart';
import 'package:womens_gym/features/session/data/exercise_video_source.dart';
import 'package:womens_gym/features/session/data/session_event_codec.dart';
import 'package:womens_gym/features/session/presentation/exercise_visual.dart';

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
      expect(find.textContaining('Dumbbell Curl'), findsOneWidget);

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
      expect(find.text('8 reps'), findsOneWidget);
      expect(find.text('with 2 kg'), findsOneWidget);
      expect(find.byKey(const ValueKey('unit-prompt')), findsOneWidget);

      await _tap(tester, const ValueKey('switch-units'));
      expect(find.text('8 reps'), findsOneWidget);
      expect(find.text('with 4.4 lb'), findsOneWidget);

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
    await _tap(tester, const ValueKey('exercise-setup-link'));
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
        exerciseVideoCacheProvider.overrideWith(
          (ref) async => _SilentVideoCache(),
        ),
        exerciseVideoPlaybackBuilderProvider.overrideWithValue(
          _silentVideoPlaybackBuilder,
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

Widget _silentVideoPlaybackBuilder({
  required Key key,
  required String exerciseId,
  required ExerciseVideoSource source,
  required Widget placeholder,
}) => ColoredBox(key: key, color: Colors.transparent);

final class _SilentVideoCache implements ExerciseVideoCache {
  @override
  Future<File> getFile(String remoteUrl) =>
      throw UnsupportedError('Video files are not loaded in widget tests.');

  @override
  Future<void> prefetch(Iterable<String> remoteUrls) async {}
}
