/// The engine trusts boundary-validated data and represents designed absence.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

ProgressionInput input({
  ExerciseData? exercise,
  RepRange range = compoundRange,
  Kg lastLoad = const Kg(12),
  int lastReps = 10,
  int targetReps = 10,
  EffortLevel? reported = EffortLevel.justRight,
  Kg? bodyMass = referenceBodyMass,
  int daysSinceLastSession = 3,
}) => ProgressionInput(
  profile: exercise ?? gobletSquat,
  range: range,
  effort: EffortTarget.rpe7,
  unitSystem: UnitSystem.metric,
  bodyMass: bodyMass,
  daysSinceLastSession: daysSinceLastSession,
  history: ExerciseSnapshot(
    lastLoad: lastLoad,
    lastReps: lastReps,
    targetReps: targetReps,
    reportedEffort: reported,
  ),
);

void main() {
  group('designed real-world normalization', () {
    test('absent body mass uses external-only math without a warning', () {
      final decision = suggester.suggest(input(bodyMass: null));
      expect(decision.externalLoad, isNotNull);
      expect(decision.why, isNotEmpty);
    });

    test('a negative layoff from clock skew behaves as zero days', () {
      final skewed = suggester.suggest(input(daysSinceLastSession: -20));
      final sameDay = suggester.suggest(input(daysSinceLastSession: 0));
      expect(skewed.suggestion, sameDay.suggestion);
      expect(skewed.targetReps, sameDay.targetReps);
      expect(skewed.why, sameDay.why);
    });

    test('a user-edited load snaps to the equipment ladder silently', () {
      final decision = suggester.suggest(input(lastLoad: const Kg(3.7)));
      final loads = config.availableLoads(gobletSquat, UnitSystem.metric);
      expect(decision.externalLoad, isNotNull);
      expect(loads.isRepresentable(decision.externalLoad!), isTrue);
    });

    test('legacy target reps clamp into a later plan window', () {
      final decision = suggester.suggest(input(targetReps: 8));
      expect(decision.targetReps, greaterThanOrEqualTo(compoundRange.min));
    });
  });

  group('programmer and configuration errors assert in debug', () {
    test('rep ranges cannot be empty or inverted', () {
      final zero = 0;
      final high = 12;
      expect(() => RepRange(zero, 8), throwsA(isA<AssertionError>()));
      expect(() => RepRange(high, 8), throwsA(isA<AssertionError>()));
    });

    test('exercise content cannot carry an invalid body-mass fraction', () {
      final invalidContribution = 1.5;
      expect(
        () => ExerciseData(
          id: 'invalid',
          name: 'Invalid',
          blockRole: BlockRole.lowerSquat,
          movementClass: MovementClass.compoundLower,
          metricType: MetricType.loadReps,
          resistanceEquipment: ResistanceEquipment.dumbbell,
          bwContribution: invalidContribution,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('event-derived snapshots require finite load and positive reps', () {
      final invalidLoad = Kg(double.nan);
      final invalidReps = 0;
      expect(
        () => ExerciseSnapshot(
          lastLoad: invalidLoad,
          lastReps: 10,
          targetReps: 10,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ExerciseSnapshot(
          lastLoad: const Kg(10),
          lastReps: invalidReps,
          targetReps: 10,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SetCompleted(
          exerciseId: 'x',
          setIndex: 0,
          load: const Kg(10),
          reps: invalidReps,
          unitSystem: UnitSystem.metric,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('configuration cannot invent invalid weeks, fractions, or steps', () {
      final noWeeks = 0;
      final badFraction = 1.2;
      expect(
        () => ProgrammingConfig(mesocycleWeeks: noWeeks),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ProgrammingConfig(maxChangeFraction: badFraction),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => EquipmentLoadTable(
          barbellBar: const Kg(20),
          barbellUpperStep: Kg.zero,
          barbellLowerStep: const Kg(5),
          dumbbellFloor: const Kg(2),
          dumbbellStep: const Kg(2),
          machineFloor: const Kg(5),
          machineStep: const Kg(5),
          assistedStackMaxAssistance: const Kg(50),
          assistedStackStep: const Kg(5),
          cableFloor: const Kg(2.5),
          cableStep: const Kg(2.5),
          addedLoadStep: const Kg(2),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('first exposure still follows each metric strategy', () {
    for (final exercise in loadMetricFixtures) {
      final decision = suggester.suggest(
        ProgressionInput(
          profile: exercise,
          range: compoundRange,
          effort: EffortTarget.rpe7,
          unitSystem: UnitSystem.metric,
        ),
      );
      expect(decision.regime, ProgressionRegime.firstExposure);
      expect(decision.suggestion, isA<NeedsCalibration>());
    }

    final pushUps = suggester.suggest(
      ProgressionInput(
        profile: pushUp,
        range: const RepRange(8, 15),
        effort: EffortTarget.rpe7,
        unitSystem: UnitSystem.metric,
      ),
    );
    expect(pushUps.suggestion, const RepOrDurationTarget.reps(8));

    final planks = suggester.suggest(
      ProgressionInput(
        profile: plank,
        range: const RepRange(1, 1),
        effort: EffortTarget.rpe7,
        unitSystem: UnitSystem.metric,
      ),
    );
    expect(planks.hold, config.timedHoldFloor);
  });
}
