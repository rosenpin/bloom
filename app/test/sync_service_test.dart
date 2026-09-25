import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/data/db/schema.dart';
import 'package:womens_gym/data/sync/sync_remote.dart';
import 'package:womens_gym/data/sync/sync_service.dart';
import 'package:womens_gym/features/plan/data/plan_codec.dart';
import 'package:womens_gym/features/session/data/session_event_codec.dart';

import 'support/session_test_support.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('lost acknowledgement retries as an idempotent double-send', () async {
    var now = DateTime.utc(2026, 7, 26, 10);
    final remote = _FakeSyncRemote(userId: 'user-1')..failAfterApplyOnce = true;
    final service = SyncService(database, remote, () => now);
    const planId = '01K11K5YQ00000000000000000';
    await database
        .into(database.outbox)
        .insert(
          OutboxCompanion.insert(
            id: '01K11K5YQ10000000000000000',
            targetTable: 'plans',
            rowId: planId,
            op: OutboxOperation.update,
            payloadJson: jsonEncode({
              'id': planId,
              'document': <String, Object?>{},
              'engine_version': 'engine-1',
              'config_hash': 'config',
              'content_hash': 'content',
              'profile_hash': 'profile',
              'mesocycle_index': 1,
              'created_at': now.toIso8601String(),
            }),
            createdAt: now,
          ),
        );

    await service.syncNow();
    expect(await database.select(database.outbox).get(), hasLength(1));
    expect(remote.applied['plans'], hasLength(1));

    now = now.add(const Duration(seconds: 3));
    await service.syncNow();
    expect(await database.select(database.outbox).get(), isEmpty);
    expect(remote.applied['plans'], hasLength(1));
    expect(remote.sendCount, 2);
  });

  test('insert-only app events retry with conflict-ignore semantics', () async {
    var now = DateTime.utc(2026, 7, 26, 10);
    final remote = _FakeSyncRemote(userId: 'user-1')..failAfterApplyOnce = true;
    final service = SyncService(database, remote, () => now);
    const eventId = '00000000-0000-4000-8000-000000000001';
    await database
        .into(database.outbox)
        .insert(
          OutboxCompanion.insert(
            id: '01K11K5YQ10000000000000000',
            targetTable: 'app_events',
            rowId: eventId,
            op: OutboxOperation.insert,
            payloadJson: jsonEncode({
              'id': eventId,
              'name': 'session_started',
              'props': <String, Object?>{},
              'client_ts': now.toIso8601String(),
            }),
            createdAt: now,
          ),
        );

    await service.syncNow();
    now = now.add(const Duration(seconds: 3));
    await service.syncNow();

    expect(await database.select(database.outbox).get(), isEmpty);
    expect(remote.applied['app_events'], hasLength(1));
    expect(remote.ignoreDuplicateCalls, [true, true]);
  });

  test('a row that used up its retries drains after a restart', () async {
    final now = DateTime.utc(2026, 7, 26, 10);
    final remote = _FakeSyncRemote(userId: 'user-1')
      ..failingTables.add('app_events');
    await _insertAppEvent(database, now);
    final service = SyncService(database, remote, () => now);
    await service.syncNow();
    await database
        .update(database.outbox)
        .write(const OutboxCompanion(attempts: Value(5)));

    // The server gets fixed; this launch has already given up on the row.
    remote.failingTables.clear();
    await service.syncNow();
    expect(await database.select(database.outbox).get(), hasLength(1));

    final relaunched = SyncService(database, remote, () => now);
    await relaunched.syncNow();
    expect(await database.select(database.outbox).get(), isEmpty);
    expect(remote.applied['app_events'], hasLength(1));
  });

  test('a failing analytics event does not hold back a plan', () async {
    final now = DateTime.utc(2026, 7, 26, 10);
    final remote = _FakeSyncRemote(userId: 'user-1')
      ..failingTables.add('app_events');
    await _insertAppEvent(database, now);
    const planId = '01K11K5YQ00000000000000000';
    await database
        .into(database.outbox)
        .insert(
          OutboxCompanion.insert(
            id: '01K11K5YQ20000000000000000',
            targetTable: 'plans',
            rowId: planId,
            op: OutboxOperation.update,
            payloadJson: jsonEncode({'id': planId}),
            createdAt: now.add(const Duration(seconds: 1)),
          ),
        );

    await SyncService(database, remote, () => now).syncNow();

    expect(remote.applied['plans'], hasLength(1));
    final left = await database.select(database.outbox).get();
    expect(left.single.targetTable, 'app_events');
    expect(left.single.attempts, 1);
  });

  test('content pull upserts the mirror and advances its cursor', () async {
    final updatedAt = DateTime.utc(2026, 7, 26, 9);
    final remote = _FakeSyncRemote()
      ..updatedByTable['exercises'] = [
        _exerciseRow(engine.catalogV1.exercises.first, updatedAt),
      ];
    final service = SyncService(
      database,
      remote,
      () => DateTime.utc(2026, 7, 26, 10),
    );

    await service.syncNow();

    final exercise = await database.select(database.exercises).getSingle();
    final cursor = await (database.select(
      database.syncCursors,
    )..where((row) => row.targetTable.equals('exercises'))).getSingle();
    expect(exercise.id, engine.catalogV1.exercises.first.id);
    expect(
      exercise.bwContribution,
      engine.catalogV1.exercises.first.bwContribution,
    );
    expect(cursor.lastPulledAt.toUtc(), updatedAt);
  });

  test(
    'fresh local database restores owner rows in dependency order',
    () async {
      final now = DateTime.utc(2026, 7, 26, 10);
      const userId = 'user-1';
      const planId = '01K11K5YQ00000000000000000';
      const sessionId = '01K11K5YQ10000000000000000';
      const eventId = '01K11K5YQ20000000000000000';
      final abandoned = SessionEventCodec.encode(
        const engine.SessionAbandoned(),
      );
      final remote = _FakeSyncRemote(userId: userId)
        ..ownedByTable['profiles'] = [
          {
            'id': userId,
            'unit_system': 'metric',
            'quiz_answers': jsonDecode(sessionTestAnswers().toJson()),
            'last_period_start': null,
            'usual_gap_days': null,
            'unit_prompt_seen': true,
            'updated_at': now.toIso8601String(),
          },
        ]
        ..ownedByTable['plans'] = [
          {
            'id': planId,
            'user_id': userId,
            'document': jsonDecode(PlanCodec.encode(sessionTestPlan())),
            'engine_version': 'session-test-engine',
            'config_hash': 'session-test-config',
            'content_hash': 'session-test-content',
            'profile_hash': 'session-test-profile',
            'mesocycle_index': 1,
            'created_at': now.toIso8601String(),
          },
        ]
        ..ownedByTable['session_records'] = [
          {
            'id': sessionId,
            'user_id': userId,
            'plan_id': planId,
            'plan_ref': 'restored-plan-ref',
            'day_index': 1,
            'mesocycle_index': 2,
            'mesocycle_week_index': 3,
            'absolute_week_index': 9,
            'week_kind': 'push',
            'started_at': now.toIso8601String(),
            'completed_at': null,
            'abandoned_at': now
                .add(const Duration(minutes: 2))
                .toIso8601String(),
          },
        ]
        ..ownedByTable['session_events'] = [
          {
            'id': eventId,
            'user_id': userId,
            'session_id': sessionId,
            'seq': 0,
            'type': abandoned.type.name,
            'payload': jsonDecode(abandoned.payloadJson),
            'recorded_at': now
                .add(const Duration(minutes: 1))
                .toIso8601String(),
            'unit_system_at_entry': 'metric',
          },
        ];
      final service = SyncService(database, remote, () => now);

      await service.syncNow();

      final profile = await database.select(database.profiles).getSingle();
      expect(profile.unitPromptSeen, isTrue);
      expect(await database.select(database.plans).get(), hasLength(1));
      final record = await database.select(database.sessionRecords).getSingle();
      expect(record.abandonedAt, isNotNull);
      expect(record.planRef, 'restored-plan-ref');
      expect(record.mesocycleIndex, 2);
      expect(record.mesocycleWeekIndex, 3);
      expect(record.absoluteWeekIndex, 9);
      expect(record.weekKind, engine.MesocycleWeekKind.push);
      expect(await database.select(database.sessionEvents).get(), hasLength(1));
    },
  );
}

