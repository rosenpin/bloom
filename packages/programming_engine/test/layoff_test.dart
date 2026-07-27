/// §6 continuous layoff curve, encoded 1:1 with its monotonicity invariant.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

typedef CurvePoint = ({String rule, int days, double multiplier});

void main() {
  group('§6 layoff curve', () {
    const points = <CurvePoint>[
      (rule: 'day 0 is normal', days: 0, multiplier: 1),
      (rule: 'day 7 is the grace anchor', days: 7, multiplier: 1),
      (rule: 'day 8 starts the slope', days: 8, multiplier: 0.9925),
      (
        rule: 'day 13 preserves the provenance anchor',
        days: 13,
        multiplier: 0.955,
      ),
      (rule: 'day 20 remains continuous', days: 20, multiplier: 0.9025),
      (rule: 'day 33 is still above the floor', days: 33, multiplier: 0.805),
      (rule: 'day 34 reaches the floor', days: 34, multiplier: 0.8),
      (rule: 'a year away stays at the floor', days: 365, multiplier: 0.8),
    ];

    for (final point in points) {
      test(point.rule, () {
        expect(
          layoffMultiplier(point.days, config),
          closeTo(point.multiplier, 1e-12),
        );
      });
    }

    test('negative elapsed days naturally use the day-zero endpoint', () {
      expect(layoffMultiplier(-30, config), 1);
      expect(layoffSuppressesProgression(-30, config), isFalse);
    });

    test('suppression begins strictly after the grace period', () {
      expect(layoffSuppressesProgression(7, config), isFalse);
      expect(layoffSuppressesProgression(8, config), isTrue);
    });
  });

  group('§6 applied before progression', () {
    ProgressionInput gobletAfter(int days, {EffortLevel? tap}) => inputFor(
      gobletSquat,
      range: compoundRange,
      lastLoad: const Kg(12),
      lastReps: 12,
      targetReps: 12,
      reported: tap ?? EffortLevel.wayTooEasy,
      daysSinceLastSession: days,
    );

    test('the first sloped day suppresses an otherwise licensed increase', () {
      final decision = suggester.suggest(gobletAfter(8));
      expect(decision.regime, ProgressionRegime.layoff);
      expect(decision.externalLoad, const Kg(10));
      expect(decision.targetReps, 12);
      expect(decision.why, contains(ReasonCode.layoffAdjusted));
    });

    test('day 20 scales continuously, then snaps down to real equipment', () {
      final decision = suggester.suggest(gobletAfter(20));
      // 12 kg × 0.9025 = 10.83 → the 10 kg dumbbells.
      expect(decision.externalLoad, const Kg(10));
      expect(decision.why, contains(ReasonCode.layoffAdjusted));
    });

    test('the floor re-calibrates compound lifts', () {
      final decision = suggester.suggest(gobletAfter(40));
      expect(decision.externalLoad, const Kg(8));
      expect(
        decision.suggestion,
        const NeedsCalibration(floor: Kg(8), probeReps: 8),
        reason: 'the probe restarts from history, not from the empty rack',
      );
      expect(decision.targetReps, config.calibrationProbeReps);
      expect(decision.why, contains(ReasonCode.layoffAdjusted));
      expect(decision.why, contains(ReasonCode.layoffFloorRecalibration));
    });

    test('the floor scales isolation work without a probe', () {
      final decision = suggester.suggest(
        inputFor(
          lateralRaise,
          range: isolationRange,
          lastLoad: const Kg(6),
          lastReps: 15,
          targetReps: 15,
          reported: EffortLevel.justRight,
          daysSinceLastSession: 40,
        ),
      );
      expect(decision.suggestion, const SuggestedLoad(Kg(4)));
      expect(decision.why, contains(ReasonCode.layoffAdjusted));
      expect(
        decision.why,
        isNot(contains(ReasonCode.layoffFloorRecalibration)),
      );
    });

    test('the curve overrides a missing feel tap too', () {
      final decision = suggester.suggest(
        inputFor(
          gobletSquat,
          range: compoundRange,
          lastLoad: const Kg(12),
          targetReps: 12,
          daysSinceLastSession: 20,
        ),
      );
      expect(decision.externalLoad, const Kg(10));
      expect(decision.why, contains(ReasonCode.layoffAdjusted));
      expect(decision.why, isNot(contains(ReasonCode.noFeedbackHold)));
    });

    test('assisted-stack scaling means more assistance, not less', () {
      final decision = suggester.suggest(
        inputFor(
          assistedPullUp,
          range: compoundRange,
          lastLoad: const Kg(-30),
          targetReps: 10,
          reported: EffortLevel.justRight,
          daysSinceLastSession: 20,
        ),
      );
      expect(decision.externalLoad, const Kg(-35));
      expect(decision.stepsMoved, -1);
      expect(decision.why, contains(ReasonCode.layoffAdjusted));
    });

    test('more days away never yields a heavier prescription', () {
      const days = <int>[0, 3, 6, 7, 8, 10, 13, 14, 20, 27, 28, 34, 60, 400];
      for (final exercise in loadMetricFixtures) {
        var previous = const Kg(1e9);
        for (final away in days) {
          final decision = suggester.suggest(
            inputFor(
              exercise,
              range: config.rangeFor(
                exercise,
                const RepScheme(
                  minSets: 3,
                  maxSets: 3,
                  range: compoundRange,
                  effort: EffortTarget.rpe7,
                  rest: Duration(seconds: 75),
                ),
              ),
              lastLoad: const Kg(20),
              lastReps: 15,
              targetReps: 12,
              reported: EffortLevel.wayTooEasy,
              daysSinceLastSession: away,
            ),
          );
          final load = decision.externalLoad!;
          expect(
            load <= previous,
            isTrue,
            reason:
                '${exercise.id} at $away days: ${load.value} > ${previous.value}',
          );
          previous = load;
        }
      }
    });

    test(
      'reps-only and timed strategies suppress progress on the same curve',
      () {
        final pushUps = suggester.suggest(
          inputFor(
            pushUp,
            range: const RepRange(8, 15),
            lastReps: 15,
            targetReps: 15,
            reported: EffortLevel.justRight,
            daysSinceLastSession: 20,
          ),
        );
        expect(pushUps.targetReps, 15);
        expect(pushUps.why, contains(ReasonCode.layoffAdjusted));

        final planks = suggester.suggest(
          inputFor(
            plank,
            range: const RepRange(1, 1),
            lastHold: const Duration(seconds: 45),
            reported: EffortLevel.justRight,
            daysSinceLastSession: 20,
          ),
        );
        expect(planks.hold, const Duration(seconds: 45));
        expect(planks.why, contains(ReasonCode.layoffAdjusted));
      },
    );
  });
}
