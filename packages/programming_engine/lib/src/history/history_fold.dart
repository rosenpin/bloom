/// The deterministic, single-pass event-log fold.
///
/// This is progression memory: no independently persisted working-load or stall
/// rows exist. Replaying the ordered records always rebuilds the same snapshot.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../config/programming_config.dart';
import '../core/effort.dart';
import '../core/events.dart';
import '../core/units.dart';
import '../progression/load_suggester.dart';
import 'training_history.dart';

final class ExerciseHistorySnapshot {
  const ExerciseHistorySnapshot({
    required this.lastLoad,
    required this.lastReps,
    required this.lastEffort,
    required this.everSeen,
    required this.sessionsSinceProgress,
    required this.consecutiveTooHardCount,
    required this.lastWorkingLoad,
    required this.lastWorkingReps,
    required this.lastWorkingEffort,
    required this.lastSeenSessionDate,
    required this.lastMesocycleIndex,
  });

  static const ExerciseHistorySnapshot empty = ExerciseHistorySnapshot(
    lastLoad: null,
    lastReps: null,
    lastEffort: null,
    everSeen: false,
    sessionsSinceProgress: 0,
    consecutiveTooHardCount: 0,
    lastWorkingLoad: null,
    lastWorkingReps: null,
    lastWorkingEffort: null,
    lastSeenSessionDate: null,
    lastMesocycleIndex: null,
  );

  final Kg? lastLoad;
  final int? lastReps;
  final EffortLevel? lastEffort;
  final bool everSeen;

  /// Consecutive same-load exposures that have not advanced reps. The first
  /// exposure establishes count 1, allowing the third prescribed exposure to
  /// carry the §5 stall deload.
  final int sessionsSinceProgress;
  final int consecutiveTooHardCount;

  /// Most recent non-deload-week values. Programmed deload loads are temporary;
  /// the next mesocycle steps from this working anchor.
  final Kg? lastWorkingLoad;
  final int? lastWorkingReps;
  final EffortLevel? lastWorkingEffort;
  final DateTime? lastSeenSessionDate;
  final int? lastMesocycleIndex;

