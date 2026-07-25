/// Immutable state consumed and produced by the mid-session reducer.
library;

import 'package:collection/collection.dart';

import '../config/programming_config.dart';
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
import '../plan/plan_edit.dart';

enum SessionExerciseStatus { pending, active, done, swapped, removed, skipped }

enum CalibrationPhase {
  notRequired,
  awaitingProbe,
  awaitingEffort,
  settled,
  failed,
}

final class CalibrationState {
  const CalibrationState({
    required this.phase,
    required this.probeSetsCompleted,
    this.currentLoad,
    this.workingLoad,
  });

  factory CalibrationState.forPrescription(ExercisePrescription prescription) =>
      switch (prescription.suggestion) {
        NeedsCalibration(:final floor) => CalibrationState(
          phase: CalibrationPhase.awaitingProbe,
          probeSetsCompleted: 0,
          currentLoad: floor,
        ),
        _ => const CalibrationState(
          phase: CalibrationPhase.notRequired,
          probeSetsCompleted: 0,
        ),
      };

  final CalibrationPhase phase;
  final int probeSetsCompleted;
  final Kg? currentLoad;
  final Kg? workingLoad;

  bool get isCalibrating =>
      phase == CalibrationPhase.awaitingProbe ||
      phase == CalibrationPhase.awaitingEffort;

  CalibrationState copyWith({
    CalibrationPhase? phase,
    int? probeSetsCompleted,
    Kg? currentLoad,
    Kg? workingLoad,
  }) => CalibrationState(
    phase: phase ?? this.phase,
    probeSetsCompleted: probeSetsCompleted ?? this.probeSetsCompleted,
    currentLoad: currentLoad ?? this.currentLoad,
    workingLoad: workingLoad ?? this.workingLoad,
  );

  @override
  bool operator ==(Object other) =>
      other is CalibrationState &&
      other.phase == phase &&
      other.probeSetsCompleted == probeSetsCompleted &&
      other.currentLoad == currentLoad &&
      other.workingLoad == workingLoad;

  @override
  int get hashCode =>
      Object.hash(phase, probeSetsCompleted, currentLoad, workingLoad);
}

final class SessionExerciseEntry {
  SessionExerciseEntry({
    required this.originalExerciseId,
    required this.planExercise,
    required this.prescription,
    required Iterable<SetCompleted> setLogs,
    required this.feelReport,
    required this.calibration,
    required this.status,
  }) : setLogs = List<SetCompleted>.unmodifiable(setLogs);

  factory SessionExerciseEntry.pending({
    required PlanExercise planExercise,
    required ExercisePrescription prescription,
  }) => SessionExerciseEntry(
    originalExerciseId: planExercise.exerciseId,
    planExercise: planExercise,
    prescription: prescription,
    setLogs: const <SetCompleted>[],
    feelReport: null,
    calibration: CalibrationState.forPrescription(prescription),
    status: SessionExerciseStatus.pending,
  );

  /// The slot's source before any temporary swap.
  final String originalExerciseId;
  final PlanExercise planExercise;
  final ExercisePrescription prescription;
  final List<SetCompleted> setLogs;
  List<SetCompleted> get perSetLogs => setLogs;
  final EffortLevel? feelReport;
  final CalibrationState calibration;
  CalibrationState get calibrationState => calibration;
  final SessionExerciseStatus status;

  String get exerciseId => prescription.exerciseId;
  int get setsCompleted => setLogs.length;
  bool get isTerminal =>
      status == SessionExerciseStatus.done ||
      status == SessionExerciseStatus.removed ||
      status == SessionExerciseStatus.skipped;
  bool get isUnstarted => setLogs.isEmpty && feelReport == null;

