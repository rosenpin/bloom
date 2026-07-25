/// Session-resolve time: plan structure meets the folded event log.
library;

import 'package:collection/collection.dart';
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
import '../history/history_fold.dart';
import '../history/training_history.dart';
import '../plan/plan.dart';
import '../progression/layoff.dart';
import '../progression/load_suggester.dart';

/// Step 5 intentionally has no active session modifiers. The type is present so
/// the public call shape stays stable when shorten/low-energy arrive in step 6.
final class SessionModifiers {
  const SessionModifiers();

  @override
  bool operator ==(Object other) => other is SessionModifiers;

  @override
  int get hashCode => (SessionModifiers).hashCode;
}

final class SessionResolution {
  SessionResolution({
    required this.date,
    required this.planRef,
    required this.mesocycleIndex,
    required this.mesocycleWeekIndex,
    required this.absoluteWeekIndex,
    required this.weekKind,
    required this.dayIndex,
    required this.dayKind,
    required this.daysSinceLastSession,
    required Iterable<ExercisePrescription> prescriptions,
    required Iterable<EngineWarning> warnings,
  }) : prescriptions = List<ExercisePrescription>.unmodifiable(prescriptions),
       warnings = List<EngineWarning>.unmodifiable(warnings);

  final DateTime date;
  final String planRef;
  final int mesocycleIndex;
  final int mesocycleWeekIndex;
  final int absoluteWeekIndex;
  final MesocycleWeekKind weekKind;
  final int dayIndex;
  final PlanDayKind? dayKind;
  final int? daysSinceLastSession;
  final List<ExercisePrescription> prescriptions;
  final List<EngineWarning> warnings;

  SessionRecord toRecord({
    required String sessionId,
    required Iterable<SessionEvent> events,
  }) => SessionRecord(
    sessionId: sessionId,
    date: date,
    planRef: planRef,
    mesocycleIndex: mesocycleIndex,
    mesocycleWeekIndex: mesocycleWeekIndex,
    absoluteWeekIndex: absoluteWeekIndex,
    dayIndex: dayIndex,
    weekKind: weekKind,
    events: events,
  );

  /// Stable semantic bytes for replay and run-twice determinism checks.
  String toCanonicalString() {
    final output = StringBuffer()
      ..writeln('date=${date.toUtc().toIso8601String()}')
      ..writeln('plan=$planRef')
      ..writeln('mesocycle=$mesocycleIndex')
      ..writeln('week=$absoluteWeekIndex/$mesocycleWeekIndex:${weekKind.name}')
      ..writeln('day=$dayIndex:${dayKind?.name ?? 'none'}')
      ..writeln('daysSince=${daysSinceLastSession ?? 'none'}');
    for (final prescription in prescriptions) {
      final dose = prescription.dose;
      output
        ..write('exercise=${prescription.exerciseId}:')
        ..write(_doseCanonical(dose))
        ..write(':${prescription.laterality.name}:')
        ..write(_suggestionCanonical(prescription.suggestion))
        ..write(':bridge=${_bridgeCanonical(prescription.bridge)}')
        ..write(':why=')
        ..writeln(prescription.why.map((reason) => reason.name).join(','));
    }
    for (final warning in warnings) {
      output.writeln('warning=${warning.code.name}:${warning.detail}');
    }
    return output.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is SessionResolution &&
      other.date == date &&
      other.planRef == planRef &&
      other.mesocycleIndex == mesocycleIndex &&
      other.mesocycleWeekIndex == mesocycleWeekIndex &&
      other.absoluteWeekIndex == absoluteWeekIndex &&
      other.weekKind == weekKind &&
      other.dayIndex == dayIndex &&
      other.dayKind == dayKind &&
      other.daysSinceLastSession == daysSinceLastSession &&
      const ListEquality<ExercisePrescription>().equals(
        other.prescriptions,
        prescriptions,
      ) &&
      const ListEquality<EngineWarning>().equals(other.warnings, warnings);

  @override
  int get hashCode => Object.hash(
    date,
    planRef,
    mesocycleIndex,
    mesocycleWeekIndex,
    absoluteWeekIndex,
    weekKind,
    dayIndex,
    dayKind,
    daysSinceLastSession,
    Object.hashAll(prescriptions),
    Object.hashAll(warnings),
  );
}

/// Total session resolver. Malformed/partial plan state degrades to a stable
/// value plus structured warnings; it never intentionally throws.
@useResult
SessionResolution resolveSession(
  Plan plan,
  TrainingHistory history,
  DateTime date, {
  SessionModifiers modifiers = const SessionModifiers(),
  ProgrammingConfig config = const ProgrammingConfig(),
}) {
  // Read the empty modifiers object so adding a field later cannot accidentally
  // leave the parameter ignored by analysis.
  final _ = modifiers;
  return _ResolutionPass(plan, history, date, config).run();
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

  late final int mesocycleWeeks = _mesocycleWeeks();
  late final String planRef = plan.reference;

  SessionResolution run() {
    final firstPlanDate = _firstCompletedPlanDate();
    var elapsedDays = firstPlanDate == null
        ? 0
        : _calendarDaysBetween(firstPlanDate, date);
    if (elapsedDays < 0) {
      warnings.add(EngineWarning(WarningCode.negativeLayoff, '$elapsedDays'));
      elapsedDays = 0;
    }

    final absoluteWeekIndex = elapsedDays ~/ 7 + 1;
    final mesocycleWeekIndex = ((absoluteWeekIndex - 1) % mesocycleWeeks) + 1;
    final mesocycleIndex =
        plan.mesocycleIndex + (absoluteWeekIndex - 1) ~/ mesocycleWeeks;
    final weekKind = _weekKind(mesocycleWeekIndex);
    final planDay = _nextDay(absoluteWeekIndex);

    var daysSinceLastSession = snapshot.lastCompletedSessionDate == null
        ? null
        : _calendarDaysBetween(snapshot.lastCompletedSessionDate!, date);
    if (daysSinceLastSession != null && daysSinceLastSession < 0) {
      warnings.add(
        EngineWarning(WarningCode.negativeLayoff, '$daysSinceLastSession'),
      );
      daysSinceLastSession = 0;
    }

    if (planDay == null) {
      warnings.add(const EngineWarning(WarningCode.noPlanDayAvailable));
      return SessionResolution(
        date: date,
        planRef: planRef,
        mesocycleIndex: mesocycleIndex,
        mesocycleWeekIndex: mesocycleWeekIndex,
        absoluteWeekIndex: absoluteWeekIndex,
        weekKind: weekKind,
        dayIndex: 0,
        dayKind: null,
        daysSinceLastSession: daysSinceLastSession,
        prescriptions: const <ExercisePrescription>[],
        warnings: warnings,
      );
    }

    final prescriptions = <ExercisePrescription>[];
    for (final planned in planDay.exercises) {
      prescriptions.add(
        _prescribe(
          planned,
          weekKind: weekKind,
          mesocycleIndex: mesocycleIndex,
          daysSinceLastSession: daysSinceLastSession ?? 0,
        ),
      );
    }

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
      prescriptions: prescriptions,
      warnings: warnings,
    );
  }

