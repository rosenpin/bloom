/// Session-resolve time: plan structure meets the folded event log.
library;

import 'package:meta/meta.dart';

import '../config/programming_config.dart';
import '../content/exercise.dart';
import '../core/dose.dart';
import '../core/effort.dart';
import '../core/events.dart';
import '../core/prescription.dart';
import '../core/reason_code.dart';
import '../core/units.dart';
import '../core/warnings.dart';
import '../history/history_fold.dart';
import '../history/training_history.dart';
import '../plan/plan.dart';
import '../progression/layoff.dart';
import '../progression/load_suggester.dart';
import 'session_state.dart';

/// Resolve-time modifiers remain empty in v1. Shorten and low-energy are events
/// consumed by `advanceSession`, so replay owns those mid-session decisions.
final class SessionModifiers {
  const SessionModifiers();

  @override
  bool operator ==(Object other) => other is SessionModifiers;

  @override
  int get hashCode => (SessionModifiers).hashCode;
}

/// Session resolver for a validated plan and event history.
@useResult
SessionResolution resolveSession(
  Plan plan,
  TrainingHistory history,
  DateTime date, {
  SessionModifiers modifiers = const SessionModifiers(),
  ProgrammingConfig? config,
}) {
  // Read the empty modifiers object so adding a field later cannot accidentally
  // leave the parameter ignored by analysis.
  final _ = modifiers;
  return _ResolutionPass(
    plan,
    history,
    date,
    config ?? ProgrammingConfig(),
  ).run();
}

final class _ResolutionPass {
  _ResolutionPass(this.plan, this.history, this.date, this.config)
    : snapshot = foldTrainingHistory(history),
      loadSuggester = LoadSuggester(config);

  final Plan plan;
  final TrainingHistory history;
  final DateTime date;
  final ProgrammingConfig config;
  final TrainingSnapshot snapshot;
  final LoadSuggester loadSuggester;
  final warnings = <EngineWarning>[];
  final resolutionReasons = <ReasonCode>[];

  late final int mesocycleWeeks = config.mesocycleWeeks;
  late final String planRef = plan.reference;

  SessionResolution run() {
    config.assertParametricConfiguration();
    final firstPlanDate = _firstCompletedPlanDate();
    final rawElapsedDays = firstPlanDate == null
        ? 0
        : _calendarDaysBetween(firstPlanDate, date);
    // A device clock can move backwards after a stored session. Treat that
    // clock-skew interval as no elapsed days; it is not training telemetry.
    final elapsedDays = rawElapsedDays < 0 ? 0 : rawElapsedDays;

    final absoluteWeekIndex = elapsedDays ~/ 7 + 1;
    final mesocycleWeekIndex = ((absoluteWeekIndex - 1) % mesocycleWeeks) + 1;
    final mesocycleIndex =
        plan.mesocycleIndex + (absoluteWeekIndex - 1) ~/ mesocycleWeeks;
    final weekKind = _weekKind(mesocycleWeekIndex);
    final planDay = _nextDay(absoluteWeekIndex);

    final rawDaysSinceLastSession = snapshot.lastCompletedSessionDate == null
        ? null
        : _calendarDaysBetween(snapshot.lastCompletedSessionDate!, date);
    // Same clock-skew policy as the plan age above.
    final daysSinceLastSession =
        rawDaysSinceLastSession != null && rawDaysSinceLastSession < 0
        ? 0
        : rawDaysSinceLastSession;

    final prescriptions = <ExercisePrescription>[];
    for (final planned in planDay.exercises) {
      prescriptions.add(
        _prescribe(
          planned,
          weekIndex: mesocycleWeekIndex,
          mesocycleIndex: mesocycleIndex,
          daysSinceLastSession: daysSinceLastSession ?? 0,
        ),
      );
    }

    final entries = <SessionExerciseEntry>[
      for (var index = 0; index < prescriptions.length; index++)
        SessionExerciseEntry.pending(
          planExercise: _entryPlanExercise(
            planDay.exercises[index],
            prescriptions[index],
          ),
          prescription: prescriptions[index],
        ),
    ];
    final reasonCodes = <ReasonCode>[...resolutionReasons];
    for (final prescription in prescriptions) {
      for (final reason in prescription.why) {
        if (!reasonCodes.contains(reason)) reasonCodes.add(reason);
      }
    }
    final plannedMinutes = _plannedMinutes(planDay);
    return SessionResolution(
      date: date,
      planRef: planRef,
      mesocycleIndex: mesocycleIndex,
      mesocycleWeekIndex: mesocycleWeekIndex,
      absoluteWeekIndex: absoluteWeekIndex,
      weekKind: weekKind,
      dayIndex: planDay.dayIndex,
      dayKind: planDay.kind,
      daysSinceLastSession: daysSinceLastSession,
      exercises: entries,
      budget: SessionBudgetInfo(
        plannedMinutes: plannedMinutes,
        availableMinutes: plannedMinutes,
        completedSetCount: 0,
      ),
      warnings: warnings,
      reasonCodes: reasonCodes,
      pendingPlanEditSuggestions: const <PendingPlanEditSuggestion>[],
      pendingSwapSuggestions: const <SessionSwapSuggestion>[],
      pendingExclusions: const <String>{},
      excludedExerciseIds: snapshot.excludedExerciseIds,
      events: const <SessionEvent>[],
      historySnapshot: snapshot,
      unitSystem: history.unitSystem,
      bodyMass: history.bodyMass,
      config: config,
    );
  }

