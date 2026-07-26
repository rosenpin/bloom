import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../data/db/app_database.dart';

final class ExerciseGuidance {
  const ExerciseGuidance({
    required this.exerciseId,
    required this.name,
    required this.setupSteps,
    required this.shouldFeel,
    required this.stopIf,
    required this.findIt,
    required this.dos,
    required this.donts,
    required this.swaps,
  });

  final String exerciseId;
  final String name;
  final List<String> setupSteps;
  final String shouldFeel;
  final String stopIf;
  final String findIt;
  final List<String> dos;
  final List<String> donts;
  final List<ExerciseSwapGuidance> swaps;
}

final class ExerciseSwapGuidance {
  const ExerciseSwapGuidance({
    required this.exerciseId,
    required this.name,
    required this.tier,
  });

  final String exerciseId;
  final String name;
  final int tier;
}

final class ExerciseContentRepository {
  const ExerciseContentRepository(this._database);

  final AppDatabase _database;

  Future<ExerciseGuidance?> loadGuidance(String exerciseId) async {
    final exerciseQuery = _database.select(_database.exercises)
      ..where((row) => row.id.equals(exerciseId));
    final copyQuery = _database.select(_database.exerciseCopy)
      ..where((row) => row.exerciseId.equals(exerciseId));
    final edgeQuery = _database.select(_database.swapEdges)
      ..where(
        (row) =>
            row.fromId.equals(exerciseId) &
            row.reason.equalsValue(engine.SwapReason.busy),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.tier),
        (row) => OrderingTerm.asc(row.rank),
        (row) => OrderingTerm.asc(row.toId),
      ]);
    final exercise = await exerciseQuery.getSingleOrNull();
    final copy = await copyQuery.getSingleOrNull();
    if (exercise == null || copy == null) return null;
    final edges = await edgeQuery.get();
    final swapExercises = edges.isEmpty
        ? const <ExerciseRow>[]
        : await (_database.select(
            _database.exercises,
          )..where((row) => row.id.isIn(edges.map((edge) => edge.toId)))).get();
    final swapNameById = <String, String>{
      for (final swap in swapExercises) swap.id: swap.name,
    };
    return ExerciseGuidance(
      exerciseId: exercise.id,
      name: exercise.name,
      setupSteps: _strings(copy.setupStepsJson),
      shouldFeel: copy.shouldFeel,
      stopIf: copy.stopIf,
      findIt: copy.findIt,
      dos: _strings(copy.dosJson),
      donts: _strings(copy.dontsJson),
      swaps: List<ExerciseSwapGuidance>.unmodifiable([
        for (final edge in edges)
          if (swapNameById[edge.toId] case final name?)
            ExerciseSwapGuidance(
              exerciseId: edge.toId,
              name: name,
              tier: edge.tier,
            ),
      ]),
    );
  }

  static List<String> _strings(String source) => List<String>.unmodifiable(
    (jsonDecode(source) as List<Object?>).cast<String>(),
  );
}

final class ExerciseContentSeeder {
  ExerciseContentSeeder(this._database, this._catalog, this._clock);

  final AppDatabase _database;
  final engine.ContentCatalog _catalog;
  final DateTime Function() _clock;
  Future<void>? _pendingSeed;

  Future<void> seedIfEmpty() {
    final pending = _pendingSeed;
    if (pending != null) return pending;
    late final Future<void> seed;
    seed = _seedIfEmpty().whenComplete(() {
      if (identical(_pendingSeed, seed)) _pendingSeed = null;
    });
    _pendingSeed = seed;
    return seed;
  }

  Future<void> _seedIfEmpty() async {
    final query = _database.select(_database.exercises)..limit(1);
    if (await query.getSingleOrNull() != null) return;

    final updatedAt = _clock();
    await _database.transaction(() async {
      for (final exercise in _catalog.exercises) {
        await _database
            .into(_database.exercises)
            .insert(
              ExercisesCompanion.insert(
                id: exercise.id,
                slug: exercise.slug,
                name: exercise.name,
                movementClass: exercise.movementClass,
                blockRole: exercise.blockRole,
                metricType: exercise.metricType,
                laterality: exercise.laterality,
                bwContribution: exercise.bwContribution,
                loadStepOverrideKg: Value(exercise.loadStepOverride?.value),
                resistanceEquipment: exercise.resistanceEquipment,
                supportEquipment: exercise.supportEquipment,
                targetMusclesJson: jsonEncode([
                  for (final target in exercise.targetMuscles)
                    <String, String>{
                      'muscle': target.muscle.name,
                      'role': target.role.name,
                    },
                ]),
                primaryJointActionsJson: jsonEncode([
                  for (final action in exercise.primaryJointActions)
                    action.name,
                ]),
                secondaryJointActionsJson: jsonEncode([
                  for (final action in exercise.secondaryJointActions)
                    action.name,
                ]),
                romRank: exercise.romRank,
                stabilityRank: exercise.stabilityRank,
                difficultyTier: exercise.difficultyTier,
                minExperience: exercise.minExperience,
                intimidationTier: exercise.intimidationTier,
                ageEligibility: exercise.ageEligibility,
                safetyEligibility: exercise.safetyEligibility,
                machineLeanOk: exercise.machineLeanOk,
                seatedVariant: exercise.seatedVariant,
                retiredAt: Value(exercise.retiredAt),
                updatedAt: updatedAt,
              ),
            );
        await _database
            .into(_database.exerciseCopy)
            .insert(
              ExerciseCopyCompanion.insert(
                exerciseId: exercise.id,
                setupStepsJson: jsonEncode(exercise.setupSteps),
                shouldFeel: exercise.shouldFeel,
                stopIf: exercise.stopIf,
                findIt: exercise.findIt,
                dosJson: jsonEncode(exercise.dos),
                dontsJson: jsonEncode(exercise.donts),
                updatedAt: updatedAt,
              ),
            );
      }

      final rankBySource = <String, int>{};
      for (final edge in _catalog.swapEdges) {
        final rank = rankBySource.update(
          edge.fromId,
          (value) => value + 1,
          ifAbsent: () => 0,
        );
        for (final reason in engine.SwapReason.values) {
          await _database
              .into(_database.swapEdges)
              .insert(
                SwapEdgesCompanion.insert(
                  fromId: edge.fromId,
                  toId: edge.toId,
                  reason: reason,
                  rank: rank,
                  tier: edge.tier,
                  updatedAt: updatedAt,
                ),
              );
        }
      }
    });
  }
}
