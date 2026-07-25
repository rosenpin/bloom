/// Immutable, fully content-resolved plan documents.
library;

import 'package:collection/collection.dart';

import '../config/programming_config.dart';
import '../content/exercise.dart';
import '../core/dose.dart';
import '../core/effort.dart';
import '../core/events.dart';
import '../core/prescription.dart';
import '../core/units.dart';
import '../core/warnings.dart';

enum PlanDayKind { fullBodyA, fullBodyB, lower, upper, lowerGluteLed }

final class PlanStamps {
  const PlanStamps({
    required this.engineVersion,
    required this.configHash,
    required this.contentHash,
    required this.profileHash,
  });

  final String engineVersion;
  final String configHash;
  final String contentHash;
  final String profileHash;

  @override
  bool operator ==(Object other) =>
      other is PlanStamps &&
      other.engineVersion == engineVersion &&
      other.configHash == configHash &&
      other.contentHash == contentHash &&
      other.profileHash == profileHash;

  @override
  int get hashCode =>
      Object.hash(engineVersion, configHash, contentHash, profileHash);
}

final class PlanWeek {
  const PlanWeek({required this.weekIndex, required this.kind})
    : assert(weekIndex >= 1);

  final int weekIndex;
  final MesocycleWeekKind kind;

  @override
  bool operator ==(Object other) =>
      other is PlanWeek && other.weekIndex == weekIndex && other.kind == kind;

  @override
  int get hashCode => Object.hash(weekIndex, kind);
}

final class PlanSwapCandidate implements LoadProfile {
  const PlanSwapCandidate({
    required this.exerciseId,
    required this.name,
    required this.blockRole,
    required this.movementClass,
    required this.metricType,
    required this.laterality,
    required this.difficultyTier,
    required this.resistanceEquipment,
    required this.supportEquipment,
    required this.bwContribution,
    required this.loadStepOverride,
    required this.reason,
    required this.rank,
  });

  final String exerciseId;
  final String name;
  final BlockRole blockRole;
  @override
  final MovementClass movementClass;
  @override
  final MetricType metricType;
  @override
  final Laterality laterality;
  final DifficultyTier difficultyTier;
  @override
  final ResistanceEquipment resistanceEquipment;
  final SupportEquipment supportEquipment;
  @override
  final double bwContribution;
  @override
  final Kg? loadStepOverride;
  final SwapReason reason;
  final int rank;

  @override
  bool operator ==(Object other) =>
      other is PlanSwapCandidate &&
      other.exerciseId == exerciseId &&
      other.name == name &&
      other.blockRole == blockRole &&
      other.movementClass == movementClass &&
      other.metricType == metricType &&
      other.laterality == laterality &&
      other.difficultyTier == difficultyTier &&
      other.resistanceEquipment == resistanceEquipment &&
      other.supportEquipment == supportEquipment &&
      other.bwContribution == bwContribution &&
      other.loadStepOverride == loadStepOverride &&
      other.reason == reason &&
      other.rank == rank;

  @override
  int get hashCode => Object.hash(
    exerciseId,
    name,
    blockRole,
    movementClass,
    metricType,
    laterality,
    difficultyTier,
    resistanceEquipment,
    supportEquipment,
    bwContribution,
    loadStepOverride,
    reason,
    rank,
  );
}

/// The content snapshot held by a plan so later phases remain offline and do
/// not observe content-table edits.
final class PlanExercise implements LoadProfile {
  PlanExercise({
    required this.exerciseId,
    required this.name,
    required this.blockRole,
    required this.movementClass,
    required this.metricType,
    required this.laterality,
    required this.difficultyTier,
    required this.resistanceEquipment,
    required this.supportEquipment,
    required this.bwContribution,
    required this.loadStepOverride,
    required this.dropPriority,
    required this.isEmphasis,
    required this.rotatesAcrossMesocycles,
    required Iterable<String> rotationCandidateIds,
    required Iterable<PlanSwapCandidate> orderedSwapCandidates,
    required Map<MesocycleWeekKind, Dose> doseByWeekKind,
    required this.repRange,
  }) : rotationCandidateIds = List<String>.unmodifiable(rotationCandidateIds),
       orderedSwapCandidates = List<PlanSwapCandidate>.unmodifiable(
         orderedSwapCandidates,
       ),
       doseByWeekKind = Map<MesocycleWeekKind, Dose>.unmodifiable(
         doseByWeekKind,
       );

