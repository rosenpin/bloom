/// Explicit, deterministic plan edits applied after a session.
library;

import '../core/warnings.dart';
import 'plan.dart';

enum PlanEditScope { thisSlot, allSlotsOfExercise }

enum ExclusionSource { user, pain }

sealed class PlanEdit {
  const PlanEdit();

  String get canonicalId;
}

/// Keep a session swap in one matching slot or every slot using the source.
final class KeepSwap extends PlanEdit {
  const KeepSwap({
    required this.exerciseId,
    required this.replacementId,
    required this.scope,
    this.dayIndex,
  });

  final String exerciseId;
  final String replacementId;
  final PlanEditScope scope;

  /// Identifies the session slot for [PlanEditScope.thisSlot]. Older callers may
  /// omit it; the deterministic compatibility fallback edits the first match.
  final int? dayIndex;

  @override
  String get canonicalId =>
      'keep:$exerciseId->$replacementId:${scope.name}:'
      '${scope == PlanEditScope.thisSlot ? dayIndex ?? 'first' : 'all'}';
}

/// Records that the caller must persist an exclusion preference.
///
/// The exclusion set deliberately lives outside [Plan] (in
/// `user_exercise_prefs`, with this provenance). Future assembly/session
/// resolution already consumes that external set. Applying this edit therefore
/// stamps the decision and substitutes current slots, but does not embed a
/// second, conflicting exclusion list in the plan document.
final class ExcludeExercise extends PlanEdit {
  const ExcludeExercise({required this.exerciseId, required this.source});

  final String exerciseId;
  final ExclusionSource source;

  @override
  String get canonicalId => 'exclude:$exerciseId:${source.name}';
}

Plan applyPlanEdit(Plan plan, PlanEdit edit) {
  if (plan.editStamps.any((stamp) => stamp.editId == edit.canonicalId)) {
    return plan;
  }

  final stamp = PlanEditStamp(
    engineVersion: plan.stamps.engineVersion,
    configHash: plan.stamps.configHash,
    contentHash: plan.stamps.contentHash,
    editId: edit.canonicalId,
  );

  return switch (edit) {
    ExcludeExercise() => _applyExclusion(plan, edit, stamp),
    KeepSwap() => _applyKeepSwap(plan, edit, stamp),
  };
}

Plan _applyKeepSwap(Plan plan, KeepSwap edit, PlanEditStamp stamp) {
  var editedAny = false;
  var editMore = true;
  final days = <PlanDay>[];
  for (final day in plan.days) {
    final exercises = <PlanExercise>[];
    for (final exercise in day.exercises) {
      final isTargetDay =
          edit.scope == PlanEditScope.allSlotsOfExercise ||
          edit.dayIndex == null ||
          edit.dayIndex == day.dayIndex;
      if (editMore && isTargetDay && exercise.exerciseId == edit.exerciseId) {
        final candidate = exercise.orderedSwapCandidates
            .where((item) => item.exerciseId == edit.replacementId)
            .firstOrNull;
        if (candidate != null) {
          exercises.add(_replacementFor(exercise, candidate));
          editedAny = true;
          editMore = edit.scope == PlanEditScope.allSlotsOfExercise;
          continue;
        }
      }
      exercises.add(exercise);
    }
    days.add(
      PlanDay(
        dayIndex: day.dayIndex,
        kind: day.kind,
        warmUpMinutes: day.warmUpMinutes,
        hasCardioFinisher: day.hasCardioFinisher,
        exercises: exercises,
      ),
    );
  }

  if (!editedAny) {
    return _copyPlan(
      plan,
      warnings: <EngineWarning>[
        ...plan.warnings,
        EngineWarning(
          WarningCode.planEditTargetMissing,
          '${edit.exerciseId}->${edit.replacementId}',
        ),
      ],
    );
  }
  return _copyPlan(
    plan,
    days: days,
    editStamps: <PlanEditStamp>[...plan.editStamps, stamp],
  );
}

Plan _applyExclusion(Plan plan, ExcludeExercise edit, PlanEditStamp stamp) {
  var found = false;
  var missedSubstitution = false;
  final days = <PlanDay>[];
  for (final day in plan.days) {
    final exercises = <PlanExercise>[];
    for (final exercise in day.exercises) {
      if (exercise.exerciseId != edit.exerciseId) {
        exercises.add(exercise);
        continue;
      }
      found = true;
      final candidates =
          exercise.orderedSwapCandidates
              .where((candidate) => candidate.exerciseId != edit.exerciseId)
              .toList(growable: false)
            ..sort((left, right) {
              final tier = left.tier.compareTo(right.tier);
              if (tier != 0) return tier;
              final rank = left.rank.compareTo(right.rank);
              if (rank != 0) return rank;
              return left.exerciseId.compareTo(right.exerciseId);
            });
      if (candidates.isEmpty) {
        missedSubstitution = true;
        exercises.add(exercise);
      } else {
        exercises.add(_replacementFor(exercise, candidates.first));
      }
    }
    days.add(
      PlanDay(
        dayIndex: day.dayIndex,
        kind: day.kind,
        warmUpMinutes: day.warmUpMinutes,
        hasCardioFinisher: day.hasCardioFinisher,
        exercises: exercises,
      ),
    );
  }

  final warnings = <EngineWarning>[...plan.warnings];
  if (!found || missedSubstitution) {
    warnings.add(
      EngineWarning(WarningCode.planEditTargetMissing, edit.exerciseId),
    );
  }
  return _copyPlan(
    plan,
    days: days,
    warnings: warnings,
    editStamps: <PlanEditStamp>[...plan.editStamps, stamp],
  );
}

PlanExercise _replacementFor(
  PlanExercise source,
  PlanSwapCandidate replacement,
) => PlanExercise(
  exerciseId: replacement.exerciseId,
  name: replacement.name,
  blockRole: replacement.blockRole,
  movementClass: replacement.movementClass,
  metricType: replacement.metricType,
  laterality: replacement.laterality,
  difficultyTier: replacement.difficultyTier,
  resistanceEquipment: replacement.resistanceEquipment,
  supportEquipment: replacement.supportEquipment,
  bwContribution: replacement.bwContribution,
  loadStepOverride: replacement.loadStepOverride,
  dropPriority: source.dropPriority,
  isEmphasis: source.isEmphasis,
  rotatesAcrossMesocycles: false,
  rotationCandidateIds: const <String>[],
  orderedSwapCandidates: source.orderedSwapCandidates.where(
    (candidate) => candidate.exerciseId != replacement.exerciseId,
  ),
  baseDose: replacement.baseDose,
  repRange: replacement.repRange,
);

Plan _copyPlan(
  Plan plan, {
  Iterable<PlanDay>? days,
  Iterable<EngineWarning>? warnings,
  Iterable<PlanEditStamp>? editStamps,
}) => Plan(
  mesocycleIndex: plan.mesocycleIndex,
  stamps: plan.stamps,
  mesocycleCalendar: plan.mesocycleCalendar,
  days: days ?? plan.days,
  warnings: warnings ?? plan.warnings,
  editStamps: editStamps ?? plan.editStamps,
);

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