  ExerciseSnapshot? asProgressionSnapshot({bool useWorkingAnchor = false}) {
    final load = useWorkingAnchor ? lastWorkingLoad : lastLoad;
    final reps = useWorkingAnchor ? lastWorkingReps : lastReps;
    if (load == null || reps == null) return null;
    return ExerciseSnapshot(
      lastLoad: load,
      lastReps: reps,
      targetReps: reps,
      reportedEffort: useWorkingAnchor ? lastWorkingEffort : lastEffort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExerciseHistorySnapshot &&
      other.lastLoad == lastLoad &&
      other.lastReps == lastReps &&
      other.lastEffort == lastEffort &&
      other.everSeen == everSeen &&
      other.sessionsSinceProgress == sessionsSinceProgress &&
      other.consecutiveTooHardCount == consecutiveTooHardCount &&
      other.lastWorkingLoad == lastWorkingLoad &&
      other.lastWorkingReps == lastWorkingReps &&
      other.lastWorkingEffort == lastWorkingEffort &&
      other.lastSeenSessionDate == lastSeenSessionDate &&
      other.lastMesocycleIndex == lastMesocycleIndex;

  @override
  int get hashCode => Object.hash(
    lastLoad,
    lastReps,
    lastEffort,
    everSeen,
    sessionsSinceProgress,
    consecutiveTooHardCount,
    lastWorkingLoad,
    lastWorkingReps,
    lastWorkingEffort,
    lastSeenSessionDate,
    lastMesocycleIndex,
  );
}

final class TrainingSnapshot {
  TrainingSnapshot({
    required Map<String, ExerciseHistorySnapshot> exercises,
    required Iterable<String> excludedExerciseIds,
    required this.lastCompletedSessionDate,
    required this.completedSessionCount,
  }) : exercises = Map<String, ExerciseHistorySnapshot>.unmodifiable(exercises),
       excludedExerciseIds = Set<String>.unmodifiable(excludedExerciseIds);

  factory TrainingSnapshot.empty({
    Iterable<String> userExcludedExerciseIds = const <String>[],
  }) => TrainingSnapshot(
    exercises: const <String, ExerciseHistorySnapshot>{},
    excludedExerciseIds: userExcludedExerciseIds,
    lastCompletedSessionDate: null,
    completedSessionCount: 0,
  );

  final Map<String, ExerciseHistorySnapshot> exercises;
  final Set<String> excludedExerciseIds;
  final DateTime? lastCompletedSessionDate;
  final int completedSessionCount;

  ExerciseHistorySnapshot exercise(String exerciseId) =>
      exercises[exerciseId] ?? ExerciseHistorySnapshot.empty;

  @override
  bool operator ==(Object other) =>
      other is TrainingSnapshot &&
      const MapEquality<String, ExerciseHistorySnapshot>().equals(
        other.exercises,
        exercises,
      ) &&
      const SetEquality<String>().equals(
        other.excludedExerciseIds,
        excludedExerciseIds,
      ) &&
      other.lastCompletedSessionDate == lastCompletedSessionDate &&
      other.completedSessionCount == completedSessionCount;

  @override
  int get hashCode => Object.hash(
    const MapEquality<String, ExerciseHistorySnapshot>().hash(exercises),
    const SetEquality<String>().hash(excludedExerciseIds),
    lastCompletedSessionDate,
    completedSessionCount,
  );
}

/// O(records + events), in the caller-provided order.
@useResult
TrainingSnapshot foldTrainingHistory(TrainingHistory history) {
  var snapshot = TrainingSnapshot.empty(
    userExcludedExerciseIds: history.userExcludedExerciseIds,
  );
  for (final record in history.records) {
    snapshot = incrementTrainingSnapshot(snapshot, record);
  }
  return snapshot;
}

/// The incremental form of [foldTrainingHistory]. This is public so cache users
/// can prove `fold(all) == increment(fold(prefix), suffix)` without maintaining a
/// second set of rules.
@useResult
TrainingSnapshot incrementTrainingSnapshot(
  TrainingSnapshot previous,
  SessionRecord record,
) {
  final exercises = Map<String, ExerciseHistorySnapshot>.of(previous.exercises);
  final exclusions = Set<String>.of(previous.excludedExerciseIds);
  final perExercise = <String, _SessionExercise>{};

  for (final event in record.events) {
    switch (event) {
      case SetCompleted():
        (perExercise[event.exerciseId] ??= _SessionExercise()).lastSet = event;
      case EffortReported():
        (perExercise[event.exerciseId] ??= _SessionExercise()).effort =
            event.level;
      case PainReported():
        exclusions.add(event.exerciseId);
      case SwapRequested() || Shorten() || LowEnergy() || SessionAbandoned():
        break;
    }
  }

  for (final entry in perExercise.entries) {
    final prior = exercises[entry.key] ?? ExerciseHistorySnapshot.empty;
    final session = entry.value;
    final set = session.lastSet;
    var noProgressCount = prior.sessionsSinceProgress;
    final countsTowardStall =
        record.weekKind != MesocycleWeekKind.easier &&
        record.weekKind != MesocycleWeekKind.deload;
    if (set != null && countsTowardStall) {
      final priorLoad = prior.lastLoad;
      final priorReps = prior.lastReps;
      if (priorLoad == null || priorReps == null) {
        noProgressCount = 1;
      } else if (priorLoad.isCloseTo(set.load)) {
        noProgressCount = set.reps > priorReps ? 0 : noProgressCount + 1;
      } else {
        noProgressCount = 0;
      }
    }

    final hadExerciseActivity = set != null || session.effort != null;
    final tooHardCount = !hadExerciseActivity
        ? prior.consecutiveTooHardCount
        : session.effort == EffortLevel.tooHard
        ? prior.consecutiveTooHardCount + 1
        : 0;
    final isWorkingWeek = record.weekKind != MesocycleWeekKind.deload;

    exercises[entry.key] = ExerciseHistorySnapshot(
      lastLoad: set?.load ?? prior.lastLoad,
      lastReps: set?.reps ?? prior.lastReps,
      lastEffort: set != null ? session.effort : prior.lastEffort,
      everSeen: prior.everSeen || set != null,
      sessionsSinceProgress: noProgressCount,
      consecutiveTooHardCount: tooHardCount,
      lastWorkingLoad: set != null && isWorkingWeek
          ? set.load
          : prior.lastWorkingLoad,
      lastWorkingReps: set != null && isWorkingWeek
          ? set.reps
          : prior.lastWorkingReps,
      lastWorkingEffort: set != null && isWorkingWeek
          ? session.effort
          : prior.lastWorkingEffort,
      lastSeenSessionDate: hadExerciseActivity
          ? record.date
          : prior.lastSeenSessionDate,
      lastMesocycleIndex: hadExerciseActivity
          ? record.mesocycleIndex
          : prior.lastMesocycleIndex,
    );
  }

  return TrainingSnapshot(
    exercises: exercises,
    excludedExerciseIds: exclusions,
    lastCompletedSessionDate: record.isCompleted
        ? record.date
        : previous.lastCompletedSessionDate,
    completedSessionCount:
        previous.completedSessionCount + (record.isCompleted ? 1 : 0),
  );
}

final class _SessionExercise {
  SetCompleted? lastSet;
  EffortLevel? effort;
}
