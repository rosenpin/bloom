import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/app.dart';
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/core/version_gate.dart';
import 'package:womens_gym/data/db/app_database.dart';

import 'support/session_test_support.dart';
import 'support/premium_entitlements.dart';

void main() {
  testWidgets('a fake hard-block decision replaces the routed app', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          versionGateProvider.overrideWithValue(
            const FakeVersionGate(
              VersionGateDecision(
                isBlocked: true,
                updateRecommended: true,
                message: 'Install the safety update.',
              ),
            ),
          ),
          appVersionProvider.overrideWith((ref) async => '0.1.0'),
        ],
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Install the safety update.'), findsOneWidget);
    expect(find.text('Update to continue'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('recommended update is a dismissible Today banner', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        entitlementServiceProvider.overrideWithValue(
          const PremiumEntitlements(),
        ),
        versionGateProvider.overrideWithValue(
          const FakeVersionGate(
            VersionGateDecision(
              isBlocked: false,
              updateRecommended: true,
              message: 'A smoother version is ready.',
            ),
          ),
        ),
        appVersionProvider.overrideWith((ref) async => '0.1.0'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await container
        .read(onboardingRepositoryProvider)
        .save(sessionTestAnswers().copyWith(completed: true));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('version-update-nudge')), findsOneWidget);
    expect(find.text('A smoother version is ready.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('dismiss-version-update-nudge')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('version-update-nudge')), findsNothing);
    await _dispose(tester);
  });
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
