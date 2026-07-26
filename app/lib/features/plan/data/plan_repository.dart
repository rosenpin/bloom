import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/ulid.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/stored_plan_document.dart';
import 'plan_codec.dart';

final class PlanRepository {
  const PlanRepository(this._database, this._ulid, this._clock, this._outbox);

  final AppDatabase _database;
  final UlidGenerator _ulid;
  final DateTime Function() _clock;
  final OutboxSink _outbox;

  Stream<StoredPlanDocument?> watchLatest() {
    final query = _database.select(_database.plans)
      ..orderBy([
        (plan) => OrderingTerm.desc(plan.createdAt),
        (plan) => OrderingTerm.desc(plan.id),
      ])
      ..limit(1);
    return query.watchSingleOrNull().map(_decode);
  }

  Future<StoredPlanDocument?> loadLatest() async {
    final query = _database.select(_database.plans)
      ..orderBy([
        (plan) => OrderingTerm.desc(plan.createdAt),
        (plan) => OrderingTerm.desc(plan.id),
      ])
      ..limit(1);
    return _decode(await query.getSingleOrNull());
  }

  Future<StoredPlanDocument?> loadById(String id) async {
    final query = _database.select(_database.plans)
      ..where((plan) => plan.id.equals(id));
    return _decode(await query.getSingleOrNull());
  }

  Future<StoredPlanDocument> store(
    engine.Plan plan, {
    required OnboardingRepository onboardingRepository,
    required engine.UnitSystem unitSystem,
  }) async {
    final createdAt = _clock();
    final row = StoredPlan(
      id: _ulid.generate(timestamp: createdAt),
      documentJson: PlanCodec.encode(plan),
      engineVersion: plan.stamps.engineVersion,
      configHash: plan.stamps.configHash,
      contentHash: plan.stamps.contentHash,
      profileHash: plan.stamps.profileHash,
      mesocycleIndex: plan.mesocycleIndex,
      createdAt: createdAt,
    );

    await _database.transaction(() async {
      await _database.into(_database.plans).insert(row);
      await _outbox.enqueue(
        targetTable: 'plans',
        rowId: row.id,
        payload: _syncPayload(row),
      );
      final answers = await onboardingRepository.load();
      if (answers == null) {
        throw StateError('Cannot complete onboarding without a profile.');
      }
      await onboardingRepository.save(
        answers.copyWith(unitSystem: unitSystem, completed: true),
      );
    });

    return StoredPlanDocument(row: row, plan: plan);
  }

  Future<StoredPlanDocument> update(
    StoredPlanDocument document,
    engine.Plan plan,
  ) async {
    await _database.transaction(() async {
      await (_database.update(
        _database.plans,
      )..where((row) => row.id.equals(document.row.id))).write(
        PlansCompanion(
          documentJson: Value(PlanCodec.encode(plan)),
          engineVersion: Value(plan.stamps.engineVersion),
          configHash: Value(plan.stamps.configHash),
          contentHash: Value(plan.stamps.contentHash),
          profileHash: Value(plan.stamps.profileHash),
          mesocycleIndex: Value(plan.mesocycleIndex),
        ),
      );
      final updated = await (_database.select(
        _database.plans,
      )..where((row) => row.id.equals(document.row.id))).getSingle();
      await _outbox.enqueue(
        targetTable: 'plans',
        rowId: updated.id,
        payload: _syncPayload(updated),
      );
    });
    final row = await (_database.select(
      _database.plans,
    )..where((row) => row.id.equals(document.row.id))).getSingle();
    return StoredPlanDocument(row: row, plan: plan);
  }

  StoredPlanDocument? _decode(StoredPlan? row) => row == null
      ? null
      : StoredPlanDocument(row: row, plan: PlanCodec.decode(row.documentJson));

  static Map<String, Object?> _syncPayload(StoredPlan row) => {
    'id': row.id,
    'document': jsonDecode(row.documentJson),
    'engine_version': row.engineVersion,
    'config_hash': row.configHash,
    'content_hash': row.contentHash,
    'profile_hash': row.profileHash,
    'mesocycle_index': row.mesocycleIndex,
    'created_at': row.createdAt.toUtc().toIso8601String(),
  };
}
