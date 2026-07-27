/// The 2026-07-24 three-way feel table (kept in `PROGRAMMING.md` §4 for provenance),
/// checked against the two-layer model that superseded it.
///
/// Where the old table still applies, the new pipeline reproduces it exactly. Where
/// it doesn't, the difference is the five-level split doing its job — the old "too
/// easy" row covered both "a bit easy" and "way too easy", and the old "too hard"
/// row covered both "harder than I'd like" and near-failure. Each divergence below
/// is named and pinned so a reviewer can see it was chosen, not drifted into.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

LoadDecision decide({
  required EffortLevel? tap,
  required int reps,
  ExerciseData? exercise,
  RepRange range = compoundRange,
  Kg lastLoad = const Kg(12),
}) => suggester.suggest(
  inputFor(
    exercise ?? gobletSquat,
    range: range,
    lastLoad: lastLoad,
    lastReps: reps,
    targetReps: reps,
    reported: tap,
  ),
);

void main() {
  group('rows that still hold exactly', () {
    test(
      '"just right" at the top of the range → +1 step, reps reset to the bottom',
      () {
        final decision = decide(tap: EffortLevel.justRight, reps: 12);
        expect(decision.externalLoad, const Kg(14));
        expect(decision.targetReps, 10);
        expect(decision.stepsMoved, 1);
      },
    );

    test('"just right" below the top → +1 rep, same weight', () {
      final decision = decide(tap: EffortLevel.justRight, reps: 10);
      expect(decision.externalLoad, const Kg(12));
      expect(decision.targetReps, 11);
    });

    test('"too easy" at the top of the range → +1 step, reps reset', () {
      for (final tap in <EffortLevel>[
        EffortLevel.wayTooEasy,
        EffortLevel.aBitEasy,
      ]) {
        final decision = decide(tap: tap, reps: 12);
        expect(decision.externalLoad, const Kg(14), reason: tap.name);
        expect(decision.targetReps, 10, reason: tap.name);
      }
    });

    test('"harder than I\'d like" → repeat identical weight and reps', () {
      final decision = decide(tap: EffortLevel.harderThanIdLike, reps: 10);
      expect(decision.externalLoad, const Kg(12));
      expect(decision.targetReps, 10);
      expect(decision.stepsMoved, 0);
    });

    test('no feedback → repeat identical', () {
      final decision = decide(tap: null, reps: 10);
      expect(decision.externalLoad, const Kg(12));
      expect(decision.targetReps, 10);
    });
  });

  group('rows the five-level split refines', () {
    test(
      '"a bit easy" below the top adds one rep where the old table added two — '
      'the same load, one session slower',
      () {
        final decision = decide(tap: EffortLevel.aBitEasy, reps: 10);
        expect(decision.externalLoad, const Kg(12));
        expect(decision.targetReps, 11);
        expect(decision.why, contains(ReasonCode.repsProgress));
      },
    );

    test(
      '"way too easy" below the top moves the *weight*, because §4.1 says she is '
      'under her working weight and reps are the wrong currency there',
      () {
        final decision = decide(tap: EffortLevel.wayTooEasy, reps: 10);
        expect(decision.regime, ProgressionRegime.calibration);
        expect(decision.externalLoad, const Kg(14));
        expect(decision.targetReps, 10);
        expect(decision.why, contains(ReasonCode.calibrationRegimeJump));
      },
    );

    test(
      '"too hard" (RPE ≥9) decreases immediately instead of waiting for a second '
      'report — §4.3 licenses it, and holding a near-failure load is the one thing '
      'v1 must not do',
      () {
        final decision = decide(tap: EffortLevel.tooHard, reps: 10);
        expect(decision.externalLoad! < const Kg(12), isTrue);
        expect(decision.why, contains(ReasonCode.loadDecrease));
      },
    );

    test(
      'the old "too hard twice → −10%" is what the formula now produces in one '
      'step when she also misses the reps',
      () {
        final decision = suggester.suggest(
          inputFor(
            legPress,
            range: compoundRange,
            lastLoad: const Kg(100),
            lastReps: 6,
            targetReps: 10,
            reported: EffortLevel.tooHard,
          ),
        );
        // −10% of 100 kg, snapped to the pin stack. The stall counter in §5 still
        // belongs to resolveSession, which sees more than one session.
        expect(decision.externalLoad, const Kg(90));
      },
    );
  });

  test('the old table\'s direction of travel is never contradicted', () {
    // For every row: easier reports never lower the load, harder reports never
    // raise it, and silence never changes anything.
    for (final reps in <int>[10, 11, 12]) {
      final easier = <EffortLevel>[
        EffortLevel.wayTooEasy,
        EffortLevel.aBitEasy,
      ];
      final harder = <EffortLevel>[
        EffortLevel.harderThanIdLike,
        EffortLevel.tooHard,
      ];
      for (final tap in easier) {
        expect(
          decide(tap: tap, reps: reps).stepsMoved,
          greaterThanOrEqualTo(0),
        );
      }
      for (final tap in harder) {
        expect(decide(tap: tap, reps: reps).stepsMoved, lessThanOrEqualTo(0));
      }
      expect(decide(tap: null, reps: reps).stepsMoved, 0);
    }
  });
}
