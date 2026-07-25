/// Totality: `LoadSuggester` never throws on weird-but-possible input.
///
/// `ENGINE.md` › "Failure behaviour": everything downstream of plan time returns a
/// value plus warnings. A crash mid-workout is far worse than a slightly worse
/// suggestion, and these inputs all arrive in practice — imported history, a synced
/// row from a newer version, a profile with no body mass, a set logged as 0 reps.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

typedef Bad = ({
  String rule,
  ProgressionInput input,
  WarningCode warning,
});

/// `bw_contribution` outside 0..1 can only come from content data, so it needs its
/// own fixture rather than a parameter.
ExerciseData gobletWithBw(double bwContribution) => ExerciseData(
      id: 'goblet-bad-bw',
      name: 'Goblet Squat (bad metadata)',
      blockRole: BlockRole.lowerSquat,
      movementClass: MovementClass.compoundLower,
      metricType: MetricType.loadReps,
      resistanceEquipment: ResistanceEquipment.dumbbell,
      bwContribution: bwContribution,
    );

ProgressionInput input({
  ExerciseData? exercise,
  RepRange range = compoundRange,
  Kg lastLoad = const Kg(12),
  int lastReps = 10,
  int targetReps = 10,
  EffortLevel? reported = EffortLevel.justRight,
  Kg bodyMass = referenceBodyMass,
  int daysSinceLastSession = 3,
  UnitSystem unitSystem = UnitSystem.metric,
}) =>
    ProgressionInput(
      profile: exercise ?? gobletSquat,
      range: range,
      effort: EffortTarget.rpe7,
      unitSystem: unitSystem,
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
  final cases = <Bad>[
    (
      rule: 'no body mass on a movement that needs it → external-only math',
      input: input(bodyMass: Kg.zero),
      warning: WarningCode.invalidBodyMass,
    ),
    (
      rule: 'negative body mass',
      input: input(bodyMass: const Kg(-70)),
      warning: WarningCode.invalidBodyMass,
    ),
    (
      rule: 'NaN body mass',
      input: input(bodyMass: const Kg(double.nan)),
      warning: WarningCode.invalidBodyMass,
    ),
    (
      rule: 'bw_contribution above 1',
      input: input(exercise: gobletWithBw(2.5)),
      warning: WarningCode.bwContributionOutOfRange,
    ),
    (
      rule: 'bw_contribution below 0',
      input: input(exercise: gobletWithBw(-1)),
      warning: WarningCode.bwContributionOutOfRange,
    ),
    (
      rule: 'NaN bw_contribution',
      input: input(exercise: gobletWithBw(double.nan)),
      warning: WarningCode.bwContributionOutOfRange,
    ),
    (
      rule: 'a set logged with zero reps',
      input: input(lastReps: 0),
      warning: WarningCode.invalidReps,
    ),
    (
      rule: 'a set logged with negative reps',
      input: input(lastReps: -5),
      warning: WarningCode.invalidReps,
    ),
    (
      rule: 'an inverted rep range',
      input: input(range: const RepRange(12, 8), targetReps: 10),
      warning: WarningCode.invertedRepRange,
    ),
    (
      rule: 'a target above the rep range',
      input: input(targetReps: 99),
      warning: WarningCode.targetRepsOutOfRange,
    ),
    (
      rule: 'a target below the rep range',
      input: input(targetReps: 1),
      warning: WarningCode.targetRepsOutOfRange,
    ),
    (
      rule: 'a load lighter than the empty bar',
      input: input(exercise: barbellSquat, lastLoad: const Kg(1)),
      warning: WarningCode.loadBelowEquipmentFloor,
    ),
    (
      rule: 'a NaN load',
      input: input(lastLoad: const Kg(double.nan)),
      warning: WarningCode.nonFiniteLoad,
    ),
    (
      rule: 'an infinite load',
      input: input(lastLoad: const Kg(double.infinity)),
      warning: WarningCode.nonFiniteLoad,
    ),
    (
      rule: 'a load that is not on this gym\'s ladder',
      input: input(lastLoad: const Kg(13)),
      warning: WarningCode.lastLoadNotRepresentable,
    ),
    (
      rule: 'a negative layoff (a clock that went backwards)',
      input: input(daysSinceLastSession: -20),
      warning: WarningCode.negativeLayoff,
    ),
  ];

  group('weird-but-possible input returns a value plus a warning', () {
    for (final entry in cases) {
      test(entry.rule, () {
        final decision = suggester.suggest(entry.input);
        expect(
          decision.warnings.map((w) => w.code),
          contains(entry.warning),
          reason: '$decision',
        );
        expect(decision.why, isNotEmpty, reason: 'still explains itself');
        final load = decision.externalLoad;
        if (load != null) {
          expect(load.isFinite, isTrue, reason: '$decision');
          final loads =
              config.availableLoads(entry.input.profile, entry.input.unitSystem);
          expect(loads.isRepresentable(load), isTrue, reason: '$decision');
        }
        expect(decision.targetReps, greaterThanOrEqualTo(1), reason: '$decision');
      });
    }
  });

  test('every pathological value at once still produces a usable decision', () {
    final decision = suggester.suggest(ProgressionInput(
      profile: gobletWithBw(double.negativeInfinity),
      range: const RepRange(15, 3),
      effort: EffortTarget.rpe7,
      unitSystem: UnitSystem.imperial,
      bodyMass: const Kg(double.nan),
      daysSinceLastSession: -99,
      history: const ExerciseSnapshot(
        lastLoad: Kg(double.negativeInfinity),
        lastReps: -3,
        targetReps: -7,
        reportedEffort: EffortLevel.tooHard,
      ),
    ));
    expect(decision.warnings.length, greaterThanOrEqualTo(4));
    expect(decision.externalLoad!.isFinite, isTrue);
    expect(decision.targetReps, greaterThanOrEqualTo(1));
    expect(decision.why, isNotEmpty);
  });

  test('absurd rep counts are absorbed by the guardrails, not by an exception', () {
    for (final reps in <int>[1, 100, 5000]) {
      final decision = suggester.suggest(input(lastReps: reps));
      expect(decision.stepsMoved.abs(), lessThanOrEqualTo(2), reason: '$reps reps');
      expect(decision.externalLoad!.isFinite, isTrue);
    }
  });

  test('a timed movement with no recorded hold starts from the floor', () {
    final decision = suggester.suggest(ProgressionInput(
      profile: plank,
      range: const RepRange(1, 1),
      effort: EffortTarget.rpe7,
      unitSystem: UnitSystem.metric,
      history: const ExerciseSnapshot(
        lastLoad: Kg.zero,
        lastReps: 1,
        targetReps: 1,
        reportedEffort: EffortLevel.justRight,
      ),
    ));
    expect(decision.hold, config.timedHoldFloor + config.timedHoldStep);
  });

  test('a first-exposure decision needs no history and no body mass', () {
    for (final exercise in loadMetricFixtures) {
      final decision = suggester.suggest(ProgressionInput(
        profile: exercise,
        range: compoundRange,
        effort: EffortTarget.rpe7,
        unitSystem: UnitSystem.metric,
      ));
      expect(decision.regime, ProgressionRegime.firstExposure);
      expect(decision.suggestion, isA<NeedsCalibration>());
      expect(decision.targetReps, config.calibrationProbeReps);
      expect(decision.warnings, isEmpty, reason: '${exercise.id}: $decision');
    }
  });

  test('the reps-only and timed paths are total on a first exposure too', () {
    final pushUps = suggester.suggest(ProgressionInput(
      profile: pushUp,
      range: const RepRange(8, 15),
      effort: EffortTarget.rpe7,
      unitSystem: UnitSystem.metric,
    ));
    expect(pushUps.suggestion, const RepOrDurationTarget.reps(8));

    final planks = suggester.suggest(ProgressionInput(
      profile: plank,
      range: const RepRange(1, 1),
      effort: EffortTarget.rpe7,
      unitSystem: UnitSystem.metric,
    ));
    expect(planks.hold, config.timedHoldFloor);
  });
}