  SessionExerciseEntry copyWith({
    String? originalExerciseId,
    PlanExercise? planExercise,
    ExercisePrescription? prescription,
    Iterable<SetCompleted>? setLogs,
    EffortLevel? feelReport,
    bool clearFeelReport = false,
    CalibrationState? calibration,
    SessionExerciseStatus? status,
  }) => SessionExerciseEntry(
    originalExerciseId: originalExerciseId ?? this.originalExerciseId,
    planExercise: planExercise ?? this.planExercise,
    prescription: prescription ?? this.prescription,
    setLogs: setLogs ?? this.setLogs,
    feelReport: clearFeelReport ? null : feelReport ?? this.feelReport,
    calibration: calibration ?? this.calibration,
    status: status ?? this.status,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionExerciseEntry &&
      other.originalExerciseId == originalExerciseId &&
      other.planExercise == planExercise &&
      other.prescription == prescription &&
      const ListEquality<SetCompleted>().equals(other.setLogs, setLogs) &&
      other.feelReport == feelReport &&
      other.calibration == calibration &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
    originalExerciseId,
    planExercise,
    prescription,
    Object.hashAll(setLogs),
    feelReport,
    calibration,
    status,
  );
}

final class SessionBudgetInfo {
  const SessionBudgetInfo({
    required this.plannedMinutes,
    required this.availableMinutes,
    required this.completedSetCount,
    this.elapsedMinutes = 0,
  });

  final int plannedMinutes;
  final int availableMinutes;

  /// Events contain no timestamps, so elapsed wall time cannot be invented.
  /// Completed sets are the deterministic progress signal alongside the budget.
  final int completedSetCount;
  final int elapsedMinutes;

  bool get isShortened => availableMinutes < plannedMinutes;

  SessionBudgetInfo copyWith({
    int? plannedMinutes,
    int? availableMinutes,
    int? completedSetCount,
    int? elapsedMinutes,
  }) => SessionBudgetInfo(
    plannedMinutes: plannedMinutes ?? this.plannedMinutes,
    availableMinutes: availableMinutes ?? this.availableMinutes,
    completedSetCount: completedSetCount ?? this.completedSetCount,
    elapsedMinutes: elapsedMinutes ?? this.elapsedMinutes,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionBudgetInfo &&
      other.plannedMinutes == plannedMinutes &&
      other.availableMinutes == availableMinutes &&
      other.completedSetCount == completedSetCount &&
      other.elapsedMinutes == elapsedMinutes;

  @override
  int get hashCode => Object.hash(
    plannedMinutes,
    availableMinutes,
    completedSetCount,
    elapsedMinutes,
  );
}

enum SwapSuggestionCause { calibrationFloor, pain }

sealed class PendingPlanEditSuggestion {
  const PendingPlanEditSuggestion();

  String get sourceExerciseId;
  String get replacementId;
  int get tier;
}

/// Asked at session end after a swap was actually used.
final class KeepSwapPlanEditSuggestion extends PendingPlanEditSuggestion {
  const KeepSwapPlanEditSuggestion({
    required this.edit,
    required this.tier,
    required this.reason,
  });

  final KeepSwap edit;
  @override
  String get sourceExerciseId => edit.exerciseId;
  @override
  String get replacementId => edit.replacementId;
  @override
  final int tier;
  final SwapReason reason;

  @override
  bool operator ==(Object other) =>
      other is KeepSwapPlanEditSuggestion &&
      other.edit.canonicalId == edit.canonicalId &&
      other.tier == tier &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(edit.canonicalId, tier, reason);
}

/// A safe tier-1/2 alternative offered after a pain or calibration stop.
///
/// This is not a plan edit yet: only an accepted/used swap becomes a keep-swap
/// suggestion at session end.
final class SessionSwapSuggestion {
  const SessionSwapSuggestion({
    required this.sourceExerciseId,
    required this.candidate,
    required this.reason,
    required this.cause,
  });

  final String sourceExerciseId;
  final PlanSwapCandidate candidate;
  String get replacementId => candidate.exerciseId;
  int get tier => candidate.tier;
  final SwapReason reason;
  final SwapSuggestionCause cause;