  final String exerciseId;
  final String name;
  final BlockRole blockRole;
  @override
  final MovementClass movementClass;
  @override
  final MetricType metricType;
  @override
  final Laterality laterality;
  final DifficultyTier difficultyTier;
  @override
  final ResistanceEquipment resistanceEquipment;
  final SupportEquipment supportEquipment;
  @override
  final double bwContribution;
  @override
  final Kg? loadStepOverride;

  /// `0` is never dropped by shortening; larger values are dropped first.
  final int dropPriority;
  final bool isEmphasis;
  final bool rotatesAcrossMesocycles;
  final List<String> rotationCandidateIds;
  final List<PlanSwapCandidate> orderedSwapCandidates;

  /// Null only for timed work.
  final RepRange? repRange;

  /// Includes build, easier, push and deload values; no session-time weight.
  final Map<MesocycleWeekKind, Dose> doseByWeekKind;

  Dose doseFor(MesocycleWeekKind kind) => doseByWeekKind[kind]!;

  EffortTarget? effortFor(MesocycleWeekKind kind) {
    final dose = doseFor(kind);
    return dose is RepsDose ? dose.effort : null;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanExercise &&
      other.exerciseId == exerciseId &&
      other.name == name &&
      other.blockRole == blockRole &&
      other.movementClass == movementClass &&
      other.metricType == metricType &&
      other.laterality == laterality &&
      other.difficultyTier == difficultyTier &&
      other.resistanceEquipment == resistanceEquipment &&
      other.supportEquipment == supportEquipment &&
      other.bwContribution == bwContribution &&
      other.loadStepOverride == loadStepOverride &&
      other.dropPriority == dropPriority &&
      other.isEmphasis == isEmphasis &&
      other.rotatesAcrossMesocycles == rotatesAcrossMesocycles &&
      const ListEquality<String>().equals(
        other.rotationCandidateIds,
        rotationCandidateIds,
      ) &&
      const ListEquality<PlanSwapCandidate>().equals(
        other.orderedSwapCandidates,
        orderedSwapCandidates,
      ) &&
      const MapEquality<MesocycleWeekKind, Dose>().equals(
        other.doseByWeekKind,
        doseByWeekKind,
      ) &&
      other.repRange == repRange;

  @override
  int get hashCode => Object.hash(
    exerciseId,
    name,
    blockRole,
    movementClass,
    metricType,
    laterality,
    difficultyTier,
    resistanceEquipment,
    supportEquipment,
    bwContribution,
    loadStepOverride,
    dropPriority,
    isEmphasis,
    rotatesAcrossMesocycles,
    Object.hashAll(rotationCandidateIds),
    Object.hashAll(orderedSwapCandidates),
    Object.hashAll(
      MesocycleWeekKind.values.map(
        (kind) => Object.hash(kind, doseByWeekKind[kind]),
      ),
    ),
    repRange,
  );
}

final class PlanDay {
  PlanDay({
    required this.dayIndex,
    required this.kind,
    required this.warmUpMinutes,
    required this.hasCardioFinisher,
    required Iterable<PlanExercise> exercises,
  }) : assert(dayIndex >= 1),
       exercises = List<PlanExercise>.unmodifiable(exercises);

  final int dayIndex;
  final PlanDayKind kind;
  final int warmUpMinutes;

  /// Sixty-minute sessions finish with generic bike or incline-walk work. It is
  /// not a 40th catalog exercise.
  final bool hasCardioFinisher;
  final List<PlanExercise> exercises;

  @override
  bool operator ==(Object other) =>
      other is PlanDay &&
      other.dayIndex == dayIndex &&
      other.kind == kind &&
      other.warmUpMinutes == warmUpMinutes &&
      other.hasCardioFinisher == hasCardioFinisher &&
      const ListEquality<PlanExercise>().equals(other.exercises, exercises);

