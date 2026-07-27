/// Invariants — asserted over a swept grid, never snapshotted.
///
/// `ENGINE.md` › "Test strategy": no feedback ⇒ unchanged · "too hard" ⇒ load never
/// increases · load moves ≤1 step (≤2 during calibration) · target reps within
/// range · every load representable on its equipment family · run-twice equality.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// The sweep: every load-metric fixture × both markets × a spread of loads, reps
/// and taps. Fixed lists, no randomness — `ENGINE.md` › "Determinism".
Iterable<ProgressionInput> sweep({List<EffortLevel?>? levels}) sync* {
  const scheme = RepScheme(
    minSets: 3,
    maxSets: 3,
    range: compoundRange,
    effort: EffortTarget.rpe7,
    rest: Duration(seconds: 75),
  );
  const loads = <Kg>[Kg(2), Kg(5), Kg(12), Kg(22.5), Kg(45), Kg(100)];
  const repsSpread = <int>[5, 8, 10, 12, 15];
  // Every effort target the shipped goals use: RPE 6 (feel healthier), 7 (toned,
  // build curves, and every novice), 8 (stronger).
  const targets = <EffortTarget>[
    EffortTarget(6),
    EffortTarget(7),
    EffortTarget(8),
  ];
  final taps = levels ?? <EffortLevel?>[...EffortLevel.values, null];

  for (final exercise in loadMetricFixtures) {
    final range = config.rangeFor(exercise, scheme);
    for (final unitSystem in UnitSystem.values) {
      for (final load in loads) {
        for (final lastReps in repsSpread) {
          for (final targetReps in <int>[range.min, range.max]) {
            for (final effort in targets) {
              for (final tap in taps) {
                yield inputFor(
                  exercise,
                  range: range,
                  effort: effort,
                  unitSystem: unitSystem,
                  lastLoad: load,
                  lastReps: lastReps,
                  targetReps: targetReps,
                  reported: tap,
                );
              }
            }
          }
        }
      }
    }
  }
}