  @override
  bool operator ==(Object other) =>
      other is SessionSwapSuggestion &&
      other.sourceExerciseId == sourceExerciseId &&
      other.candidate == candidate &&
      other.reason == reason &&
      other.cause == cause;

  @override
  int get hashCode => Object.hash(sourceExerciseId, candidate, reason, cause);
}

final class SessionState {
  SessionState({
    required this.date,
    required this.planRef,
    required this.mesocycleIndex,
    required this.mesocycleWeekIndex,
    required this.absoluteWeekIndex,
    required this.weekKind,
    required this.dayIndex,
    required this.dayKind,
    required this.daysSinceLastSession,
    required Iterable<SessionExerciseEntry> exercises,
    required this.budget,
    required Iterable<EngineWarning> warnings,
    required Iterable<ReasonCode> reasonCodes,
    required Iterable<PendingPlanEditSuggestion> pendingPlanEditSuggestions,
    required Iterable<SessionSwapSuggestion> pendingSwapSuggestions,
    required Iterable<String> pendingExclusions,
    required Iterable<String> excludedExerciseIds,
    required Iterable<SessionEvent> events,
    required this.historySnapshot,
    required this.unitSystem,
    required this.bodyMass,
    required this.config,
    this.lastShortenMinutes,
    this.lowEnergyWasApplied = false,
    this.isAbandoned = false,
  }) : exercises = List<SessionExerciseEntry>.unmodifiable(exercises),
       warnings = List<EngineWarning>.unmodifiable(warnings),
       reasonCodes = List<ReasonCode>.unmodifiable(reasonCodes),
       pendingPlanEditSuggestions =
           List<PendingPlanEditSuggestion>.unmodifiable(
             pendingPlanEditSuggestions,
           ),
       pendingSwapSuggestions = List<SessionSwapSuggestion>.unmodifiable(
         pendingSwapSuggestions,
       ),
       pendingExclusions = Set<String>.unmodifiable(pendingExclusions),
       excludedExerciseIds = Set<String>.unmodifiable(excludedExerciseIds),
       events = List<SessionEvent>.unmodifiable(events);

  final DateTime date;
  final String planRef;
  final int mesocycleIndex;
  final int mesocycleWeekIndex;
  final int absoluteWeekIndex;
  final MesocycleWeekKind weekKind;
  final int dayIndex;
  final PlanDayKind? dayKind;
  final int? daysSinceLastSession;

  final List<SessionExerciseEntry> exercises;
  List<SessionExerciseEntry> get entries => exercises;
  List<SessionExerciseEntry> get orderedExerciseEntries => exercises;
  List<ExercisePrescription> get prescriptions =>
      List<ExercisePrescription>.unmodifiable(
        exercises.map((entry) => entry.prescription),
      );
  final SessionBudgetInfo budget;
  SessionBudgetInfo get elapsedBudgetInfo => budget;
  final List<EngineWarning> warnings;
  final List<ReasonCode> reasonCodes;
  List<ReasonCode> get accumulatedReasonCodes => reasonCodes;
  final List<PendingPlanEditSuggestion> pendingPlanEditSuggestions;
  final List<SessionSwapSuggestion> pendingSwapSuggestions;

  /// Session-local pain exclusions awaiting persistence. Every id here is
  /// written by the app with `source=pain`; user-authored exclusions arrive
  /// separately through [excludedExerciseIds].
  final Set<String> pendingExclusions;
  final Set<String> excludedExerciseIds;
  final List<SessionEvent> events;

  /// Immutable injected context used to resolve a swap target from its own
  /// history without consulting I/O or mutable content.
  final TrainingSnapshot historySnapshot;
  final UnitSystem unitSystem;
  final Kg bodyMass;
  final ProgrammingConfig config;

