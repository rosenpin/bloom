/// Mid-session time: one total, deterministic reducer.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../config/programming_config.dart';
import '../content/exercise.dart';
import '../core/dose.dart';
import '../core/effort.dart';
import '../core/events.dart';
import '../core/load_suggestion.dart';
import '../core/prescription.dart';
import '../core/reason_code.dart';
import '../core/units.dart';
import '../core/warnings.dart';
import '../plan/plan.dart';
import '../plan/plan_edit.dart';
import '../progression/load_suggester.dart';
import 'session_state.dart';

@useResult
SessionState advanceSession(SessionState state, SessionEvent event) {
  final reduced = state.isAbandoned && event is! SessionAbandoned
      ? _warn(
          state,
          WarningCode.sessionEventIgnored,
          'after-abandon/${event.runtimeType}',
        )
      : _SessionReducer(state).apply(event);
  return reduced.copyWith(events: <SessionEvent>[...state.events, event]);
}

final class _SessionReducer {
  const _SessionReducer(this.state);

  final SessionState state;

  SessionState apply(SessionEvent event) => switch (event) {
    SetCompleted() => _setCompleted(event),
    EffortReported() => _effortReported(event),
    SwapRequested() => _swapRequested(event),
    Shorten() => _shorten(event),
    LowEnergy() => _lowEnergy(),
    PainReported() => _painReported(event),
    SessionAbandoned() => _abandon(),
  };

  SessionState _setCompleted(SetCompleted event) {
    final index = _entryIndex(event.exerciseId);
    if (index == -1) return _unknown(event.exerciseId);
    final entry = state.exercises[index];
    if (entry.status == SessionExerciseStatus.removed ||
        entry.status == SessionExerciseStatus.skipped) {
      return _ignored('${event.exerciseId}/set/${entry.status.name}');
    }

    final wasCalibrating = entry.calibration.isCalibrating;
    final logs = <SetCompleted>[
      ...entry.setLogs.where((set) => set.setIndex != event.setIndex),
      event,
    ]..sort((left, right) => left.setIndex.compareTo(right.setIndex));
    var prescription = entry.prescription;
    var calibration = entry.calibration;
    var status = logs.length >= prescription.dose.sets
        ? SessionExerciseStatus.done
        : entry.status == SessionExerciseStatus.swapped
        ? SessionExerciseStatus.swapped
        : SessionExerciseStatus.active;
    var nextState = state;

    if (wasCalibrating) {
      final probeCount = calibration.probeSetsCompleted + 1;
      final loads = state.config.availableLoads(
        entry.planExercise,
        state.unitSystem,
      );
      final hasUsableStep =
          loads.smallestStep.isFinite && loads.smallestStep.isPositive;
      final probeLoad = hasUsableStep
          ? loads.snapDown(event.load)
          : event.load.isFinite
          ? event.load
          : loads.floor;
      final failedAtFloor =
          event.reps < state.config.calibrationMinCleanReps &&
          probeLoad.isCloseTo(loads.floor);
      if (failedAtFloor) {
        calibration = CalibrationState(
          phase: CalibrationPhase.failed,
          probeSetsCompleted: probeCount,
          currentLoad: probeLoad,
        );
        status = SessionExerciseStatus.removed;
        prescription = _withWhy(prescription, const <ReasonCode>[
          ReasonCode.atEquipmentFloor,
        ]);
        nextState = _offerSafeSwap(
          nextState,
          entry,
          reason: SwapReason.uncomfortable,
          cause: SwapSuggestionCause.calibrationFloor,
        );
        nextState = _warn(
          nextState,
          WarningCode.calibrationFloorFailed,
          event.exerciseId,
        );
      } else if (probeCount >= state.config.calibrationMaxTestSets) {
        calibration = CalibrationState(
          phase: CalibrationPhase.settled,
          probeSetsCompleted: probeCount,
          currentLoad: probeLoad,
          workingLoad: probeLoad,
        );
        prescription = _settleCalibration(prescription, probeLoad);
      } else {
        calibration = CalibrationState(
          phase: CalibrationPhase.awaitingEffort,
          probeSetsCompleted: probeCount,
          currentLoad: probeLoad,
        );
      }
    } else if (event.setIndex == 0 &&
        prescription.dose is RepsDose &&
        event.reps < (prescription.dose as RepsDose).range.min) {
      final adjustment = _fractionalAdjustment(
        state,
        entry,
        baseLoad: event.load,
        fraction: 1 - state.config.missedBottomDropFraction,
        reason: ReasonCode.missedBottomSameSessionDrop,
      );
      prescription = adjustment.prescription;
      nextState = _withReason(
        nextState,
        ReasonCode.missedBottomSameSessionDrop,
      );
    }

    final updated = entry.copyWith(
      prescription: prescription,
      setLogs: logs,
      calibration: calibration,
      status: status,
    );
    nextState = _replaceEntry(nextState, index, updated);
    return nextState.copyWith(
      budget: nextState.budget.copyWith(
        completedSetCount: nextState.exercises.fold<int>(
          0,
          (total, item) => total + item.setsCompleted,
        ),
      ),
    );
  }

