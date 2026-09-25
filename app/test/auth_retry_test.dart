import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:womens_gym/app.dart';
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/core/version_gate.dart';
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/data/db/schema.dart';
import 'package:womens_gym/data/sync/sync_remote.dart';

import 'support/premium_entitlements.dart';

void main() {
  testWidgets('a sign-in that failed at launch is retried on resume', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final remote = _SignedOutRemote();
    var attempts = 0;
    final now = DateTime.utc(2026, 7, 26, 10);
    await database
        .into(database.outbox)
        .insert(
          OutboxCompanion.insert(
            id: '01K11K5YQ10000000000000000',
            targetTable: 'app_events',
            rowId: '00000000-0000-4000-8000-000000000001',
            op: OutboxOperation.insert,
            payloadJson: jsonEncode({
              'id': '00000000-0000-4000-8000-000000000001',
              'name': 'session_started',
              'props': <String, Object?>{},
              'client_ts': now.toIso8601String(),
            }),
            createdAt: now,
          ),
        );
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
        syncRemoteProvider.overrideWithValue(remote),
        // No signal at launch; the next attempt signs in.
        ensureAnonymousAuthProvider.overrideWith((ref) async {
          attempts++;
          if (attempts == 1) return null;
          remote.userId = 'user-1';
          return _session('user-1');
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WomensGymApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(remote.sent, isEmpty);
    expect(await database.select(database.outbox).get(), isNotEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(remote.sent, contains('app_events'));
    expect(await database.select(database.outbox).get(), isEmpty);

    // Signed in now: another resume does not sign in again.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(attempts, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Session _session(String userId) => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-07-26T10:00:00Z',
  ),
);

final class _SignedOutRemote implements SyncRemote {
  String? userId;
  final sent = <String>[];

  @override
  Future<String?> currentUserId() async => userId;

  @override
  Future<void> upsert(
    String table,
    Map<String, Object?> row, {
    required String onConflict,
    bool ignoreDuplicates = false,
  }) async => sent.add(table);

  @override
  Future<List<Map<String, Object?>>> pullUpdated(
    String table, {
    DateTime? after,
  }) async => const [];

  @override
  Future<List<Map<String, Object?>>> pullOwned(
    String table, {
    required String userId,
  }) async => const [];
}
