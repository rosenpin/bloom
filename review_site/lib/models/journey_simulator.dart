import 'package:programming_engine/programming_engine.dart';

import 'review_form_state.dart';

enum JourneyPattern { honestNovice, alwaysJustRight, struggling }

enum JourneyTargetKind { reps, hold }

final class JourneySession {
  const JourneySession({
    required this.session,
    required this.absoluteWeek,
    required this.weekKind,
  });

  final int session;
  final int absoluteWeek;
  final MesocycleWeekKind weekKind;
}

final class JourneyPoint {
  const JourneyPoint({
    required this.session,
    required this.absoluteWeek,
    required this.weekKind,
    required this.exerciseId,
    required this.exerciseName,
    required this.load,
    required this.hasExternalLoad,
    required this.target,
    required this.targetKind,
  });

  final int session;
  final int absoluteWeek;
  final MesocycleWeekKind weekKind;
  final String exerciseId;
  final String exerciseName;
  final Kg load;
  final bool hasExternalLoad;
  final int target;
  final JourneyTargetKind targetKind;
}

final class JourneyResult {
  JourneyResult({
    required Iterable<JourneyPoint> points,
    required Iterable<JourneySession> sessions,
  }) : points = List<JourneyPoint>.unmodifiable(points),
       sessions = List<JourneySession>.unmodifiable(sessions);

  final List<JourneyPoint> points;
  final List<JourneySession> sessions;

  int get sessionCount => sessions.length;

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
  final sessions = <JourneySession>[];
  final exposureByExercise = <String, int>{};

  for (var index = 0; index < dates.length; index++) {
    final sessionNumber = index + 1;
    final resolution = resolveSession(
      plan,
      history,
      dates[index],
      config: config,
    );
    sessions.add(
      JourneySession(
        session: sessionNumber,
        absoluteWeek: resolution.absoluteWeekIndex,
        weekKind: resolution.weekKind,
      ),
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
      final target = _journeyTarget(prescription.dose);
      final targetRpe = switch (prescription.dose) {
        RepsDose(:final effort) => effort.rpe,
        TimedDose() => null,
      };
      points.add(
        JourneyPoint(
          session: sessionNumber,
          absoluteWeek: resolution.absoluteWeekIndex,
          weekKind: resolution.weekKind,
          exerciseId: prescription.exerciseId,
          exerciseName: entry.planExercise.name,
          load: load,
          hasExternalLoad: entry.planExercise.metricType.hasLoad,
          target: target.value,
          targetKind: target.kind,
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
  return JourneyResult(points: points, sessions: sessions);
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

({int value, JourneyTargetKind kind}) _journeyTarget(Dose dose) =>
    switch (dose) {
      RepsDose(:final targetReps) => (
        value: targetReps,
        kind: JourneyTargetKind.reps,
      ),
      TimedDose(:final hold) => (
        value: hold.inSeconds,
        kind: JourneyTargetKind.hold,
      ),
    };