  @override
  int get hashCode => Object.hash(
    dayIndex,
    kind,
    warmUpMinutes,
    hasCardioFinisher,
    Object.hashAll(exercises),
  );
}

final class Plan {
  Plan({
    required this.mesocycleIndex,
    required this.stamps,
    required Iterable<PlanWeek> mesocycleCalendar,
    required Iterable<PlanDay> days,
    required Iterable<EngineWarning> warnings,
  }) : assert(mesocycleIndex >= 1),
       mesocycleCalendar = List<PlanWeek>.unmodifiable(mesocycleCalendar),
       days = List<PlanDay>.unmodifiable(days),
       warnings = List<EngineWarning>.unmodifiable(warnings);

  final int mesocycleIndex;
  final PlanStamps stamps;
  final List<PlanWeek> mesocycleCalendar;
  final List<PlanDay> days;
  final List<EngineWarning> warnings;

  /// Stable semantic bytes for persistence checks and determinism tests.
  String toCanonicalString() {
    final output = StringBuffer()
      ..writeln('engine=${stamps.engineVersion}')
      ..writeln('config=${stamps.configHash}')
      ..writeln('content=${stamps.contentHash}')
      ..writeln('profile=${stamps.profileHash}')
      ..writeln('mesocycle=$mesocycleIndex')
      ..writeln(
        'calendar=${mesocycleCalendar.map((week) => '${week.weekIndex}:${week.kind.name}').join(',')}',
      );
    for (final day in days) {
      output.writeln(
        'day=${day.dayIndex}:${day.kind.name}:warmup=${day.warmUpMinutes}:'
        'finisher=${day.hasCardioFinisher}',
      );
      for (final exercise in day.exercises) {
        output
          ..write(
            'exercise=${exercise.exerciseId}:${exercise.blockRole.name}:'
            '${exercise.movementClass.name}:${exercise.metricType.name}:'
            '${exercise.laterality.name}:${exercise.difficultyTier.name}:'
            '${exercise.resistanceEquipment.name}:'
            '${exercise.supportEquipment.name}:${exercise.bwContribution}:'
            '${exercise.loadStepOverride?.value ?? 'null'}:'
            '${exercise.dropPriority}:${exercise.isEmphasis}:'
            '${exercise.rotatesAcrossMesocycles}:',
          )
          ..write(exercise.rotationCandidateIds.join(','))
          ..write(':swaps=')
          ..write(
            exercise.orderedSwapCandidates
                .map(
                  (candidate) =>
                      '${candidate.reason.name}.${candidate.rank}.'
                      '${candidate.exerciseId}.${candidate.blockRole.name}.'
                      '${candidate.movementClass.name}.${candidate.metricType.name}.'
                      '${candidate.laterality.name}.${candidate.difficultyTier.name}.'
                      '${candidate.resistanceEquipment.name}.'
                      '${candidate.supportEquipment.name}.'
                      '${candidate.bwContribution}.'
                      '${candidate.loadStepOverride?.value ?? 'null'}',
                )
                .join(','),
          );
        for (final kind in MesocycleWeekKind.values) {
          output.write(':${kind.name}=${_doseText(exercise.doseFor(kind))}');
        }
        output.writeln();
      }
    }
    for (final warning in warnings) {
      output.writeln('warning=${warning.code.name}:${warning.detail}');
    }
    return output.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is Plan &&
      other.mesocycleIndex == mesocycleIndex &&
      other.stamps == stamps &&
      const ListEquality<PlanWeek>().equals(
        other.mesocycleCalendar,
        mesocycleCalendar,
      ) &&
      const ListEquality<PlanDay>().equals(other.days, days) &&
      const ListEquality<EngineWarning>().equals(other.warnings, warnings);

  @override
  int get hashCode => Object.hash(
    mesocycleIndex,
    stamps,
    Object.hashAll(mesocycleCalendar),
    Object.hashAll(days),
    Object.hashAll(warnings),
  );
}

String _doseText(Dose dose) => switch (dose) {
  RepsDose(:final sets, :final range, :final effort, :final targetReps) =>
    '${sets}x$range@$targetReps/rpe${effort.rpe}',
  TimedDose(:final sets, :final hold) => '${sets}x${hold.inSeconds}s',
};