  PlanExercise _entryPlanExercise(
    PlanExercise planned,
    ExercisePrescription prescription,
  ) {
    if (planned.exerciseId == prescription.exerciseId) return planned;
    for (final candidate in planned.orderedSwapCandidates) {
      if (candidate.exerciseId == prescription.exerciseId) {
        return PlanExercise(
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
          dropPriority: planned.dropPriority,
          isEmphasis: planned.isEmphasis,
          rotatesAcrossMesocycles: false,
          rotationCandidateIds: const <String>[],
          orderedSwapCandidates: planned.orderedSwapCandidates,
          baseDose: candidate.baseDose,
          repRange: candidate.repRange,
        );
      }
    }
    return planned;
  }

  int _plannedMinutes(PlanDay day) {
    if (day.hasCardioFinisher || day.exercises.length >= 7) return 60;
    if (day.exercises.length >= 5) return 45;
    return 30;
  }

  ExercisePrescription _prescribe(
    PlanExercise planned, {
    required int weekIndex,
    required int mesocycleIndex,
    required int daysSinceLastSession,
  }) {
    final selected = _selectExercise(planned);
    var dose = config.doseForWeek(selected.baseDose, weekIndex);
    final exerciseState = snapshot.exercise(selected.exerciseId);
    final range = dose is RepsDose ? dose.range : const RepRange(1, 1);
    final layoffSuppressed = layoffSuppressesProgression(
      daysSinceLastSession,
      config,
    );
    final weekLoadScale = config.weekLoadScaleFor(weekIndex);
    final easierWeek =
        config.weekSetsDeltaFor(weekIndex) < 0 ||
        config.weekRpeDeltaFor(weekIndex) < 0;

    var useWorkingAnchor = false;
    PreSuggesterAdjustment? adjustment;
    if (weekLoadScale < 1 && exerciseState.lastWorkingLoad != null) {
      useWorkingAnchor = true;
      adjustment = PreSuggesterAdjustment.fractionalDeload(
        reason: ReasonCode.deloadWeek,
        loadFraction: weekLoadScale,
      );
    } else if (!layoffSuppressed &&
        exerciseState.lastMesocycleIndex != null &&
        exerciseState.lastMesocycleIndex! < mesocycleIndex &&
        exerciseState.lastWorkingLoad != null) {
      useWorkingAnchor = true;
      adjustment = PreSuggesterAdjustment.stepUp(
        reason: ReasonCode.newMesocycleStep,
        steps: config.newMesocycleStepUp,
      );
    } else if (!layoffSuppressed &&
        exerciseState.consecutiveTooHardCount >= 2) {
      adjustment = PreSuggesterAdjustment.fractionalDeload(
        reason: ReasonCode.reactiveDeload,
        loadFraction: 1 - config.missedBottomDropFraction,
      );
    } else if (!layoffSuppressed &&
        exerciseState.sessionsSinceProgress >= _stallTriggerPriorSessions() &&
        !(selected.resistanceEquipment == ResistanceEquipment.assistedStack &&
            exerciseState.lastLoad?.isZero == true)) {
      adjustment = PreSuggesterAdjustment.fractionalDeload(
        reason: ReasonCode.stallDeload,
        loadFraction: 1 - config.stallDeloadFraction,
      );
    } else if (!layoffSuppressed && easierWeek) {
      adjustment = const PreSuggesterAdjustment.hold(ReasonCode.easierWeek);
    }

    var progressionSnapshot = exerciseState.asProgressionSnapshot(
      useWorkingAnchor: useWorkingAnchor,
    );
    if (progressionSnapshot != null &&
        adjustment != null &&
        adjustment.kind != PreSuggesterAdjustmentKind.hold) {
      progressionSnapshot = ExerciseSnapshot(
        lastLoad: progressionSnapshot.lastLoad,
        lastReps: progressionSnapshot.lastReps,
        targetReps: range.min,
        reportedEffort: progressionSnapshot.reportedEffort,
        lastHold: progressionSnapshot.lastHold,
      );
    }

    final decision = loadSuggester.suggest(
      ProgressionInput(
        profile: selected,
        range: range,
        effort: dose is RepsDose ? dose.effort : const EffortTarget(7),
        unitSystem: history.unitSystem,
        history: progressionSnapshot,
        bodyMass: history.bodyMass.isPositive ? history.bodyMass : null,
        daysSinceLastSession: weekLoadScale < 1 ? 0 : daysSinceLastSession,
        preSuggesterAdjustment: adjustment,
      ),
    );
    if (dose is RepsDose) {
      dose = dose.copyWith(targetReps: decision.targetReps);
    } else if (dose is TimedDose && decision.hold != null) {
      dose = dose.copyWith(hold: decision.hold);
    }

    final why = <ReasonCode>[...decision.why];
    if (easierWeek && !why.contains(ReasonCode.easierWeek)) {
      why.add(ReasonCode.easierWeek);
    }
    if (weekLoadScale < 1 && !why.contains(ReasonCode.deloadWeek)) {
      why.add(ReasonCode.deloadWeek);
    }
    if (selected.wasSwapped) why.add(ReasonCode.swapApplied);
    if (why.isEmpty) why.add(ReasonCode.noFeedbackHold);

    return ExercisePrescription(
      exerciseId: selected.exerciseId,
      dose: dose,
      suggestion: decision.suggestion,
      laterality: selected.laterality,
      bridge: decision.bridge,
      why: List<ReasonCode>.unmodifiable(why),
    );
  }

