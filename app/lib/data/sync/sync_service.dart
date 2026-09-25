import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../db/app_database.dart';
import '../db/schema.dart';
import 'sync_remote.dart';

final class SyncService {
  SyncService(
    this._database,
    this._remote,
    this._clock, {
    this.period = const Duration(seconds: 30),
    this.maxAttempts = 5,
  });

  static const contentTables = <String>[
    'exercises',
    'exercise_copy',
    'swap_edges',
    'version_gate',
  ];

  final AppDatabase _database;
  final SyncRemote _remote;
  final DateTime Function() _clock;
  final Duration period;
  final int maxAttempts;

  Timer? _timer;
  Future<void>? _activeSync;
  bool _retriesForgiven = false;

  void startForeground() {
    _timer?.cancel();
    unawaited(syncNow());
    _timer = Timer.periodic(period, (_) => unawaited(syncNow()));
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => pause();

  Future<void> syncNow() {
    final active = _activeSync;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _sync().whenComplete(() {
      if (identical(_activeSync, operation)) _activeSync = null;
    });
    _activeSync = operation;
    return operation;
  }

  Future<void> _sync() async {
    try {
      // Once per launch, forget past failures, so a fix on the server is
      // picked up on the next launch instead of waiting for an app update.
      if (!_retriesForgiven) {
        _retriesForgiven = true;
        await _database
            .update(_database.outbox)
            .write(
              const OutboxCompanion(
                attempts: Value(0),
                nextAttemptAt: Value(null),
              ),
            );
      }
      await _pullContent();
      final userId = await _remote.currentUserId();
      if (userId == null) return;
      await _drain(userId);
      await _restoreIfEmpty(userId);
    } on Object {
      // Local-first and fail-open: the next lifecycle or timer trigger retries.
    }
  }

  Future<void> _drain(String userId) async {
    final query = _database.select(_database.outbox)
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    final rows = await query.get();
    for (final entry in rows) {
      // Analytics stand alone, so a stuck event is stepped over. Everything
      // else stops the drain: the server needs profiles, plans, sessions and
      // their events in order.
      final independent = entry.targetTable == 'app_events';
      final now = _clock().toUtc();
      final waiting =
          entry.attempts >= maxAttempts ||
          (entry.nextAttemptAt?.isAfter(now) ?? false);
      if (waiting) {
        if (independent) continue;
        return;
      }
      try {
        await _send(entry, userId);
        await (_database.delete(
          _database.outbox,
        )..where((row) => row.id.equals(entry.id))).go();
      } on Object {
        final attempts = entry.attempts + 1;
        final exponent = attempts.clamp(1, 6);
        await (_database.update(
          _database.outbox,
        )..where((row) => row.id.equals(entry.id))).write(
          OutboxCompanion(
            attempts: Value(attempts),
            nextAttemptAt: Value(now.add(Duration(seconds: 1 << exponent))),
          ),
        );
        if (independent) continue;
        return;
      }
    }
  }

  Future<void> _send(OutboxEntry entry, String userId) async {
    final payload = (jsonDecode(entry.payloadJson) as Map<Object?, Object?>)
        .cast<String, Object?>();
    switch (entry.targetTable) {
      case 'profiles':
        payload['id'] = userId;
      case 'plans' ||
          'session_records' ||
          'session_events' ||
          'user_exercise_prefs' ||
          'app_events':
        payload['user_id'] = userId;
      default:
        throw StateError('Unsupported outbox table: ${entry.targetTable}');
    }

    final onConflict = switch (entry.targetTable) {
      'profiles' => 'id',
      'plans' || 'session_records' || 'session_events' || 'app_events' => 'id',
      'user_exercise_prefs' => 'user_id,exercise_id,source',
      _ => throw StateError('Unsupported outbox table: ${entry.targetTable}'),
    };
    await _remote.upsert(
      entry.targetTable,
      payload,
      onConflict: onConflict,
      ignoreDuplicates:
          entry.targetTable == 'session_events' ||
          entry.targetTable == 'app_events',
    );
  }

  Future<void> _pullContent() async {
    for (final table in contentTables) {
      final cursorQuery = _database.select(_database.syncCursors)
        ..where((row) => row.targetTable.equals(table));
      final cursor = await cursorQuery.getSingleOrNull();
      final rows = await _remote.pullUpdated(
        table,
        after: cursor?.lastPulledAt,
      );
      if (rows.isEmpty) continue;
      await _database.transaction(() async {
        await _upsertContent(table, rows);
        final latest = rows
            .map((row) => _date(row['updated_at']))
            .reduce((left, right) => left.isAfter(right) ? left : right);
        await _database
            .into(_database.syncCursors)
            .insertOnConflictUpdate(
              SyncCursorsCompanion.insert(
                targetTable: table,
                lastPulledAt: latest,
              ),
            );
      });
    }
  }

  Future<void> _upsertContent(
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    switch (table) {
      case 'exercises':
        for (final row in rows) {
          await _database
              .into(_database.exercises)
              .insertOnConflictUpdate(
                ExercisesCompanion.insert(
                  id: row['id']! as String,
                  slug: row['slug']! as String,
                  name: row['name']! as String,
                  movementClass: _enum(
                    engine.MovementClass.values,
                    row['movement_class'],
                  ),
                  blockRole: _enum(engine.BlockRole.values, row['block_role']),
                  metricType: _enum(
                    engine.MetricType.values,
                    row['metric_type'],
                  ),
                  laterality: _enum(
                    engine.Laterality.values,
                    row['laterality'],
                  ),
                  bwContribution: (row['bw_contribution']! as num).toDouble(),
                  loadStepOverrideKg: Value(
                    (row['load_step_override_kg'] as num?)?.toDouble(),
                  ),
                  resistanceEquipment: _enum(
                    engine.ResistanceEquipment.values,
                    row['resistance_equipment'],
                  ),
                  supportEquipment: _enum(
                    engine.SupportEquipment.values,
                    row['support_equipment'],
                  ),
                  targetMusclesJson: _json(row['target_muscles']),
                  primaryJointActionsJson: _json(row['primary_joint_actions']),
                  secondaryJointActionsJson: _json(
                    row['secondary_joint_actions'],
                  ),
                  romRank: row['rom_rank']! as int,
                  stabilityRank: row['stability_rank']! as int,
                  difficultyTier: _enum(
                    engine.DifficultyTier.values,
                    row['difficulty_tier'],
                  ),
                  minExperience: _enum(
                    engine.ExperienceTier.values,
                    row['min_experience'],
                  ),
                  intimidationTier: _enum(
                    engine.IntimidationTier.values,
                    row['intimidation_tier'],
                  ),
                  ageEligibility: _enum(
                    engine.AgeEligibility.values,
                    row['age_eligibility'],
                  ),
                  safetyEligibility: _enum(
                    engine.SafetyEligibility.values,
                    row['safety_eligibility'],
                  ),
                  machineLeanOk: row['machine_lean_ok']! as bool,
                  seatedVariant: row['seated_variant']! as bool,
                  retiredAt: Value(_nullableDate(row['retired_at'])),
                  updatedAt: _date(row['updated_at']),
                ),
              );
        }
      case 'exercise_copy':
        for (final row in rows) {
          await _database
              .into(_database.exerciseCopy)
              .insertOnConflictUpdate(
                ExerciseCopyCompanion.insert(
                  exerciseId: row['exercise_id']! as String,
                  setupStepsJson: _json(row['setup_steps']),
                  shouldFeel: row['should_feel']! as String,
                  stopIf: row['stop_if']! as String,
                  findIt: row['find_it']! as String,
                  dosJson: _json(row['dos']),
                  dontsJson: _json(row['donts']),
                  updatedAt: _date(row['updated_at']),
                ),
              );
        }
      case 'swap_edges':
        for (final row in rows) {
          await _database
              .into(_database.swapEdges)
              .insertOnConflictUpdate(
                SwapEdgesCompanion.insert(
                  fromId: row['from_id']! as String,
                  toId: row['to_id']! as String,
                  reason: _enum(engine.SwapReason.values, row['reason']),
                  rank: row['rank']! as int,
                  tier: row['tier']! as int,
                  updatedAt: _date(row['updated_at']),
                ),
              );
        }
      case 'version_gate':
        for (final row in rows) {
          await _database
              .into(_database.versionGateConfigs)
              .insertOnConflictUpdate(
                VersionGateConfigsCompanion.insert(
                  id: Value(row['id'] as bool? ?? true),
                  recommendedVersion: row['recommended_version']! as String,
                  minSupportedVersion: row['min_supported_version']! as String,
                  message: Value(row['message'] as String?),
                  updatedAt: _date(row['updated_at']),
                ),
              );
        }
    }
  }

  Future<void> _restoreIfEmpty(String userId) async {
    final hasPlan =
        await (_database.select(_database.plans)..limit(1)).getSingleOrNull() !=
        null;
    final hasSession =
        await (_database.select(
          _database.sessionRecords,
        )..limit(1)).getSingleOrNull() !=
        null;
    final hasPreference =
        await (_database.select(
          _database.userExercisePrefs,
        )..limit(1)).getSingleOrNull() !=
        null;
    if (hasPlan || hasSession || hasPreference) return;

    final profileRows = await _remote.pullOwned('profiles', userId: userId);
    final planRows = await _remote.pullOwned('plans', userId: userId);
    final recordRows = await _remote.pullOwned(
      'session_records',
      userId: userId,
    );
    final eventRows = await _remote.pullOwned('session_events', userId: userId);
    final preferenceRows = await _remote.pullOwned(
      'user_exercise_prefs',
      userId: userId,
    );
    if (profileRows.isEmpty &&
        planRows.isEmpty &&
        recordRows.isEmpty &&
        eventRows.isEmpty &&
        preferenceRows.isEmpty) {
      return;
    }

    await _database.transaction(() async {
      final abandonedAtBySession = <String, DateTime>{
        for (final event in eventRows)
          if (event['type'] == StoredSessionEventType.sessionAbandoned.name)
            event['session_id']! as String: _date(event['recorded_at']),
      };
      for (final row in profileRows) {
        await _database
            .into(_database.profiles)
            .insertOnConflictUpdate(
              ProfilesCompanion.insert(
                id: const Value('local'),
                unitSystem: _enum(engine.UnitSystem.values, row['unit_system']),
                quizAnswersJson: _json(row['quiz_answers']),
                lastPeriodStart: Value(_nullableDate(row['last_period_start'])),
                usualGapDays: Value(row['usual_gap_days'] as int?),
                unitPromptSeen: Value(
                  row['unit_prompt_seen'] as bool? ?? false,
                ),
                updatedAt: _date(row['updated_at']),
              ),
            );
      }
      for (final row in planRows) {
        await _database
            .into(_database.plans)
            .insertOnConflictUpdate(
              PlansCompanion.insert(
                id: row['id']! as String,
                documentJson: _json(row['document']),
                engineVersion: row['engine_version']! as String,
                configHash: row['config_hash']! as String,
                contentHash: row['content_hash']! as String,
                profileHash: row['profile_hash']! as String,
                mesocycleIndex: row['mesocycle_index']! as int,
                createdAt: _date(row['created_at']),
              ),
            );
      }
      for (final row in recordRows) {
        final completedAt = _nullableDate(row['completed_at']);
        final explicitAbandonedAt = _nullableDate(row['abandoned_at']);
        await _database
            .into(_database.sessionRecords)
            .insertOnConflictUpdate(
              SessionRecordsCompanion.insert(
                id: row['id']! as String,
                planId: row['plan_id']! as String,
                planRef: Value(row['plan_ref'] as String? ?? ''),
                dayIndex: row['day_index']! as int,
                mesocycleIndex: Value(row['mesocycle_index'] as int? ?? 1),
                mesocycleWeekIndex: Value(
                  row['mesocycle_week_index'] as int? ?? 1,
                ),
                absoluteWeekIndex: Value(
                  row['absolute_week_index'] as int? ?? 1,
                ),
                weekKind: Value(
                  row['week_kind'] == null
                      ? engine.MesocycleWeekKind.build
                      : _enum(
                          engine.MesocycleWeekKind.values,
                          row['week_kind'],
                        ),
                ),
                startedAt: _date(row['started_at']),
                completedAt: Value(completedAt),
                abandonedAt: Value(
                  completedAt == null
                      ? explicitAbandonedAt ??
                            abandonedAtBySession[row['id']! as String]
                      : null,
                ),
              ),
            );
      }
      for (final row in eventRows) {
        await _database
            .into(_database.sessionEvents)
            .insert(
              SessionEventsCompanion.insert(
                id: row['id']! as String,
                sessionId: row['session_id']! as String,
                seq: row['seq']! as int,
                type: _enum(StoredSessionEventType.values, row['type']),
                payloadJson: _json(row['payload']),
                recordedAt: _date(row['recorded_at']),
                unitSystemAtEntry: _enum(
                  engine.UnitSystem.values,
                  row['unit_system_at_entry'],
                ),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      for (final row in preferenceRows) {
        await _database
            .into(_database.userExercisePrefs)
            .insertOnConflictUpdate(
              UserExercisePrefsCompanion.insert(
                exerciseId: row['exercise_id']! as String,
                excluded: row['excluded']! as bool,
                source: _enum(
                  UserExercisePreferenceSource.values,
                  row['source'],
                ),
                updatedAt: _date(row['updated_at']),
              ),
            );
      }
    });
  }

  static T _enum<T extends Enum>(List<T> values, Object? name) =>
      values.firstWhere((value) => value.name == name);

  static String _json(Object? value) =>
      value is String ? value : jsonEncode(value);

  static DateTime _date(Object? value) {
    if (value is DateTime) return value.toUtc();
    return DateTime.parse(value! as String).toUtc();
  }

  static DateTime? _nullableDate(Object? value) =>
      value == null ? null : _date(value);
}
