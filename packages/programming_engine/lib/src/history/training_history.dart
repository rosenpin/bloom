/// Immutable session records and the history input to session resolution.
///
/// The event list remains the source of truth. This wrapper adds only the
/// session metadata needed to order work, find the next plan day, and interpret
/// the six-week mesocycle calendar.
library;

import 'package:collection/collection.dart';

import '../config/programming_config.dart';
import '../core/events.dart';
import '../core/units.dart';

final class SessionRecord {
  SessionRecord({
    required this.sessionId,
    required this.date,
    required this.planRef,
    required this.mesocycleIndex,
    required this.mesocycleWeekIndex,
    required this.absoluteWeekIndex,
    required this.dayIndex,
    required this.weekKind,
    required Iterable<SessionEvent> events,
  }) : events = List<SessionEvent>.unmodifiable(events);

  final String sessionId;
  final DateTime date;

  /// Stable reference derived from the plan's decision stamps.
  final String planRef;

  /// The 1-based authored mesocycle and week references in force for the session.
  final int mesocycleIndex;
  final int mesocycleWeekIndex;

  /// 1-based week from the beginning of this plan journey.
  final int absoluteWeekIndex;
  final int dayIndex;
  final MesocycleWeekKind weekKind;
  final List<SessionEvent> events;

  bool get wasAbandoned => events.any((event) => event is SessionAbandoned);

  /// An empty or abandoned record does not finish a plan day.
  bool get isCompleted =>
      events.isNotEmpty &&
      !wasAbandoned &&
      events.any((event) => event is SetCompleted || event is EffortReported);

  @override
  bool operator ==(Object other) =>
      other is SessionRecord &&
      other.sessionId == sessionId &&
      other.date == date &&
      other.planRef == planRef &&
      other.mesocycleIndex == mesocycleIndex &&
      other.mesocycleWeekIndex == mesocycleWeekIndex &&
      other.absoluteWeekIndex == absoluteWeekIndex &&
      other.dayIndex == dayIndex &&
      other.weekKind == weekKind &&
      const ListEquality<SessionEvent>().equals(other.events, events);

  @override
  int get hashCode => Object.hash(
    sessionId,
    date,
    planRef,
    mesocycleIndex,
    mesocycleWeekIndex,
    absoluteWeekIndex,
    dayIndex,
    weekKind,
    Object.hashAll(events),
  );
}

/// All caller-owned inputs needed at session-resolve time. Body mass and the
/// current unit market are explicit so replay never reaches outside the package.
final class TrainingHistory {
  TrainingHistory({
    Iterable<SessionRecord> records = const <SessionRecord>[],
    Iterable<String> userExcludedExerciseIds = const <String>[],
    this.unitSystem = UnitSystem.metric,
    this.bodyMass = Kg.zero,
  }) : records = List<SessionRecord>.unmodifiable(records),
       userExcludedExerciseIds = Set<String>.unmodifiable(
         userExcludedExerciseIds,
       );

  final List<SessionRecord> records;
  final Set<String> userExcludedExerciseIds;
  final UnitSystem unitSystem;
  final Kg bodyMass;

  TrainingHistory add(SessionRecord record) => TrainingHistory(
    records: <SessionRecord>[...records, record],
    userExcludedExerciseIds: userExcludedExerciseIds,
    unitSystem: unitSystem,
    bodyMass: bodyMass,
  );

  TrainingHistory copyWith({
    Iterable<SessionRecord>? records,
    Iterable<String>? userExcludedExerciseIds,
    UnitSystem? unitSystem,
    Kg? bodyMass,
  }) => TrainingHistory(
    records: records ?? this.records,
    userExcludedExerciseIds:
        userExcludedExerciseIds ?? this.userExcludedExerciseIds,
    unitSystem: unitSystem ?? this.unitSystem,
    bodyMass: bodyMass ?? this.bodyMass,
  );
}
