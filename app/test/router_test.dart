import 'dart:async';

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
import 'package:womens_gym/features/paywall/entitlement_service.dart';

void main() {
  testWidgets('first run redirects to onboarding', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          entitlementServiceProvider.overrideWithValue(_FakeEntitlements()),
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
        entitlementServiceProvider.overrideWithValue(
          _FakeEntitlements(premium: true),
        ),
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
    expect(find.text('Your first workout will land here.'), findsOneWidget);
    await _disposeWidgetTree(tester);
  });

  testWidgets('completed profile reaches paywall and purchase opens Today', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final entitlements = _FakeEntitlements();
    addTearDown(entitlements.dispose);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        entitlementServiceProvider.overrideWithValue(entitlements),
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
    expect(find.byKey(const ValueKey('paywall-screen')), findsOneWidget);
    expect(find.text('€59.99/yr'), findsOneWidget);
    expect(find.text('€12.99/mo'), findsOneWidget);
    expect(find.text('7 days free'), findsOneWidget);
    expect(find.text('Start my free week'), findsOneWidget);

    container.read(routerProvider).go('/today');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paywall-screen')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('paywall-purchase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paywall-purchase')));
    await tester.pumpAndSettle();
    expect(entitlements.purchasedProduct, 'bloom_premium_annual');
    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
    await _disposeWidgetTree(tester);
  });
}

class _FakeEntitlements implements EntitlementService {
  _FakeEntitlements({bool premium = false})
    : _status = MembershipStatus(isPremium: premium);

  final _updates = StreamController<MembershipStatus>.broadcast();
  MembershipStatus _status;
  String? purchasedProduct;

  void dispose() => _updates.close();

  @override
  MembershipStatus get currentStatus => _status;

  @override
  Future<void> whenReady() async {}

  @override
  Stream<MembershipStatus> watchStatus() async* {
    yield _status;
    yield* _updates.stream;
  }

  @override
  Future<List<MembershipPlan>> loadPlans() async => const [
    MembershipPlan(
      packageId: r'$rc_annual',
      productId: 'bloom_premium_annual',
      price: '€59.99',
      pricePerMonth: '€5.00',
      trialEligible: true,
    ),
    MembershipPlan(
      packageId: r'$rc_monthly',
      productId: 'bloom_premium_monthly',
      price: '€12.99',
    ),
  ];

  @override
  Future<MembershipStatus> purchase(MembershipPlan plan) async {
    purchasedProduct = plan.productId;
    _status = const MembershipStatus(isPremium: true, isTrial: true);
    _updates.add(_status);
    return _status;
  }

  @override
  Future<MembershipStatus> restore() async => _status;

  @override
  Future<void> redeemCode() async {}

  @override
  Future<MembershipStatus> refresh() async => _status;
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