  SessionState _effortReported(EffortReported event) {
    final index = _entryIndex(event.exerciseId);
    if (index == -1) return _unknown(event.exerciseId);
    final entry = state.exercises[index];
    if (entry.status == SessionExerciseStatus.removed ||
        entry.status == SessionExerciseStatus.skipped) {
      return _ignored('${event.exerciseId}/effort/${entry.status.name}');
    }

    var prescription = entry.prescription;
    var calibration = entry.calibration;
    var nextState = state;
    if (calibration.phase == CalibrationPhase.awaitingEffort) {
      final current = calibration.currentLoad;
      if (current == null) {
        nextState = _ignored('${event.exerciseId}/calibration/no-load');
      } else {
        switch (event.level) {
          case EffortLevel.wayTooEasy || EffortLevel.aBitEasy:
            if (calibration.probeSetsCompleted >=
                state.config.calibrationMaxTestSets) {
              calibration = calibration.copyWith(
                phase: CalibrationPhase.settled,
                workingLoad: current,
              );
              prescription = _settleCalibration(prescription, current);
            } else {
              final nextLoad = _nextCalibrationProbe(
                entry.planExercise,
                current,
                state.config,
                state.unitSystem,
                state.bodyMass.isPositive ? state.bodyMass : null,
              );
              calibration = calibration.copyWith(
                phase: CalibrationPhase.awaitingProbe,
                currentLoad: nextLoad,
              );
              prescription = ExercisePrescription(
                exerciseId: prescription.exerciseId,
                dose: prescription.dose,
                suggestion: NeedsCalibration(
                  floor: nextLoad,
                  probeReps: state.config.calibrationProbeReps,
                ),
                laterality: prescription.laterality,
                bridge: prescription.bridge,
                why: _mergeReasons(prescription.why, const <ReasonCode>[
                  ReasonCode.calibrationRegimeJump,
                  ReasonCode.weightStep,
                ]),
              );
              nextState = _withReason(
                nextState,
                ReasonCode.calibrationRegimeJump,
              );
            }
          case EffortLevel.justRight:
            calibration = calibration.copyWith(
              phase: CalibrationPhase.settled,
              workingLoad: current,
            );
            prescription = _settleCalibration(prescription, current);
          case EffortLevel.harderThanIdLike || EffortLevel.tooHard:
            final floor = state.config
                .availableLoads(entry.planExercise, state.unitSystem)
                .floor;
            calibration = calibration.copyWith(
              phase: CalibrationPhase.settled,
              currentLoad: floor,
              workingLoad: floor,
            );
            prescription = _settleCalibration(prescription, floor);
        }
      }
    }

    if (calibration.phase == CalibrationPhase.settled) {
      nextState = _withReason(nextState, ReasonCode.calibrationSettled);
    }
    return _replaceEntry(
      nextState,
      index,
      entry.copyWith(
        prescription: prescription,
        feelReport: event.level,
        calibration: calibration,
      ),
    );
  }

