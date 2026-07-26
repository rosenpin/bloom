import 'package:programming_engine/programming_engine.dart';

import 'review_form_state.dart';

enum JourneyPattern { honestNovice, alwaysJustRight, struggling }

final class JourneyPoint {
  const JourneyPoint({
    required this.session,
    required this.absoluteWeek,
    required this.exerciseId,
    required this.exerciseName,
    required this.load,
    required this.hasExternalLoad,
  });

  final int session;
  final int absoluteWeek;
  final String exerciseId;
  final String exerciseName;
  final Kg load;
  final bool hasExternalLoad;
}

final class JourneyResult {
  JourneyResult({
    required Iterable<JourneyPoint> points,
    required this.sessionCount,
  }) : points = List<JourneyPoint>.unmodifiable(points);

  final List<JourneyPoint> points;
  final int sessionCount;

  Map<String, List<JourneyPoint>> get series {
    final result = <String, List<JourneyPoint>>{};
    for (final point in points) {
      result.putIfAbsent(point.exerciseId, () => <JourneyPoint>[]).add(point);
    }
    return result;
  }
}

JourneyResult simulateJourney({
  required Plan plan,
  required ReviewFormState form,
  required int weeks,
  required JourneyPattern pattern,
  ProgrammingConfig config = const ProgrammingConfig(),
}) {
  final dates = _sessionDates(
    weeks: weeks,
    daysPerWeek: form.daysPerWeek.value,
  );
  var history = form.toHistory();
  final points = <JourneyPoint>[];
  final exposureByExercise = <String, int>{};

  for (var index = 0; index < dates.length; index++) {
    final sessionNumber = index + 1;
    final resolution = resolveSession(
      plan,
      history,
      dates[index],
      config: config,
    );
    final events = <SessionEvent>[];
    for (final prescription in resolution.prescriptions) {
      final exposure = (exposureByExercise[prescription.exerciseId] ?? 0) + 1;
      exposureByExercise[prescription.exerciseId] = exposure;
      final entry = resolution.exercises.firstWhere(
        (item) => item.exerciseId == prescription.exerciseId,
      );
      final load = _loadOf(prescription.suggestion);
      final targetReps = _targetReps(prescription);
      final targetRpe = switch (prescription.dose) {
        RepsDose(:final effort) => effort.rpe,
        TimedDose() => null,
      };
      points.add(
        JourneyPoint(
          session: sessionNumber,
          absoluteWeek: resolution.absoluteWeekIndex,
          exerciseId: prescription.exerciseId,
          exerciseName: entry.planExercise.name,
          load: load,
          hasExternalLoad: entry.planExercise.metricType.hasLoad,
        ),
      );
      events
        ..add(
          SetCompleted(
            exerciseId: prescription.exerciseId,
            setIndex: 0,
            load: load,
            reps: targetReps,
            unitSystem: form.unitSystem,
            targetReps: targetReps,
            targetRpe: targetRpe,
            prescribedLoad: load,
          ),
        )
        ..add(
          EffortReported(
            exerciseId: prescription.exerciseId,
            level: _effortFor(pattern, exposure),
          ),
        );
    }
    history = history.add(
      resolution.toRecord(sessionId: 'review-$sessionNumber', events: events),
    );
  }
  return JourneyResult(points: points, sessionCount: dates.length);
}

EffortLevel _effortFor(JourneyPattern pattern, int exposure) =>
    switch (pattern) {
      JourneyPattern.honestNovice when exposure <= 2 => EffortLevel.wayTooEasy,
      JourneyPattern.honestNovice when exposure <= 4 => EffortLevel.aBitEasy,
      JourneyPattern.honestNovice => EffortLevel.justRight,
      JourneyPattern.alwaysJustRight => EffortLevel.justRight,
      JourneyPattern.struggling when exposure % 3 == 0 =>
        EffortLevel.harderThanIdLike,
      JourneyPattern.struggling => EffortLevel.justRight,
    };

List<DateTime> _sessionDates({required int weeks, required int daysPerWeek}) {
  final start = DateTime.utc(2026, 1, 5);
  final dayOffsets = switch (daysPerWeek) {
    2 => const <int>[0, 3],
    3 => const <int>[0, 2, 4],
    4 => const <int>[0, 1, 3, 5],
    _ => throw ArgumentError.value(daysPerWeek, 'daysPerWeek'),
  };
  return <DateTime>[
    for (var week = 0; week < weeks; week++)
      for (final offset in dayOffsets)
        start.add(Duration(days: week * 7 + offset)),
  ];
}

Kg _loadOf(LoadSuggestion suggestion) => switch (suggestion) {
  SuggestedLoad(:final kg) => kg,
  BodyweightOnly(:final added) => added,
  NeedsCalibration(:final floor) => floor,
  RepOrDurationTarget() => Kg.zero,
};

int _targetReps(ExercisePrescription prescription) =>
    switch (prescription.dose) {
      RepsDose(:final targetReps) => targetReps,
      TimedDose() => 1,
    };