  _SelectedExercise _selectExercise(PlanExercise planned) {
    if (!snapshot.excludedExerciseIds.contains(planned.exerciseId)) {
      return _SelectedExercise.fromPlan(planned);
    }

    final candidates = planned.orderedSwapCandidates
        .where(
          (candidate) =>
              !snapshot.excludedExerciseIds.contains(candidate.exerciseId),
        )
        .toList(growable: false);
    candidates.sort((left, right) {
      final tier = left.tier.compareTo(right.tier);
      if (tier != 0) return tier;
      final rank = left.rank.compareTo(right.rank);
      if (rank != 0) return rank;
      return left.exerciseId.compareTo(right.exerciseId);
    });
    if (candidates.isNotEmpty) {
      final selected = candidates.first;
      warnings.add(
        EngineWarning(
          WarningCode.excludedExerciseSubstituted,
          '${planned.exerciseId}->${selected.exerciseId}',
        ),
      );
      return _SelectedExercise.fromSwap(selected);
    }

    warnings.add(
      EngineWarning(WarningCode.excludedExerciseHadNoSwap, planned.exerciseId),
    );
    return _SelectedExercise.fromPlan(planned);
  }

  PlanDay _nextDay(int absoluteWeekIndex) {
    final completed = <int>{
      for (final record in history.records)
        if (record.planRef == planRef &&
            record.absoluteWeekIndex == absoluteWeekIndex &&
            record.isCompleted)
          record.dayIndex,
    };
    for (final day in plan.days) {
      if (!completed.contains(day.dayIndex)) return day;
    }
    resolutionReasons.add(ReasonCode.planWeekCompleteRepeat);
    return plan.days.last;
  }

  DateTime? _firstCompletedPlanDate() {
    for (final record in history.records) {
      if (record.planRef == planRef && record.isCompleted) return record.date;
    }
    return null;
  }

  MesocycleWeekKind _weekKind(int weekIndex) => config.weekKind(weekIndex);

  int _stallTriggerPriorSessions() {
    final configured = config.stallSessions;
    if (configured <= 1) return 1;
    return configured - 1;
  }
}

final class _SelectedExercise implements LoadProfile {
  _SelectedExercise({
    required this.exerciseId,
    required this.movementClass,
    required this.metricType,
    required this.laterality,
    required this.resistanceEquipment,
    required this.bwContribution,
    required this.loadStepOverride,
    required this.repRange,
    required this.baseDose,
    required this.wasSwapped,
  });

  factory _SelectedExercise.fromPlan(PlanExercise exercise) =>
      _SelectedExercise(
        exerciseId: exercise.exerciseId,
        movementClass: exercise.movementClass,
        metricType: exercise.metricType,
        laterality: exercise.laterality,
        resistanceEquipment: exercise.resistanceEquipment,
        bwContribution: exercise.bwContribution,
        loadStepOverride: exercise.loadStepOverride,
        repRange: exercise.repRange,
        baseDose: exercise.baseDose,
        wasSwapped: false,
      );

  factory _SelectedExercise.fromSwap(PlanSwapCandidate exercise) =>
      _SelectedExercise(
        exerciseId: exercise.exerciseId,
        movementClass: exercise.movementClass,
        metricType: exercise.metricType,
        laterality: exercise.laterality,
        resistanceEquipment: exercise.resistanceEquipment,
        bwContribution: exercise.bwContribution,
        loadStepOverride: exercise.loadStepOverride,
        repRange: exercise.repRange,
        baseDose: exercise.baseDose,
        wasSwapped: true,
      );

  final String exerciseId;
  @override
  final MovementClass movementClass;
  @override
  final MetricType metricType;
  @override
  final Laterality laterality;
  @override
  final ResistanceEquipment resistanceEquipment;
  @override
  final double bwContribution;
  @override
  final Kg? loadStepOverride;
  final RepRange? repRange;
  final Dose baseDose;
  final bool wasSwapped;
}

int _calendarDaysBetween(DateTime earlier, DateTime later) {
  final first = DateTime.utc(earlier.year, earlier.month, earlier.day);
  final second = DateTime.utc(later.year, later.month, later.day);
  return second.difference(first).inDays;
}