Map<String, Object?> _exerciseRow(
  engine.Exercise exercise,
  DateTime updatedAt,
) => {
  'id': exercise.id,
  'slug': exercise.slug,
  'name': exercise.name,
  'movement_class': exercise.movementClass.name,
  'block_role': exercise.blockRole.name,
  'metric_type': exercise.metricType.name,
  'laterality': exercise.laterality.name,
  'bw_contribution': exercise.bwContribution,
  'load_step_override_kg': exercise.loadStepOverride?.value,
  'resistance_equipment': exercise.resistanceEquipment.name,
  'support_equipment': exercise.supportEquipment.name,
  'target_muscles': [
    for (final target in exercise.targetMuscles)
      {'muscle': target.muscle.name, 'role': target.role.name},
  ],
  'primary_joint_actions': [
    for (final action in exercise.primaryJointActions) action.name,
  ],
  'secondary_joint_actions': [
    for (final action in exercise.secondaryJointActions) action.name,
  ],
  'rom_rank': exercise.romRank,
  'stability_rank': exercise.stabilityRank,
  'difficulty_tier': exercise.difficultyTier.name,
  'min_experience': exercise.minExperience.name,
  'intimidation_tier': exercise.intimidationTier.name,
  'age_eligibility': exercise.ageEligibility.name,
  'safety_eligibility': exercise.safetyEligibility.name,
  'machine_lean_ok': exercise.machineLeanOk,
  'seated_variant': exercise.seatedVariant,
  'retired_at': exercise.retiredAt?.toIso8601String(),
  'updated_at': updatedAt.toIso8601String(),
};