  final int? lastShortenMinutes;
  final bool lowEnergyWasApplied;
  final bool isAbandoned;

  SessionState copyWith({
    Iterable<SessionExerciseEntry>? exercises,
    SessionBudgetInfo? budget,
    Iterable<EngineWarning>? warnings,
    Iterable<ReasonCode>? reasonCodes,
    Iterable<PendingPlanEditSuggestion>? pendingPlanEditSuggestions,
    Iterable<SessionSwapSuggestion>? pendingSwapSuggestions,
    Iterable<String>? pendingExclusions,
    Iterable<String>? excludedExerciseIds,
    Iterable<SessionEvent>? events,
    int? lastShortenMinutes,
    bool clearLastShortenMinutes = false,
    bool? lowEnergyWasApplied,
    bool? isAbandoned,
  }) => SessionState(
    date: date,
    planRef: planRef,
    mesocycleIndex: mesocycleIndex,
    mesocycleWeekIndex: mesocycleWeekIndex,
    absoluteWeekIndex: absoluteWeekIndex,
    weekKind: weekKind,
    dayIndex: dayIndex,
    dayKind: dayKind,
    daysSinceLastSession: daysSinceLastSession,
    exercises: exercises ?? this.exercises,
    budget: budget ?? this.budget,
    warnings: warnings ?? this.warnings,
    reasonCodes: reasonCodes ?? this.reasonCodes,
    pendingPlanEditSuggestions:
        pendingPlanEditSuggestions ?? this.pendingPlanEditSuggestions,
    pendingSwapSuggestions:
        pendingSwapSuggestions ?? this.pendingSwapSuggestions,
    pendingExclusions: pendingExclusions ?? this.pendingExclusions,
    excludedExerciseIds: excludedExerciseIds ?? this.excludedExerciseIds,
    events: events ?? this.events,
    historySnapshot: historySnapshot,
    unitSystem: unitSystem,
    bodyMass: bodyMass,
    config: config,
    lastShortenMinutes: clearLastShortenMinutes
        ? null
        : lastShortenMinutes ?? this.lastShortenMinutes,
    lowEnergyWasApplied: lowEnergyWasApplied ?? this.lowEnergyWasApplied,
    isAbandoned: isAbandoned ?? this.isAbandoned,
  );

  SessionRecord toRecord({
    required String sessionId,
    Iterable<SessionEvent>? events,
  }) => SessionRecord(
    sessionId: sessionId,
    date: date,
    planRef: planRef,
    mesocycleIndex: mesocycleIndex,
    mesocycleWeekIndex: mesocycleWeekIndex,
    absoluteWeekIndex: absoluteWeekIndex,
    dayIndex: dayIndex,
    weekKind: weekKind,
    events: events ?? this.events,
  );