  SessionState _swapRequested(SwapRequested event) {
    final index = _entryIndex(event.exerciseId);
    if (index == -1) return _unknown(event.exerciseId);
    final entry = state.exercises[index];
    if (entry.isTerminal) {
      return _ignored('${event.exerciseId}/swap/${entry.status.name}');
    }
    final candidate = _bestCandidate(entry);
    if (candidate == null) {
      return _warn(state, WarningCode.noEligibleSessionSwap, event.exerciseId);
    }

    final resolution = _prescribeCandidate(state, candidate);
    final prescription = resolution.prescription;
    final replacementPlan = _candidatePlanExercise(entry, candidate);
    final replacement = SessionExerciseEntry(
      originalExerciseId: entry.originalExerciseId,
      planExercise: replacementPlan,
      prescription: prescription,
      setLogs: const <SetCompleted>[],
      feelReport: null,
      calibration: CalibrationState.forPrescription(prescription),
      status: SessionExerciseStatus.swapped,
    );
    final suggestion = KeepSwapPlanEditSuggestion(
      edit: KeepSwap(
        exerciseId: entry.originalExerciseId,
        replacementId: candidate.exerciseId,
        scope: PlanEditScope.thisSlot,
        dayIndex: state.dayIndex,
      ),
      tier: candidate.tier,
      reason: event.reason,
    );
    var nextState = _replaceEntry(state, index, replacement);
    nextState = nextState.copyWith(
      pendingPlanEditSuggestions: <PendingPlanEditSuggestion>[
        ...nextState.pendingPlanEditSuggestions.where(
          (item) => item.sourceExerciseId != suggestion.sourceExerciseId,
        ),
        suggestion,
      ],
    );
    return _withReason(nextState, ReasonCode.swapApplied);
  }

  SessionState _shorten(Shorten event) {
    if (state.lastShortenMinutes == event.minutes) {
      return _warn(
        state,
        WarningCode.sessionModifierAlreadyApplied,
        'shorten/${event.minutes}',
      );
    }
    final available = event.minutes < state.budget.availableMinutes
        ? event.minutes
        : state.budget.availableMinutes;
    final targetCount = _exerciseTargetForMinutes(event.minutes, state.config);
    final exercises = <SessionExerciseEntry>[...state.exercises];
    final liveCount = exercises
        .where(
          (entry) =>
              entry.status != SessionExerciseStatus.removed &&
              entry.status != SessionExerciseStatus.skipped,
        )
        .length;
    var toDrop = (liveCount - targetCount).clamp(0, liveCount);
    final candidates =
        <(int, SessionExerciseEntry)>[
          for (var index = 0; index < exercises.length; index++)
            if (exercises[index].isUnstarted &&
                !exercises[index].planExercise.blockRole.isPrimary &&
                exercises[index].status != SessionExerciseStatus.removed &&
                exercises[index].status != SessionExerciseStatus.skipped)
              (index, exercises[index]),
        ]..sort((left, right) {
          final priority = right.$2.planExercise.dropPriority.compareTo(
            left.$2.planExercise.dropPriority,
          );
          if (priority != 0) return priority;
          return right.$1.compareTo(left.$1);
        });
    for (final candidate in candidates) {
      if (toDrop == 0) break;
      exercises[candidate.$1] = candidate.$2.copyWith(
        status: SessionExerciseStatus.removed,
        prescription: _withWhy(candidate.$2.prescription, const <ReasonCode>[
          ReasonCode.shortened,
        ]),
      );
      toDrop--;
    }
    var nextState = state.copyWith(
      exercises: exercises,
      budget: state.budget.copyWith(availableMinutes: available),
      lastShortenMinutes: event.minutes,
    );
    nextState = _withReason(nextState, ReasonCode.shortened);
    return nextState;
  }

  SessionState _lowEnergy() {
    if (state.lowEnergyWasApplied) {
      return _warn(
        state,
        WarningCode.sessionModifierAlreadyApplied,
        'lowEnergy',
      );
    }
    final exercises = <SessionExerciseEntry>[];
    for (final entry in state.exercises) {
      if (!entry.isUnstarted ||
          entry.status == SessionExerciseStatus.removed ||
          entry.status == SessionExerciseStatus.skipped) {
        exercises.add(entry);
        continue;
      }
      final dose = switch (entry.prescription.dose) {
        RepsDose(:final range) =>
          (entry.prescription.dose as RepsDose).copyWith(targetReps: range.min),
        TimedDose() => entry.prescription.dose,
      };
      var prescription = ExercisePrescription(
        exerciseId: entry.exerciseId,
        dose: dose,
        suggestion: entry.prescription.suggestion,
        laterality: entry.prescription.laterality,
        bridge: entry.prescription.bridge,
        why: _mergeReasons(entry.prescription.why, const <ReasonCode>[
          ReasonCode.lowEnergyApplied,
        ]),
      );
      final base = _loadFromSuggestion(entry.prescription.suggestion);
      if (base != null && entry.prescription.suggestion is! NeedsCalibration) {
        final adjustment = _fractionalAdjustment(
          state,
          entry.copyWith(prescription: prescription),
          baseLoad: base,
          fraction: state.config.lowEnergyLoadFraction,
          reason: ReasonCode.lowEnergyApplied,
        );
        prescription = adjustment.prescription;
      }
      exercises.add(entry.copyWith(prescription: prescription));
    }
    var nextState = state.copyWith(
      exercises: exercises,
      lowEnergyWasApplied: true,
    );
    nextState = _withReason(nextState, ReasonCode.lowEnergyApplied);
    return nextState;
  }

