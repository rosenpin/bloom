import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/plan_fixtures.dart';

void main() {
  group('resolveSession', () {
    test('picks the next unfinished day in the current plan week', () {
      final plan = successfulPlan(personaFixtures[1].profile);
      final date = DateTime.utc(2026, 1, 5);
      final empty = TrainingHistory(bodyMass: const Kg(65));
      final first = resolveSession(plan, empty, date);
      final history = empty.add(
        first.toRecord(sessionId: 's1', events: _completedEvents(first)),
      );
      final second = resolveSession(
        plan,
        history,
        date.add(const Duration(days: 2)),
      );

      expect(first.dayIndex, 1);
      expect(second.dayIndex, 2);
      expect(second.absoluteWeekIndex, 1);
    });

    test('a complete plan week repeats the last day as a reasoned flow', () {
      final plan = successfulPlan(personaFixtures[1].profile);
      final date = DateTime.utc(2026, 1, 5);
      var history = TrainingHistory(bodyMass: const Kg(65));
      for (var index = 0; index < plan.days.length; index++) {
        final session = resolveSession(
          plan,
          history,
          date.add(Duration(days: index)),
        );
        history = history.add(
          session.toRecord(
            sessionId: 'complete-$index',
            events: _completedEvents(session),
          ),
        );
      }

      final repeated = resolveSession(
        plan,
        history,
        date.add(Duration(days: plan.days.length)),
      );
      expect(repeated.dayIndex, plan.days.last.dayIndex);
      expect(repeated.reasonCodes, contains(ReasonCode.planWeekCompleteRepeat));
      expect(repeated.warnings, isEmpty);
    });

    test('run twice is equal and byte-identical', () {
      final plan = successfulPlan(personaFixtures[0].profile);
      final history = TrainingHistory(bodyMass: const Kg(65));
      final date = DateTime.utc(2026, 1, 5);

      final first = resolveSession(plan, history, date);
      final second = resolveSession(plan, history, date);
      expect(first, second);
      expect(first.toCanonicalString(), second.toCanonicalString());
    });

    test('every prescription explains itself and is representable', () {
      final config = ProgrammingConfig();
      final plan = successfulPlan(personaFixtures[0].profile, config: config);
      final resolution = resolveSession(
        plan,
        TrainingHistory(bodyMass: const Kg(65)),
        DateTime.utc(2026, 1, 5),
        config: config,
      );
      final profiles = _loadProfiles(plan);

      for (final prescription in resolution.prescriptions) {
        expect(prescription.why, isNotEmpty, reason: prescription.exerciseId);
        final profile = profiles[prescription.exerciseId]!;
        final loads = config.availableLoads(profile, UnitSystem.metric);
        switch (prescription.suggestion) {
          case SuggestedLoad(:final kg):
            expect(
              loads.isRepresentable(kg),
              isTrue,
              reason: prescription.exerciseId,
            );
          case BodyweightOnly(:final added):
            expect(
              loads.isRepresentable(added),
              isTrue,
              reason: prescription.exerciseId,
            );
          case NeedsCalibration(:final floor):
            expect(
              loads.isRepresentable(floor),
              isTrue,
              reason: prescription.exerciseId,
            );
          case RepOrDurationTarget():
            break;
        }
      }
    });

    test('excluded planned exercise auto-substitutes and warns', () {
      final plan = successfulPlan(personaFixtures[1].profile);
      final excluded = plan.days.first.exercises.first.exerciseId;
      final resolution = resolveSession(
        plan,
        TrainingHistory(
          bodyMass: const Kg(65),
          userExcludedExerciseIds: {excluded},
        ),
        DateTime.utc(2026, 1, 5),
      );

      expect(
        resolution.prescriptions.map((item) => item.exerciseId),
        isNot(contains(excluded)),
      );
      expect(
        resolution.warnings.map((warning) => warning.code),
        contains(WarningCode.excludedExerciseSubstituted),
      );
      expect(
        resolution.prescriptions.first.why,
        contains(ReasonCode.swapApplied),
      );
    });

    test('two consecutive too-hard taps select reactive deload', () {
      final plan = successfulPlan(personaFixtures[1].profile);
      final exercise = plan.days.last.exercises.first;
      final firstDate = DateTime.utc(2026, 1, 5);
      final records = <SessionRecord>[
        for (var index = 0; index < 2; index++)
          SessionRecord(
            sessionId: 'hard-${index + 1}',
            date: firstDate.add(Duration(days: index * 2)),
            planRef: plan.reference,
            mesocycleIndex: 1,
            mesocycleWeekIndex: 1,
            absoluteWeekIndex: 1,
            dayIndex: index + 1,
            weekKind: MesocycleWeekKind.build,
            events: [
              SetCompleted(
                exerciseId: exercise.exerciseId,
                setIndex: 0,
                load: const Kg(30),
                reps: 10,
                unitSystem: UnitSystem.metric,
              ),
              EffortReported(
                exerciseId: exercise.exerciseId,
                level: EffortLevel.tooHard,
              ),
            ],
          ),
      ];

      final resolution = resolveSession(
        plan,
        TrainingHistory(records: records, bodyMass: const Kg(65)),
        firstDate.add(const Duration(days: 4)),
      );
      final prescription = resolution.prescriptions.firstWhere(
        (item) => item.exerciseId == exercise.exerciseId,
      );
      expect(prescription.why, contains(ReasonCode.reactiveDeload));
      expect(_loadOf(prescription.suggestion).value, lessThan(30));
    });

    test('a plan cannot represent an empty training week', () {
      expect(
        () => Plan(
          mesocycleIndex: 1,
          stamps: const PlanStamps(
            engineVersion: 'test',
            configHash: 'config',
            contentHash: 'content',
            profileHash: 'profile',
          ),
          mesocycleCalendar: const <PlanWeek>[],
          days: const <PlanDay>[],
          warnings: const <EngineWarning>[],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

List<SessionEvent> _completedEvents(
  SessionResolution resolution, {
  EffortLevel effort = EffortLevel.justRight,
}) => [
  for (final prescription in resolution.prescriptions) ...[
    SetCompleted(
      exerciseId: prescription.exerciseId,
      setIndex: 0,
      load: _loadOf(prescription.suggestion),
      reps: _targetReps(prescription),
      unitSystem: UnitSystem.metric,
    ),
    EffortReported(exerciseId: prescription.exerciseId, level: effort),
  ],
];

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

Map<String, LoadProfile> _loadProfiles(Plan plan) {
  final result = <String, LoadProfile>{};
  for (final exercise in plan.days.expand((day) => day.exercises)) {
    result[exercise.exerciseId] = exercise;
    for (final swap in exercise.orderedSwapCandidates) {
      result[swap.exerciseId] = swap;
    }
  }
  return result;
}
