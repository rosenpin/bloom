import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/app.dart';
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/core/version_gate.dart';
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/features/onboarding/domain/onboarding_answers.dart';

import 'support/premium_entitlements.dart';
import 'support/session_test_support.dart';

void main() {
  testWidgets('training day starts with a plan, then offers resume', (
    tester,
  ) async {
    final harness = await _TodayHarness.create(
      tester,
      DateTime.utc(2026, 9, 21, 10),
    );
    await harness.pump(tester);
    expect(find.text('Lower body today. About 30 minutes.'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-workout')), findsOneWidget);
    expect(find.text('Week 1 of 6 · Build week'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-month-card')), findsNothing);

    await harness.insertSession(completed: false);
    harness.container.invalidate(sessionPreviewProvider);
    await tester.pumpAndSettle();
    expect(find.text('Pick up where you left off.'), findsWidgets);
    expect(find.byKey(const ValueKey('resume-workout')), findsOneWidget);
  });

  testWidgets('completed session has a calm state line', (tester) async {
    final done = await _TodayHarness.create(
      tester,
      DateTime.utc(2026, 9, 21, 10),
    );
    await done.insertSession(completed: true);
    await done.pump(tester);
    expect(find.text('Done for today. Nice and steady.'), findsOneWidget);
    expect(find.byKey(const ValueKey('see-what-you-did')), findsOneWidget);
  });

  testWidgets('rest day names the next real plan day', (tester) async {
    final rest = await _TodayHarness.create(
      tester,
      DateTime.utc(2026, 9, 22, 10),
    );
    await rest.pump(tester);
    expect(find.text('Rest day. Monday is lower body.'), findsOneWidget);
  });

  testWidgets('month card shows period, premenstrual, and not sure copy', (
    tester,
  ) async {
    final harness = await _TodayHarness.create(
      tester,
      DateTime.utc(2026, 9, 21, 10),
    );
    await harness.setMonth(DateTime(2026, 9, 20), MenstrualGap.days28);
    await harness.pump(tester);
    expect(find.text('Day 2 since your period started'), findsOneWidget);
    expect(find.textContaining('Gentle movement eases cramps'), findsOneWidget);

    await harness.setMonth(DateTime(2026, 8, 26), MenstrualGap.days28);
    await tester.pumpAndSettle();
    expect(find.textContaining('more tired before a period'), findsOneWidget);

    await harness.setMonth(DateTime(2026, 9, 16), MenstrualGap.notSure);
    await tester.pumpAndSettle();
    expect(find.text('About day 6 since your period started'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('month-research')));
    await tester.tap(find.byKey(const ValueKey('month-research')));
    await tester.pumpAndSettle();
    expect(find.textContaining('McNulty et al.'), findsOneWidget);
    expect(find.textContaining('Bruinvels et al.'), findsOneWidget);
    expect(find.textContaining('Armour et al.'), findsOneWidget);
  });

  testWidgets('month card stays hidden without opted-in date', (tester) async {
    final harness = await _TodayHarness.create(
      tester,
      DateTime.utc(2026, 9, 21, 10),
    );
    await harness.setMonth(
      DateTime(2026, 9, 16),
      MenstrualGap.days28,
      preference: MenstrualPreference.declined,
    );
    await harness.pump(tester);
    expect(find.byKey(const ValueKey('today-month-card')), findsNothing);
    await harness.setMonth(
      DateTime(2026, 9, 16),
      MenstrualGap.days28,
      preference: MenstrualPreference.notApplicable,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-month-card')), findsNothing);
  });

  testWidgets('started today updates profile and undo restores its date', (
    tester,
  ) async {
    final harness = await _TodayHarness.create(
      tester,
      DateTime.utc(2026, 9, 21, 10),
    );
    final previous = DateTime(2026, 9, 16);
    await harness.setMonth(previous, MenstrualGap.days28);
    await harness.pump(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('month-started-today')),
    );
    await tester.tap(find.byKey(const ValueKey('month-started-today')));
    await tester.pumpAndSettle();
    expect(
      (await harness.container.read(onboardingRepositoryProvider).load())!
          .lastPeriodStart,
      DateTime(2026, 9, 21),
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      (await harness.container.read(onboardingRepositoryProvider).load())!
          .lastPeriodStart,
      previous,
    );
  });
}

class _TodayHarness {
  _TodayHarness(
    this.container,
    this.database,
    this.now,
    this.planId,
    this.planRef,
  );

  final ProviderContainer container;
  final AppDatabase database;
  final DateTime now;
  final String planId;
  final String planRef;

  static Future<_TodayHarness> create(WidgetTester tester, DateTime now) async {
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
    final document = await storeSessionTestPlan(container);
    return _TodayHarness(
      container,
      database,
      now,
      document.row.id,
      document.plan.reference,
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> setMonth(
    DateTime start,
    MenstrualGap gap, {
    MenstrualPreference preference = MenstrualPreference.optedIn,
  }) async {
    await container
        .read(onboardingRepositoryProvider)
        .update(
          (current) => current.copyWith(
            menstrualPreference: preference,
            lastPeriodStart: start,
            menstrualGap: gap,
          ),
        );
  }

  Future<void> insertSession({required bool completed}) async {
    await database
        .into(database.sessionRecords)
        .insert(
          SessionRecordRow(
            id: completed ? 'done-session' : 'open-session',
            planId: planId,
            planRef: planRef,
            dayIndex: 1,
            mesocycleIndex: 1,
            mesocycleWeekIndex: 1,
            absoluteWeekIndex: 1,
            weekKind: sessionTestPlan().mesocycleCalendar.first.kind,
            startedAt: now.subtract(const Duration(hours: 1)),
            completedAt: completed ? now : null,
          ),
        );
  }
}