final class _FakeSyncRemote implements SyncRemote {
  _FakeSyncRemote({this.userId});

  final String? userId;
  final updatedByTable = <String, List<Map<String, Object?>>>{};
  final ownedByTable = <String, List<Map<String, Object?>>>{};
  final applied = <String, Map<String, Map<String, Object?>>>{};
  bool failAfterApplyOnce = false;
  final failingTables = <String>{};
  int sendCount = 0;
  final ignoreDuplicateCalls = <bool>[];

  @override
  Future<String?> currentUserId() async => userId;

  @override
  Future<List<Map<String, Object?>>> pullOwned(
    String table, {
    required String userId,
  }) async => ownedByTable[table] ?? const [];

  @override
  Future<List<Map<String, Object?>>> pullUpdated(
    String table, {
    DateTime? after,
  }) async => [
    for (final row in updatedByTable[table] ?? const <Map<String, Object?>>[])
      if (after == null ||
          DateTime.parse(row['updated_at']! as String).isAfter(after))
        row,
  ];

  @override
  Future<void> upsert(
    String table,
    Map<String, Object?> row, {
    required String onConflict,
    bool ignoreDuplicates = false,
  }) async {
    sendCount++;
    ignoreDuplicateCalls.add(ignoreDuplicates);
    if (failingTables.contains(table)) {
      throw StateError('new row violates row-level security policy');
    }
    final key = [
      for (final column in onConflict.split(',')) row[column],
    ].join('|');
    applied.putIfAbsent(table, () => {})[key] = Map.of(row);
    if (failAfterApplyOnce) {
      failAfterApplyOnce = false;
      throw StateError('acknowledgement lost');
    }
  }
}

Future<void> _insertAppEvent(AppDatabase database, DateTime now) => database
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