  ExercisePrescription _prescribe(
    PlanExercise planned, {
    required MesocycleWeekKind weekKind,
    required int mesocycleIndex,
    required int daysSinceLastSession,
  }) {
    final selected = _selectExercise(planned);
    var dose = _doseFor(selected, weekKind);
    final exerciseState = snapshot.exercise(selected.exerciseId);
    final range = dose is RepsDose
        ? dose.range
        : selected.repRange ?? const RepRange(8, 12);
    final layoffTier = layoffTierFor(daysSinceLastSession, config);

    var useWorkingAnchor = false;
    PreSuggesterAdjustment? adjustment;
    if (weekKind == MesocycleWeekKind.deload &&
        exerciseState.lastWorkingLoad != null) {
      useWorkingAnchor = true;
      adjustment = PreSuggesterAdjustment.fractionalDeload(
        reason: ReasonCode.deloadWeek,
        loadFraction: config.deloadWeekLoadFraction,
      );
    } else if (layoffTier == LayoffTier.none &&
        exerciseState.lastMesocycleIndex != null &&
        exerciseState.lastMesocycleIndex! < mesocycleIndex &&
        exerciseState.lastWorkingLoad != null) {
      useWorkingAnchor = true;
      adjustment = PreSuggesterAdjustment.stepUp(
        reason: ReasonCode.newMesocycleStep,
        steps: config.newMesocycleStepUp,
      );
    } else if (layoffTier == LayoffTier.none &&
        exerciseState.consecutiveTooHardCount >= 2) {
      adjustment = PreSuggesterAdjustment.fractionalDeload(
        reason: ReasonCode.reactiveDeload,
        loadFraction: 1 - config.missedBottomDropFraction,
      );
    } else if (layoffTier == LayoffTier.none &&
        exerciseState.sessionsSinceProgress >= _stallTriggerPriorSessions() &&
        !(selected.resistanceEquipment == ResistanceEquipment.assistedStack &&
            exerciseState.lastLoad?.isZero == true)) {
      adjustment = PreSuggesterAdjustment.fractionalDeload(
        reason: ReasonCode.stallDeload,
        loadFraction: 1 - config.stallDeloadFraction,
      );
    } else if (layoffTier == LayoffTier.none &&
        weekKind == MesocycleWeekKind.easier) {
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
        bodyMass: history.bodyMass,
        daysSinceLastSession: weekKind == MesocycleWeekKind.deload
            ? 0
            : daysSinceLastSession,
        preSuggesterAdjustment: adjustment,
      ),
    );
    warnings.addAll(decision.warnings);