  SessionState _painReported(PainReported event) {
    final index = _entryIndex(event.exerciseId);
    if (index == -1) return _unknown(event.exerciseId);
    if (state.pendingExclusions.contains(event.exerciseId)) {
      return _warn(
        state,
        WarningCode.sessionModifierAlreadyApplied,
        'pain/${event.exerciseId}',
      );
    }
    final entry = state.exercises[index];
    var nextState = state.copyWith(
      pendingExclusions: <String>{...state.pendingExclusions, event.exerciseId},
      excludedExerciseIds: <String>{
        ...state.excludedExerciseIds,
        event.exerciseId,
      },
    );
    nextState = _replaceEntry(
      nextState,
      index,
      entry.copyWith(
        status: SessionExerciseStatus.removed,
        prescription: _withWhy(entry.prescription, const <ReasonCode>[
          ReasonCode.painExclusion,
        ]),
      ),
    );
    nextState = _offerSafeSwap(
      nextState,
      entry,
      reason: SwapReason.uncomfortable,
      cause: SwapSuggestionCause.pain,
    );
    return _withReason(nextState, ReasonCode.painExclusion);
  }

  SessionState _abandon() {
    if (state.isAbandoned) {
      return _warn(
        state,
        WarningCode.sessionModifierAlreadyApplied,
        'abandoned',
      );
    }
    return state.copyWith(
      exercises: <SessionExerciseEntry>[
        for (final entry in state.exercises)
          if (entry.status == SessionExerciseStatus.done ||
              entry.status == SessionExerciseStatus.removed)
            entry
          else
            entry.copyWith(status: SessionExerciseStatus.skipped),
      ],
      isAbandoned: true,
    );
  }

  int _entryIndex(String exerciseId) {
    for (var index = 0; index < state.exercises.length; index++) {
      if (state.exercises[index].exerciseId == exerciseId) return index;
    }
    for (var index = 0; index < state.exercises.length; index++) {
      if (state.exercises[index].originalExerciseId == exerciseId) return index;
    }
    return -1;
  }

  SessionState _unknown(String exerciseId) =>
      _warn(state, WarningCode.unknownSessionExercise, exerciseId);

  SessionState _ignored(String detail) =>
      _warn(state, WarningCode.sessionEventIgnored, detail);

  PlanSwapCandidate? _bestCandidate(
    SessionExerciseEntry entry, {
    int maxTier = 3,
    SessionState? fromState,
  }) {
    final source = fromState ?? state;
    final excluded = <String>{
      ...source.excludedExerciseIds,
      ...source.pendingExclusions,
      entry.exerciseId,
    };
    final candidates =
        entry.planExercise.orderedSwapCandidates
            .where(
              (candidate) =>
                  candidate.tier <= maxTier &&
                  !excluded.contains(candidate.exerciseId),
            )
            .toList(growable: false)
          ..sort(_compareCandidates);
    return candidates.isEmpty ? null : candidates.first;
  }