void main() {
  test('the sweep is big enough to be worth calling a sweep', () {
    expect(sweep().length, greaterThan(6000));
  });

  test('every suggested load is representable on its equipment family', () {
    for (final input in sweep()) {
      final decision = suggester.suggest(input);
      final load = decision.externalLoad;
      if (load == null) continue;
      final loads = config.availableLoads(input.profile, input.unitSystem);
      expect(
        loads.isRepresentable(load),
        isTrue,
        reason:
            '${input.profile.resistanceEquipment.name} '
            '${input.unitSystem.name}: ${load.value}kg is not on the ladder '
            '($loads) — $decision',
      );
    }
  });

  test('assisted-stack loads are representable and never exceed zero', () {
    for (final unitSystem in UnitSystem.values) {
      final loads = config.availableLoads(assistedPullUp, unitSystem);
      for (var rung = 0; rung <= 15; rung++) {
        final base = loads.shift(loads.floor, rung);
        for (final level in EffortLevel.values) {
          final decision = suggester.suggest(
            inputFor(
              assistedPullUp,
              range: compoundRange,
              unitSystem: unitSystem,
              lastLoad: base,
              lastReps: level == EffortLevel.tooHard ? 6 : 12,
              targetReps: 12,
              reported: level,
            ),
          );
          final load = decision.externalLoad!;
          expect(load <= Kg.zero, isTrue, reason: '$decision');
          expect(loads.isRepresentable(load), isTrue, reason: '$decision');
        }
      }
    }
  });

  test('no feedback ⇒ load and reps unchanged', () {
    for (final input in sweep(levels: <EffortLevel?>[null])) {
      final decision = suggester.suggest(input);
      expect(decision.regime, ProgressionRegime.noFeedback);
      expect(decision.stepsMoved, 0, reason: '$decision');
      expect(
        decision.targetReps,
        input.history!.targetReps,
        reason: '$decision',
      );
      expect(decision.why, contains(ReasonCode.noFeedbackHold));
    }
  });

  test('"too hard" never increases the load', () {
    for (final input in sweep(
      levels: <EffortLevel?>[EffortLevel.tooHard, EffortLevel.harderThanIdLike],
    )) {
      final decision = suggester.suggest(input);
      expect(decision.stepsMoved, lessThanOrEqualTo(0), reason: '$decision');
    }
  });

  test('"too hard" never increases the target reps either', () {
    for (final input in sweep(
      levels: <EffortLevel?>[EffortLevel.tooHard, EffortLevel.harderThanIdLike],
    )) {
      final decision = suggester.suggest(input);
      expect(
        decision.targetReps,
        lessThanOrEqualTo(input.history!.targetReps),
        reason: '$decision',
      );
    }
  });

  test('the load never moves more than two equipment steps', () {
    for (final input in sweep()) {
      final decision = suggester.suggest(input);
      expect(
        decision.stepsMoved.abs(),
        lessThanOrEqualTo(2),
        reason: '$decision',
      );
    }
  });

  test('the calibration regime moves at most two steps', () {
    for (final input in sweep(levels: <EffortLevel?>[EffortLevel.wayTooEasy])) {
      final decision = suggester.suggest(input);
      if (decision.regime != ProgressionRegime.calibration) continue;
      expect(
        decision.stepsMoved.abs(),
        lessThanOrEqualTo(2),
        reason: '$decision',
      );
    }
  });

  test(
    'the normal regime moves at most ONE step wherever a step is coarser than the '
    '±10% cap — the beginner case ENGINE.md names',
    () {
      var checked = 0;
      for (final input in sweep()) {
        final decision = suggester.suggest(input);
        if (decision.regime != ProgressionRegime.normal) continue;
        final loads = config.availableLoads(input.profile, input.unitSystem);
        final base = loads.snapDown(input.history!.lastLoad);
        final bodyTerm = input.bodyMass! * input.profile.bwContribution;
        final effective = base + bodyTerm;
        if (loads.stepAt(base) < effective * config.maxChangeFraction) continue;
        checked++;
        expect(
          decision.stepsMoved.abs(),
          lessThanOrEqualTo(1),
          reason: '$decision',
        );
      }
      expect(
        checked,
        greaterThan(100),
        reason: 'the coarse-step case must be covered',
      );
    },
  );

  test('the load change never exceeds the cap the config allows', () {
    for (final input in sweep()) {
      final decision = suggester.suggest(input);
      final load = decision.externalLoad;
      if (load == null) continue;
      final loads = config.availableLoads(input.profile, input.unitSystem);
      final base = loads.snapDown(input.history!.lastLoad);
      final bodyTerm = input.bodyMass! * input.profile.bwContribution;
      final oneStep = loads.stepAt(base);
      final calibrating = decision.regime == ProgressionRegime.calibration;
      final fraction = calibrating
          ? config.calibrationMaxIncreaseFraction
          : config.maxChangeFraction;
      var allowed = (base + bodyTerm) * fraction;
      if (allowed < oneStep) allowed = oneStep;
      final ceiling = oneStep * config.maxStepsPerAdjustment;
      if (allowed > ceiling) allowed = ceiling;
      // Decreases may round down past the cap by less than one step: coarse
      // dumbbells cannot express 10%, and holding instead would mean a beginner
      // could never deload. Increases are exact.
      final slack = decision.stepsMoved < 0 ? oneStep : Kg.zero;
      expect(
        (load - base).abs.value,
        lessThanOrEqualTo((allowed + slack).value + 1e-9),
        reason: '$decision',
      );
    }
  });

  test('target reps stay inside the prescribable window', () {
    for (final input in sweep()) {
      final decision = suggester.suggest(input);
      final isIsolationLike =
          input.profile.movementClass.isIsolation ||
          input.profile.laterality.isPerSide;
      final low =
          isIsolationLike && config.isolationRestartRange.min < input.range.min
          ? config.isolationRestartRange.min
          : input.range.min;
      expect(
        decision.targetReps,
        greaterThanOrEqualTo(low),
        reason: '$decision',
      );
      expect(
        decision.targetReps,
        lessThanOrEqualTo(input.range.max),
        reason: '$decision',
      );
    }
  });

  test('running twice gives an identical decision', () {
    for (final input in sweep()) {
      final first = suggester.suggest(input);
      final second = suggester.suggest(input);
      expect(second.suggestion, first.suggestion);
      expect(second.targetReps, first.targetReps);
      expect(second.hold, first.hold);
      expect(second.regime, first.regime);
      expect(second.stepsMoved, first.stepsMoved);
      expect(second.bridge, first.bridge);
      expect(second.why, first.why);
      expect(second.toString(), first.toString());
    }
  });

  test('a load decision never comes back without an explanation', () {
    for (final input in sweep()) {
      expect(suggester.suggest(input).why, isNotEmpty);
    }
  });

  test(
    'a step up always resets the reps to the bottom of the window or below the '
    'previous target',
    () {
      for (final input in sweep()) {
        final decision = suggester.suggest(input);
        if (decision.stepsMoved <= 0) continue;
        expect(
          decision.targetReps,
          lessThanOrEqualTo(input.range.max),
          reason:
              'double progression must not raise weight and reps together: '
              '$decision',
        );
        expect(
          decision.why,
          contains(ReasonCode.weightStep),
          reason: '$decision',
        );
      }
    },
  );

  test(
    'bodyweight-family suggestions are always BodyweightOnly, never a raw load',
    () {
      for (final input in sweep()) {
        final decision = suggester.suggest(input);
        if (input.profile.resistanceEquipment !=
            ResistanceEquipment.bodyweight) {
          continue;
        }
        expect(
          decision.suggestion,
          anyOf(isA<BodyweightOnly>(), isA<NeedsCalibration>()),
          reason: '$decision',
        );
      }
    },
  );
}