    if (dose is RepsDose) {
      dose = dose.copyWith(targetReps: decision.targetReps);
    } else if (dose is TimedDose && decision.hold != null) {
      dose = dose.copyWith(hold: decision.hold);
    }

    final why = <ReasonCode>[...decision.why];
    if (weekKind == MesocycleWeekKind.easier &&
        !why.contains(ReasonCode.easierWeek)) {
      why.add(ReasonCode.easierWeek);
    }
    if (weekKind == MesocycleWeekKind.deload &&
        !why.contains(ReasonCode.deloadWeek)) {
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
      final relation = left.patternRelation.index.compareTo(
        right.patternRelation.index,
      );
      if (relation != 0) return relation;
      final rank = left.rank.compareTo(right.rank);
      if (rank != 0) return rank;
      final reason = left.reason.index.compareTo(right.reason.index);
      if (reason != 0) return reason;
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

  Dose _doseFor(_SelectedExercise exercise, MesocycleWeekKind weekKind) {
    final exact = exercise.doseByWeekKind[weekKind];
    if (exact != null) return exact;
    final build = exercise.doseByWeekKind[MesocycleWeekKind.build];
    if (build != null) {
      warnings.add(
        EngineWarning(
          WarningCode.missingWeekDose,
          '${exercise.exerciseId}/${weekKind.name}->build',
        ),
      );
      return build;
    }
    if (exercise.doseByWeekKind.values.isNotEmpty) {
      warnings.add(
        EngineWarning(
          WarningCode.missingWeekDose,
          '${exercise.exerciseId}/${weekKind.name}->first',
        ),
      );
      return exercise.doseByWeekKind.values.first;
    }

    warnings.add(
      EngineWarning(
        WarningCode.missingWeekDose,
        '${exercise.exerciseId}/${weekKind.name}->synthetic',
      ),
    );
    if (exercise.metricType == MetricType.timed) {
      return TimedDose(sets: 1, hold: config.timedHoldFloor);
    }
    final range = exercise.repRange ?? const RepRange(8, 12);
    return RepsDose(
      sets: 1,
      range: range,
      effort: const EffortTarget(7),
      targetReps: range.min,
    );
  }

  PlanDay? _nextDay(int absoluteWeekIndex) {
    if (plan.days.isEmpty) return null;
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
    warnings.add(
      EngineWarning(
        WarningCode.planWeekAlreadyComplete,
        'week $absoluteWeekIndex',
      ),
    );
    return plan.days.last;
  }

  DateTime? _firstCompletedPlanDate() {
    for (final record in history.records) {
      if (record.planRef == planRef && record.isCompleted) return record.date;
    }
    return null;
  }

  int _mesocycleWeeks() {
    if (config.mesocycleWeeks >= 1) return config.mesocycleWeeks;
    warnings.add(
      EngineWarning(
        WarningCode.invalidMesocycleConfiguration,
        '${config.mesocycleWeeks}->1',
      ),
    );
    return 1;
  }

  MesocycleWeekKind _weekKind(int weekIndex) {
    for (final week in plan.mesocycleCalendar) {
      if (week.weekIndex == weekIndex) return week.kind;
    }
    if (config.mesocycleWeeks < 1) return MesocycleWeekKind.build;
    return config.weekKind(weekIndex);
  }

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
    required this.doseByWeekKind,
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
        doseByWeekKind: exercise.doseByWeekKind,
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
        doseByWeekKind: exercise.doseByWeekKind,
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
  final Map<MesocycleWeekKind, Dose> doseByWeekKind;
  final bool wasSwapped;
}

int _calendarDaysBetween(DateTime earlier, DateTime later) {
  final first = DateTime.utc(earlier.year, earlier.month, earlier.day);
  final second = DateTime.utc(later.year, later.month, later.day);
  return second.difference(first).inDays;
}

String _doseCanonical(Dose dose) => switch (dose) {
  RepsDose(:final sets, :final range, :final effort, :final targetReps) =>
    '${sets}x$range@$targetReps/rpe${effort.rpe}',
  TimedDose(:final sets, :final hold) => '${sets}x${hold.inSeconds}s',
};

String _suggestionCanonical(LoadSuggestion suggestion) => switch (suggestion) {
  SuggestedLoad(:final kg) => 'load=${kg.value}',
  BodyweightOnly(:final added) => 'bodyweight+${added.value}',
  NeedsCalibration(:final floor, :final probeReps) =>
    'calibrate=${floor.value}x$probeReps',
  RepOrDurationTarget(:final reps, :final hold) =>
    hold == null ? 'reps=$reps' : 'hold=${hold.inSeconds}',
};

String _bridgeCanonical(DropBridge? bridge) => switch (bridge) {
  null => 'none',
  DropSetBridge(
    :final backOffLoad,
    :final backOffRepsMin,
    :final backOffRepsMax,
  ) =>
    'drop=${backOffLoad.value}/$backOffRepsMin-$backOffRepsMax',
  EasierVariationBridge(:final exerciseId) => 'variation=$exerciseId',
};
