import 'package:drift/drift.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/ulid.dart';
import '../../../data/db/app_database.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/stored_plan_document.dart';
import 'plan_codec.dart';

final class PlanRepository {
  const PlanRepository(this._database, this._ulid, this._clock);

  final AppDatabase _database;
  final UlidGenerator _ulid;
  final DateTime Function() _clock;

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

  StoredPlanDocument? _decode(StoredPlan? row) => row == null
      ? null
      : StoredPlanDocument(row: row, plan: PlanCodec.decode(row.documentJson));
}