  SessionState _offerSafeSwap(
    SessionState targetState,
    SessionExerciseEntry entry, {
    required SwapReason reason,
    required SwapSuggestionCause cause,
  }) {
    final candidate = _bestCandidate(entry, maxTier: 2, fromState: targetState);
    if (candidate == null) {
      return _warn(
        targetState,
        WarningCode.noEligibleSessionSwap,
        entry.exerciseId,
      );
    }
    final suggestion = SessionSwapSuggestion(
      sourceExerciseId: entry.exerciseId,
      candidate: candidate,
      reason: reason,
      cause: cause,
    );
    return targetState.copyWith(
      pendingSwapSuggestions: <SessionSwapSuggestion>[
        ...targetState.pendingSwapSuggestions.where(
          (item) => item.sourceExerciseId != suggestion.sourceExerciseId,
        ),
        suggestion,
      ],
    );
  }
}

int _compareCandidates(PlanSwapCandidate left, PlanSwapCandidate right) {
  final tier = left.tier.compareTo(right.tier);
  if (tier != 0) return tier;
  final rank = left.rank.compareTo(right.rank);
  if (rank != 0) return rank;
  return left.exerciseId.compareTo(right.exerciseId);
}

SessionState _replaceEntry(
  SessionState state,
  int index,
  SessionExerciseEntry replacement,
) => state.copyWith(
  exercises: <SessionExerciseEntry>[
    for (var current = 0; current < state.exercises.length; current++)
      current == index ? replacement : state.exercises[current],
  ],
);

SessionState _warn(SessionState state, WarningCode code, String detail) =>
    state.copyWith(
      warnings: <EngineWarning>[...state.warnings, EngineWarning(code, detail)],
    );

SessionState _withReason(SessionState state, ReasonCode reason) =>
    state.reasonCodes.contains(reason)
    ? state
    : state.copyWith(reasonCodes: <ReasonCode>[...state.reasonCodes, reason]);

List<ReasonCode> _mergeReasons(
  Iterable<ReasonCode> existing,
  Iterable<ReasonCode> added,
) {
  final result = <ReasonCode>[...existing];
  for (final reason in added) {
    if (!result.contains(reason)) result.add(reason);
  }
  return List<ReasonCode>.unmodifiable(result);
}

ExercisePrescription _withWhy(
  ExercisePrescription prescription,
  Iterable<ReasonCode> reasons,
) => ExercisePrescription(
  exerciseId: prescription.exerciseId,
  dose: prescription.dose,
  suggestion: prescription.suggestion,
  laterality: prescription.laterality,
  bridge: prescription.bridge,
  why: _mergeReasons(prescription.why, reasons),
);

ExercisePrescription _settleCalibration(
  ExercisePrescription prescription,
  Kg load,
) {
  final dose = switch (prescription.dose) {
    RepsDose(:final range) => (prescription.dose as RepsDose).copyWith(
      targetReps: range.min,
    ),
    TimedDose() => prescription.dose,
  };
  return ExercisePrescription(
    exerciseId: prescription.exerciseId,
    dose: dose,
    suggestion: SuggestedLoad(load),
    laterality: prescription.laterality,
    bridge: prescription.bridge,
    why: _mergeReasons(prescription.why, const <ReasonCode>[
      ReasonCode.calibrationSettled,
    ]),
  );
}

Kg _nextCalibrationProbe(
  LoadProfile profile,
  Kg current,
  ProgrammingConfig config,
  UnitSystem unitSystem,
  Kg? bodyMass,
) {
  final loads = config.availableLoads(profile, unitSystem);
  final oneStep = loads.stepAt(current);
  final probeLoadFraction =
      config.probeLoadFractionByMovementClass[profile.movementClass];
  assert(probeLoadFraction != null);
  final expectedWorkingLoad =
      probeLoadFraction! *
      (bodyMass?.value ?? 0) *
      (1 - profile.bwContribution);
  final jump = math.max(
    oneStep.value,
    config.calibrationJumpFraction * expectedWorkingLoad,
  );
  final target = current + Kg(jump);
  var snapped = loads.snapDown(target);
  if (snapped <= current) snapped = loads.shift(current, 1);
  return snapped;
}