  /// Stable semantic projection for reducer goldens and replay determinism.
  String toCanonicalString() {
    final output = StringBuffer()
      ..writeln('date=${date.toUtc().toIso8601String()}')
      ..writeln('plan=$planRef')
      ..writeln('mesocycle=$mesocycleIndex')
      ..writeln('week=$absoluteWeekIndex/$mesocycleWeekIndex:${weekKind.name}')
      ..writeln('day=$dayIndex:${dayKind?.name ?? 'none'}')
      ..writeln('daysSince=${daysSinceLastSession ?? 'none'}')
      ..writeln(
        'budget=${budget.plannedMinutes}/${budget.availableMinutes}'
        ':elapsed=${budget.elapsedMinutes}:sets=${budget.completedSetCount}',
      );
    for (final entry in exercises) {
      final prescription = entry.prescription;
      output
        ..write('exercise=${prescription.exerciseId}:')
        ..write(_doseCanonical(prescription.dose))
        ..write(':${prescription.laterality.name}:')
        ..write(_suggestionCanonical(prescription.suggestion))
        ..write(':status=${entry.status.name}')
        ..write(':cal=${entry.calibration.phase.name}/')
        ..write('${entry.calibration.probeSetsCompleted}')
        ..write(':sets=')
        ..write(
          entry.setLogs
              .map((set) => '${set.setIndex}@${set.load.value}x${set.reps}')
              .join(','),
        )
        ..write(':feel=${entry.feelReport?.name ?? 'none'}')
        ..write(':why=')
        ..writeln(prescription.why.map((reason) => reason.name).join(','));
    }
    output.writeln(
      'reasons=${reasonCodes.map((reason) => reason.name).join(',')}',
    );
    output.writeln('pendingExclusions=${pendingExclusions.join(',')}');
    for (final suggestion in pendingPlanEditSuggestions) {
      output.writeln(
        'editSuggestion=${suggestion.sourceExerciseId}->'
        '${suggestion.replacementId}:tier${suggestion.tier}',
      );
    }
    for (final suggestion in pendingSwapSuggestions) {
      output.writeln(
        'swapSuggestion=${suggestion.sourceExerciseId}->'
        '${suggestion.replacementId}:tier${suggestion.tier}:'
        '${suggestion.cause.name}',
      );
    }
    for (final warning in warnings) {
      output.writeln('warning=${warning.code.name}:${warning.detail}');
    }
    output.writeln('abandoned=$isAbandoned');
    return output.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is SessionState &&
      other.date == date &&
      other.planRef == planRef &&
      other.mesocycleIndex == mesocycleIndex &&
      other.mesocycleWeekIndex == mesocycleWeekIndex &&
      other.absoluteWeekIndex == absoluteWeekIndex &&
      other.weekKind == weekKind &&
      other.dayIndex == dayIndex &&
      other.dayKind == dayKind &&
      other.daysSinceLastSession == daysSinceLastSession &&
      const ListEquality<SessionExerciseEntry>().equals(
        other.exercises,
        exercises,
      ) &&
      other.budget == budget &&
      const ListEquality<EngineWarning>().equals(other.warnings, warnings) &&
      const ListEquality<ReasonCode>().equals(other.reasonCodes, reasonCodes) &&
      const ListEquality<PendingPlanEditSuggestion>().equals(
        other.pendingPlanEditSuggestions,
        pendingPlanEditSuggestions,
      ) &&
      const ListEquality<SessionSwapSuggestion>().equals(
        other.pendingSwapSuggestions,
        pendingSwapSuggestions,
      ) &&
      const SetEquality<String>().equals(
        other.pendingExclusions,
        pendingExclusions,
      ) &&
      const SetEquality<String>().equals(
        other.excludedExerciseIds,
        excludedExerciseIds,
      ) &&
      const ListEquality<SessionEvent>().equals(other.events, events) &&
      other.historySnapshot == historySnapshot &&
      other.unitSystem == unitSystem &&
      other.bodyMass == bodyMass &&
      other.lastShortenMinutes == lastShortenMinutes &&
      other.lowEnergyWasApplied == lowEnergyWasApplied &&
      other.isAbandoned == isAbandoned;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    date,
    planRef,
    mesocycleIndex,
    mesocycleWeekIndex,
    absoluteWeekIndex,
    weekKind,
    dayIndex,
    dayKind,
    daysSinceLastSession,
    Object.hashAll(exercises),
    budget,
    Object.hashAll(warnings),
    Object.hashAll(reasonCodes),
    Object.hashAll(pendingPlanEditSuggestions),
    Object.hashAll(pendingSwapSuggestions),
    const SetEquality<String>().hash(pendingExclusions),
    const SetEquality<String>().hash(excludedExerciseIds),
    Object.hashAll(events),
    historySnapshot,
    unitSystem,
    bodyMass,
    lastShortenMinutes,
    lowEnergyWasApplied,
    isAbandoned,
  ]);
}

/// Compatibility name retained for step-5 callers.
typedef SessionResolution = SessionState;

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
