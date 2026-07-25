/// §6 "Layoff handling", encoded 1:1 — plus the monotonicity invariant.
///
/// "Never punish absence": the tier is applied before progression, silently.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

typedef Tier = ({String rule, int days, LayoffTier tier, double loadFraction});

void main() {
  group('§6 the layoff table', () {
    const tiers = <Tier>[
      (
        rule: '0 days away: normal progression',
        days: 0,
        tier: LayoffTier.none,
        loadFraction: 1,
      ),
      (
        rule: '6 days away: still normal progression',
        days: 6,
        tier: LayoffTier.none,
        loadFraction: 1,
      ),
      (
        rule: '7 days away: repeat last weights, no increase',
        days: 7,
        tier: LayoffTier.hold,
        loadFraction: 1,
      ),
      (
        rule: '13 days away: still repeat, no increase',
        days: 13,
        tier: LayoffTier.hold,
        loadFraction: 1,
      ),
      (
        rule: '14 days away: −10% on all working weights',
        days: 14,
        tier: LayoffTier.reduce,
        loadFraction: 0.9,
      ),
      (
        rule: '27 days away: still −10%',
        days: 27,
        tier: LayoffTier.reduce,
        loadFraction: 0.9,
      ),
      (
        rule: '28 days away: −20% and re-calibrate the compound lifts',
        days: 28,
        tier: LayoffTier.reCalibrate,
        loadFraction: 0.8,
      ),
      (
        rule: 'a year away: still the 28+ tier',
        days: 365,
        tier: LayoffTier.reCalibrate,
        loadFraction: 0.8,
      ),
    ];

    for (final entry in tiers) {
      test(entry.rule, () {
        final tier = layoffTierFor(entry.days, config);
        expect(tier, entry.tier);
        expect(layoffLoadFraction(tier, config), entry.loadFraction);
      });
    }

    test('a negative day count is treated as no layoff, not as an error', () {
      expect(layoffTierFor(-30, config), LayoffTier.none);
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

    test(
      '7–13 days: identical load and reps, even on a "way too easy" report',
      () {
        final decision = suggester.suggest(gobletAfter(9));
        expect(decision.regime, ProgressionRegime.layoff);
        expect(decision.externalLoad, const Kg(12));
        expect(decision.targetReps, 12);
        expect(decision.stepsMoved, 0);
        expect(decision.why, contains(ReasonCode.layoffTier1));
      },
    );

    test('14–27 days: −10%, snapped down to a real dumbbell', () {
      final decision = suggester.suggest(gobletAfter(20));
      // 12 kg × 0.9 = 10.8 → the 10 kg dumbbells.
      expect(decision.externalLoad, const Kg(10));
      expect(decision.why, contains(ReasonCode.layoffTier2));
    });

    test('28+ days: −20% and the compound lifts re-find their weights', () {
      final decision = suggester.suggest(gobletAfter(40));
      expect(decision.externalLoad, const Kg(8));
      expect(
        decision.suggestion,
        const NeedsCalibration(floor: Kg(8), probeReps: 8),
        reason: 'the probe restarts from history, not from the empty rack',
      );
      expect(decision.targetReps, config.calibrationProbeReps);
      expect(decision.why, contains(ReasonCode.layoffTier3));
    });

    test('28+ days: isolation work just drops 20%, no probe', () {
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
      expect(decision.why, contains(ReasonCode.layoffTier3));
    });

    test('a layoff overrides the missing feel tap too', () {
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
      expect(decision.why, contains(ReasonCode.layoffTier2));
      expect(decision.why, isNot(contains(ReasonCode.noFeedbackHold)));
    });

    test('assisted-stack layoff reduction means more assistance, not less', () {
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
      // 59.5 kg body term − 30 kg assistance = 29.5 kg effective;
      // 90% is 26.55 kg, or −32.95 kg external, snapped down to −35.
      expect(decision.externalLoad, const Kg(-35));
      expect(decision.stepsMoved, -1);
      expect(decision.why, contains(ReasonCode.layoffTier2));
    });

    test('layoff is monotone: more days away is never heavier', () {
      const days = <int>[0, 3, 6, 7, 10, 13, 14, 20, 27, 28, 60, 400];
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

    test('bodyweight and timed movements also ease back in', () {
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
      expect(pushUps.targetReps, 8);
      expect(pushUps.why, contains(ReasonCode.layoffTier2));

      final planks = suggester.suggest(
        inputFor(
          plank,
          range: const RepRange(1, 1),
          lastHold: const Duration(seconds: 45),
          reported: EffortLevel.justRight,
          daysSinceLastSession: 20,
        ),
      );
      expect(planks.hold, const Duration(seconds: 40));
      expect(planks.why, contains(ReasonCode.layoffTier2));
    });
  });
}