_ResolvedPrescription _fractionalAdjustment(
  SessionState state,
  SessionExerciseEntry entry, {
  required Kg baseLoad,
  required double fraction,
  required ReasonCode reason,
}) {
  final dose = entry.prescription.dose;
  final range = dose is RepsDose ? dose.range : const RepRange(1, 1);
  final effort = dose is RepsDose ? dose.effort : const EffortTarget(7);
  final targetReps = dose is RepsDose ? dose.targetReps : range.min;
  final decision = LoadSuggester(state.config).suggest(
    ProgressionInput(
      profile: entry.planExercise,
      range: range,
      effort: effort,
      unitSystem: state.unitSystem,
      history: ExerciseSnapshot(
        lastLoad: baseLoad,
        lastReps: targetReps,
        targetReps: targetReps,
      ),
      bodyMass: state.bodyMass.isPositive ? state.bodyMass : null,
      preSuggesterAdjustment: PreSuggesterAdjustment.fractionalDeload(
        reason: reason,
        loadFraction: fraction,
      ),
    ),
  );
  final nextDose = dose is RepsDose
      ? dose.copyWith(targetReps: decision.targetReps)
      : dose;
  return (
    prescription: ExercisePrescription(
      exerciseId: entry.exerciseId,
      dose: nextDose,
      suggestion: decision.suggestion,
      laterality: entry.prescription.laterality,
      bridge: decision.bridge ?? entry.prescription.bridge,
      why: _mergeReasons(entry.prescription.why, decision.why),
    ),
  );
}

_ResolvedPrescription _prescribeCandidate(
  SessionState state,
  PlanSwapCandidate candidate,
) {
  var dose = state.config.doseForWeek(
    candidate.baseDose,
    state.mesocycleWeekIndex,
  );
  final range = dose is RepsDose ? dose.range : const RepRange(1, 1);
  final decision = LoadSuggester(state.config).suggest(
    ProgressionInput(
      profile: candidate,
      range: range,
      effort: dose is RepsDose ? dose.effort : const EffortTarget(7),
      unitSystem: state.unitSystem,
      history: state.historySnapshot
          .exercise(candidate.exerciseId)
          .asProgressionSnapshot(),
      bodyMass: state.bodyMass.isPositive ? state.bodyMass : null,
      daysSinceLastSession: state.daysSinceLastSession ?? 0,
    ),
  );
  if (dose is RepsDose) {
    dose = dose.copyWith(targetReps: decision.targetReps);
  } else if (dose is TimedDose && decision.hold != null) {
    dose = dose.copyWith(hold: decision.hold);
  }
  return (
    prescription: ExercisePrescription(
      exerciseId: candidate.exerciseId,
      dose: dose,
      suggestion: decision.suggestion,
      laterality: candidate.laterality,
      bridge: decision.bridge,
      why: _mergeReasons(decision.why, const <ReasonCode>[
        ReasonCode.swapApplied,
      ]),
    ),
  );
}

typedef _ResolvedPrescription = ({ExercisePrescription prescription});

PlanExercise _candidatePlanExercise(
  SessionExerciseEntry source,
  PlanSwapCandidate candidate,
) => PlanExercise(
  exerciseId: candidate.exerciseId,
  name: candidate.name,
  blockRole: candidate.blockRole,
  movementClass: candidate.movementClass,
  metricType: candidate.metricType,
  laterality: candidate.laterality,
  difficultyTier: candidate.difficultyTier,
  resistanceEquipment: candidate.resistanceEquipment,
  supportEquipment: candidate.supportEquipment,
  bwContribution: candidate.bwContribution,
  loadStepOverride: candidate.loadStepOverride,
  dropPriority: source.planExercise.dropPriority,
  isEmphasis: source.planExercise.isEmphasis,
  rotatesAcrossMesocycles: false,
  rotationCandidateIds: const <String>[],
  orderedSwapCandidates: source.planExercise.orderedSwapCandidates.where(
    (item) => item.exerciseId != candidate.exerciseId,
  ),
  baseDose: candidate.baseDose,
  repRange: candidate.repRange,
);

int _exerciseTargetForMinutes(int minutes, ProgrammingConfig config) {
  assert(config.exerciseCountByMinutes.isNotEmpty);
  final keys = config.exerciseCountByMinutes.keys.toList(growable: false)
    ..sort();
  var selected = keys.first;
  for (final key in keys) {
    if (key <= minutes) selected = key;
  }
  return config.exerciseCountByMinutes[selected]!;
}

Kg? _loadFromSuggestion(LoadSuggestion suggestion) => switch (suggestion) {
  SuggestedLoad(:final kg) => kg,
  BodyweightOnly(:final added) => added,
  NeedsCalibration(:final floor) => floor,
  RepOrDurationTarget() => null,
};
