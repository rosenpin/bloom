/// `PROGRAMMING.md` §4 (and the §3 increment rules it generalises), encoded 1:1.
///
/// One row per rule, named after the rule it pins. A tuning change edits the config,
/// this table and nothing else — which is the point of having no snapshots here
/// (`ENGINE.md` › "Progression: no snapshots").
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// One rule of the spec, as a test case.
typedef Row = ({
  /// Test name: the spec clause, then what it requires.
  String rule,
  ProgressionInput input,
  ProgrammingConfig? config,

  /// Expected external load, or `null` to skip the check.
  Kg? load,
  int? reps,
  int? steps,
  ProgressionRegime regime,

  /// Reason codes that must be present.
  List<ReasonCode> why,

  /// Extra assertion on the whole decision, when a row needs one.
  void Function(LoadDecision)? also,
});

Row row({
  required String rule,
  required ProgressionInput input,
  required ProgressionRegime regime,
  ProgrammingConfig? config,
  Kg? load,
  int? reps,
  int? steps,
  List<ReasonCode> why = const [],
  void Function(LoadDecision)? also,
}) => (
  rule: rule,
  input: input,
  config: config,
  load: load,
  reps: reps,
  steps: steps,
  regime: regime,
  why: why,
  also: also,
);

void main() {
  // ── §4.1 Calibration regime ────────────────────────────────────────────────
  final calibration = <Row>[
    row(
      rule:
          '§4.1 reported ≤RPE4 jumps at least one equipment step, even when the '
          'formula asks for less than one pin',
      input: inputFor(
        legPress,
        range: compoundRange,
        lastLoad: const Kg(100),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.wayTooEasy,
      ),
      regime: ProgressionRegime.calibration,
      load: const Kg(105),
      reps: 10,
      steps: 1,
      why: [
        ReasonCode.calibrationRegimeJump,
        ReasonCode.calibrationMinimumStep,
        ReasonCode.weightStep,
        ReasonCode.repsReset,
      ],
    ),
    row(
      rule:
          '§4.1 on light dumbbells the two-step allowance is a permission, not a '
          'mandate: one step is what the formula asks for',
      input: inputFor(
        lateralRaise,
        range: isolationRange,
        lastLoad: const Kg(4),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.wayTooEasy,
      ),
      regime: ProgressionRegime.calibration,
      load: const Kg(6),
      reps: 8,
      steps: 1,
      why: [
        ReasonCode.calibrationRegimeJump,
        ReasonCode.calibrationMinimumStep,
      ],
    ),
    row(
      rule: '§4.1 calibration jumps stop at +15% / two steps',
      input: inputFor(
        legPress,
        range: compoundRange,
        lastLoad: const Kg(100),
        lastReps: 14,
        targetReps: 10,
        reported: EffortLevel.wayTooEasy,
      ),
      regime: ProgressionRegime.calibration,
      load: const Kg(110),
      reps: 10,
      steps: 2,
      why: [ReasonCode.calibrationRegimeJump, ReasonCode.cappedAtMaxChange],
    ),
  ];

  // ── §4.2 Normal-regime cap ─────────────────────────────────────────────────
  final normalCap = <Row>[
    row(
      rule: '§4.2 change capped at ±10% of effective load',
      input: inputFor(
        legPress,
        range: compoundRange,
        lastLoad: const Kg(100),
        lastReps: 14,
        targetReps: 10,
        reported: EffortLevel.aBitEasy,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(110),
      reps: 10,
      steps: 2,
      why: [
        ReasonCode.cappedAtMaxChange,
        ReasonCode.weightStep,
        ReasonCode.repsReset,
      ],
    ),
    row(
      rule:
          '§4.2 the cap is never tighter than one equipment step, so a step-up at '
          'a light absolute load is always allowed',
      input: inputFor(
        lateralRaise,
        range: isolationRange,
        lastLoad: const Kg(6),
        lastReps: 15,
        targetReps: 15,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(8),
      reps: 8,
      steps: 1,
      why: [ReasonCode.topOfRangeStepUp, ReasonCode.weightStep],
    ),
  ];

  // ── §4.3 Asymmetric down-rule ──────────────────────────────────────────────
  final downRule = <Row>[
    row(
      rule:
          '§4.3 harder than target at target reps holds — a novice reporting RPE 8 '
          'is probably over-reporting',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.harderThanIdLike,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(12),
      reps: 10,
      steps: 0,
      why: [ReasonCode.asymmetricDownRuleHold],
    ),
    row(
      rule: '§4.3 RPE ≥9 licenses a decrease',
      input: inputFor(
        lateralRaise,
        range: isolationRange,
        lastLoad: const Kg(6),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.tooHard,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(4),
      reps: 12,
      steps: -1,
      why: [ReasonCode.loadDecrease, ReasonCode.decreaseRoundedDown],
    ),
    row(
      rule:
          '§4.3 + §5 missing the target reps licenses a decrease, and the cap makes '
          'it §5\'s −10%',
      input: inputFor(
        legPress,
        range: compoundRange,
        lastLoad: const Kg(100),
        lastReps: 6,
        targetReps: 10,
        reported: EffortLevel.tooHard,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(90),
      reps: 10,
      steps: -2,
      why: [ReasonCode.cappedAtMaxChange, ReasonCode.loadDecrease],
    ),
    row(
      rule:
          '§4.3 a decrease on a high-bw movement is bounded in *effective* terms, '
          'which is two dumbbell steps of external load',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.tooHard,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(8),
      reps: 10,
      steps: -2,
      why: [ReasonCode.loadDecrease, ReasonCode.decreaseRoundedDown],
      also: (decision) {
        // −4 kg external on a 57.5 kg effective load is −7%, inside the ±10% cap.
        expect(decision.why, isNot(contains(ReasonCode.cappedAtMaxChange)));
      },
    ),
  ];

  // ── §4.4 Deadband ──────────────────────────────────────────────────────────
  final deadband = <Row>[
    row(
      rule:
          '§4.4 a computed change under the deadband is ignored, and the progress '
          'falls to reps',
      // One rep or RPE point is worth 2.0–2.9% in our rep ranges, so the shipped 2%
      // deadband almost never binds on integer inputs. Widened here to pin the
      // mechanism rather than the coincidence.
      config: const ProgrammingConfig(deadbandFraction: 0.05),
      input: inputFor(
        legPress,
        range: compoundRange,
        lastLoad: const Kg(100),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.aBitEasy,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(100),
      // Easier-than-target reports earn +2 reps ("+1-2" rule row); exactly-at-
      // target earns +1. Differentiates "a bit easy" from "just right".
      reps: 12,
      steps: 0,
      why: [ReasonCode.deadbandHold, ReasonCode.repsProgress],
    ),
  ];

  // ── §4.5 Discretization ────────────────────────────────────────────────────
  final discretization = <Row>[
    row(
      rule: '§4.5 an increment too small to be a step is spent on reps instead',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.aBitEasy,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(12),
      reps: 11,
      steps: 0,
      why: [ReasonCode.incrementTooSmallForStep, ReasonCode.repsProgress],
    ),
    row(
      rule:
          '§4.5 a load between steps rounds DOWN and adds ~1 rep per 3% shortfall',
      input: inputFor(
        legPress,
        range: compoundRange,
        lastLoad: const Kg(100),
        lastReps: 12,
        targetReps: 10,
        reported: EffortLevel.wayTooEasy,
      ),
      regime: ProgressionRegime.calibration,
      // Ideal is 109.3 kg; the stack can do 105 or 110, so 105 + one rep.
      load: const Kg(105),
      reps: 11,
      steps: 1,
      why: [
        ReasonCode.weightStep,
        ReasonCode.repsReset,
        ReasonCode.roundedDownAddedReps,
      ],
    ),
    row(
      rule:
          '§4.5 at the top of the rep window at target effort: one step up, reps '
          'reset to the bottom',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(14),
      reps: 10,
      steps: 1,
      why: [
        ReasonCode.topOfRangeStepUp,
        ReasonCode.weightStep,
        ReasonCode.repsReset,
      ],
    ),
  ];

  // ── §4.6 / §4.7 ────────────────────────────────────────────────────────────
  final feedbackRules = <Row>[
    row(
      rule: '§4.6 no feedback → repeat identical; silence is never permission',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 12,
        targetReps: 12,
      ),
      regime: ProgressionRegime.noFeedback,
      load: const Kg(12),
      reps: 12,
      steps: 0,
      why: [ReasonCode.noFeedbackHold],
    ),
    row(
      rule:
          '§4.7 "just right" still always moves — via reps when there is room',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(12),
      reps: 11,
      steps: 0,
      why: [ReasonCode.repsProgress],
    ),
  ];

  // ── §4.7 at effort targets other than RPE 7 ────────────────────────────────
  // Two of the four shipped goals target RPE 8 and one targets RPE 6, and the
  // easier week is just an easier target — so a non-7 target is the normal case,
  // not an edge case.
  final otherTargets = <Row>[
    row(
      rule:
          '§4.7 at a "Feel healthier" target (RPE 6) "just right" still moves: the '
          'tap is answered against the week\'s target, so it means "I hit what you '
          'asked for", not "RPE 7"',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        effort: const EffortTarget(6),
        lastLoad: const Kg(12),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(12),
      reps: 11,
      steps: 0,
      // The arithmetic wants a small decrease (she worked harder than the RPE 6
      // target); §4.3 holds the load and §4.7 spends the progress on reps.
      why: [ReasonCode.asymmetricDownRuleHold, ReasonCode.repsProgress],
    ),
    row(
      rule:
          '§4.7 at a RPE 6 target, "just right" at the top of the range still steps '
          'the weight up',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        effort: const EffortTarget(6),
        lastLoad: const Kg(12),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(14),
      reps: 10,
      steps: 1,
      why: [ReasonCode.topOfRangeStepUp, ReasonCode.weightStep],
    ),
    row(
      rule:
          '§4.3 at a "Stronger" target (RPE 8), "harder than I\'d like" holds both '
          'load and reps even though it is numerically on target — she just told us '
          'it was harder than she wanted',
      input: inputFor(
        gobletSquat,
        range: const RepRange(6, 8),
        effort: const EffortTarget(8),
        lastLoad: const Kg(12),
        lastReps: 8,
        targetReps: 8,
        reported: EffortLevel.harderThanIdLike,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(12),
      reps: 8,
      steps: 0,
    ),
    row(
      rule:
          '§4.5 at a RPE 8 target, "just right" is *easier* than target, so the '
          'weight moves at the top of the range',
      input: inputFor(
        gobletSquat,
        range: const RepRange(6, 8),
        effort: const EffortTarget(8),
        lastLoad: const Kg(12),
        lastReps: 8,
        targetReps: 8,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(14),
      reps: 6,
      steps: 1,
      why: [
        ReasonCode.topOfRangeStepUp,
        ReasonCode.weightStep,
        ReasonCode.repsReset,
      ],
    ),
  ];

  // ── §4 Cold start, bodyweight and timed ────────────────────────────────────
  final coldStartAndMetrics = <Row>[
    row(
      rule:
          '§4 cold start: first exposure to an exercise goes through the §7 probe '
          'at the equipment floor, 8 reps',
      input: inputFor(gobletSquat, range: compoundRange, noHistory: true),
      regime: ProgressionRegime.firstExposure,
      load: const Kg(2),
      reps: 8,
      why: [ReasonCode.firstExposure],
      also: (decision) => expect(
        decision.suggestion,
        const NeedsCalibration(floor: Kg(2), probeReps: 8),
      ),
    ),
    row(
      rule: '§4 bodyweight movements resolve to a rep target, not a load',
      input: inputFor(
        pushUp,
        range: const RepRange(8, 15),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.repsOnly,
      reps: 11,
      why: [ReasonCode.bodyweightRepProgress],
      also: (decision) =>
          expect(decision.suggestion, const RepOrDurationTarget.reps(11)),
    ),
    row(
      rule: '§4 timed movements resolve to a hold duration',
      input: inputFor(
        plank,
        range: const RepRange(1, 1),
        lastHold: const Duration(seconds: 30),
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.timed,
      why: [ReasonCode.timedHoldProgress],
      also: (decision) => expect(decision.hold, const Duration(seconds: 35)),
    ),
    row(
      rule:
          '§3 bodyweight: at the top of the window, add a variation rather than '
          'more reps',
      input: inputFor(
        pushUp,
        range: const RepRange(8, 15),
        lastReps: 15,
        targetReps: 15,
        reported: EffortLevel.wayTooEasy,
      ),
      regime: ProgressionRegime.repsOnly,
      reps: 15,
      why: [ReasonCode.variationDue],
    ),
  ];

  // ── §3 Weight increments, one step per equipment family ────────────────────
  final increments = <Row>[
    row(
      rule: '§3 dumbbells step to the next pair up (+2 kg, metric)',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(14),
      steps: 1,
      why: [ReasonCode.weightStep],
    ),
    row(
      rule: '§3 barbell upper body steps +2.5 kg total',
      input: inputFor(
        barbellBench,
        range: compoundRange,
        lastLoad: const Kg(40),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(42.5),
      steps: 1,
      why: [ReasonCode.weightStep],
    ),
    row(
      rule: '§3 barbell lower body steps +5 kg total',
      input: inputFor(
        barbellSquat,
        range: compoundRange,
        lastLoad: const Kg(40),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(45),
      steps: 1,
      why: [ReasonCode.weightStep],
    ),
    row(
      rule: '§3 cables step one pin (2.5 kg, metric)',
      input: inputFor(
        cablePushdown,
        range: isolationRange,
        lastLoad: const Kg(15),
        lastReps: 15,
        targetReps: 15,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(17.5),
      reps: 8,
      steps: 1,
      why: [ReasonCode.topOfRangeStepUp],
    ),
    row(
      rule: '§3 a per-exercise pin size overrides the family default',
      input: inputFor(
        hipAbduction,
        range: isolationRange,
        lastLoad: const Kg(20),
        lastReps: 15,
        targetReps: 15,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(22.5),
      steps: 1,
      why: [ReasonCode.weightStep],
    ),
  ];

  // ── Assisted stack: signed negative external load ─────────────────────────
  final assistedStack = <Row>[
    row(
      rule: 'assisted stack: one progression step is +5 kg (less assistance)',
      input: inputFor(
        assistedPullUp,
        range: compoundRange,
        lastLoad: const Kg(-30),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(-25),
      reps: 10,
      steps: 1,
      why: [ReasonCode.topOfRangeStepUp, ReasonCode.weightStep],
    ),
    row(
      rule: 'assisted stack: a licensed decrease adds one assistance pin',
      input: inputFor(
        assistedPullUp,
        range: compoundRange,
        lastLoad: const Kg(-25),
        lastReps: 6,
        targetReps: 10,
        reported: EffortLevel.tooHard,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(-30),
      reps: 10,
      steps: -1,
      why: [ReasonCode.loadDecrease, ReasonCode.decreaseRoundedDown],
    ),
    row(
      rule: 'lb assisted stack: one progression step is +10 lb toward zero',
      input: inputFor(
        assistedPullUp,
        range: compoundRange,
        unitSystem: UnitSystem.imperial,
        lastLoad: Kg(-60 * kgPerLb),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: Kg(-50 * kgPerLb),
      reps: 10,
      steps: 1,
      why: [ReasonCode.topOfRangeStepUp, ReasonCode.weightStep],
      also: (decision) =>
          expect(decision.externalLoad!.inLb, closeTo(-50, 1e-9)),
    ),
  ];

  // ── §3 Isolation and single-side work: wide range, bridged jumps ───────────
  final isolationRules = <Row>[
    row(
      rule: '§3.2 isolation adds reps session to session, up to 15',
      input: inputFor(
        lateralRaise,
        range: isolationRange,
        lastLoad: const Kg(6),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(6),
      reps: 13,
      steps: 0,
      why: [ReasonCode.repsProgress],
    ),
    row(
      rule:
          '§3.3 at 15 reps she is overdue: increase the weight and restart at 8',
      input: inputFor(
        lateralRaise,
        range: isolationRange,
        lastLoad: const Kg(6),
        lastReps: 15,
        targetReps: 15,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(8),
      reps: 8,
      steps: 1,
      why: [ReasonCode.topOfRangeStepUp, ReasonCode.repsReset],
    ),
    row(
      rule:
          '§3.4 a jump on isolation work offers the drop-set bridge back to the old '
          'weight for 4–5 reps',
      input: inputFor(
        lateralRaise,
        range: isolationRange,
        lastLoad: const Kg(6),
        lastReps: 15,
        targetReps: 15,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      why: [ReasonCode.dropBridgeOffered],
      also: (decision) => expect(
        decision.bridge,
        const DropSetBridge(
          backOffLoad: Kg(6),
          backOffRepsMin: 4,
          backOffRepsMax: 5,
        ),
      ),
    ),
    row(
      rule: '§3 single-side work takes the same wide range and bridged jumps',
      input: inputFor(
        singleArmRow,
        range: isolationRange,
        lastLoad: const Kg(10),
        lastReps: 15,
        targetReps: 15,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(12),
      reps: 8,
      steps: 1,
      why: [ReasonCode.topOfRangeStepUp, ReasonCode.dropBridgeOffered],
    ),
  ];

  // ── Markets: the same rules on a 5 lb ladder ───────────────────────────────
  final lbMarket = <Row>[
    row(
      rule: 'lb market: dumbbells step 5 lb, so 25 lb → 30 lb',
      input: inputFor(
        dumbbellBench,
        range: compoundRange,
        unitSystem: UnitSystem.imperial,
        lastLoad: Kg(25 * kgPerLb),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: Kg(30 * kgPerLb),
      reps: 10,
      steps: 1,
      why: [ReasonCode.topOfRangeStepUp],
      also: (decision) =>
          expect(decision.externalLoad!.inLb, closeTo(30, 1e-9)),
    ),
    row(
      rule: 'lb market: the calibration-regime minimum step is one 5 lb rung',
      input: inputFor(
        lateralRaise,
        range: isolationRange,
        unitSystem: UnitSystem.imperial,
        lastLoad: Kg(10 * kgPerLb),
        lastReps: 10,
        targetReps: 10,
        reported: EffortLevel.wayTooEasy,
      ),
      regime: ProgressionRegime.calibration,
      load: Kg(15 * kgPerLb),
      reps: 8,
      steps: 1,
      why: [ReasonCode.calibrationMinimumStep],
    ),
    row(
      rule: 'lb market: barbell lower body steps 10 lb from a 45 lb bar',
      input: inputFor(
        barbellSquat,
        range: compoundRange,
        unitSystem: UnitSystem.imperial,
        lastLoad: Kg(95 * kgPerLb),
        lastReps: 12,
        targetReps: 12,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: Kg(105 * kgPerLb),
      steps: 1,
      why: [ReasonCode.weightStep],
    ),
  ];

  // ── bw_contribution: the same +2 kg means different things ─────────────────
  final effectiveLoadRules = <Row>[
    row(
      rule:
          'ENGINE.md effective load: a 70 kg user on a goblet squat is guarded on '
          '57.5 kg of load moved, not 12 kg',
      input: inputFor(
        gobletSquat,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 14,
        targetReps: 10,
        reported: EffortLevel.wayTooEasy,
      ),
      regime: ProgressionRegime.calibration,
      // Ideal 57.5 × 49/43 = 65.5 kg effective (+8.0 kg), capped to two dumbbell
      // steps: 16 kg external. On the same numbers with bw 0 the cap would be
      // ±10% of 12 kg = 1.2 kg, i.e. one step at most.
      load: const Kg(16),
      reps: 10,
      steps: 2,
      why: [ReasonCode.cappedAtMaxChange, ReasonCode.weightStep],
    ),
    row(
      rule:
          'ENGINE.md effective load: bodyweight movements that take added load '
          'report the added load only',
      input: inputFor(
        gluteBridgeAdded,
        range: isolationRange,
        lastLoad: const Kg(10),
        lastReps: 15,
        targetReps: 15,
        reported: EffortLevel.justRight,
      ),
      regime: ProgressionRegime.normal,
      load: const Kg(12),
      steps: 1,
      why: [ReasonCode.weightStep],
      also: (decision) =>
          expect(decision.suggestion, const BodyweightOnly(added: Kg(12))),
    ),
  ];

  final sections = <String, List<Row>>{
    '§4.1 calibration regime': calibration,
    '§4.2 normal-regime cap': normalCap,
    '§4.3 asymmetric down-rule': downRule,
    '§4.4 deadband': deadband,
    '§4.5 discretization': discretization,
    '§4.6–§4.7 feedback rules': feedbackRules,
    '§4.7 at other effort targets': otherTargets,
    '§4 cold start, bodyweight and timed': coldStartAndMetrics,
    '§3 weight increments': increments,
    'assisted-stack signed progression': assistedStack,
    '§3 isolation and single-side work': isolationRules,
    '§3 lb market': lbMarket,
    'effective load (bw_contribution)': effectiveLoadRules,
  };

  sections.forEach((section, rows) {
    group(section, () {
      for (final testRow in rows) {
        test(testRow.rule, () {
          final decision = LoadSuggester(
            testRow.config ?? config,
          ).suggest(testRow.input);
          expect(decision.regime, testRow.regime, reason: 'regime: $decision');
          if (testRow.load != null) {
            expect(
              decision.externalLoad?.value,
              closeTo(testRow.load!.value, 1e-9),
              reason: 'load: $decision',
            );
          }
          if (testRow.reps != null) {
            expect(
              decision.targetReps,
              testRow.reps,
              reason: 'reps: $decision',
            );
          }
          if (testRow.steps != null) {
            expect(
              decision.stepsMoved,
              testRow.steps,
              reason: 'steps: $decision',
            );
          }
          expect(
            decision.why,
            containsAll(testRow.why),
            reason: 'why: $decision',
          );
          expect(decision.warnings, isEmpty, reason: 'warnings: $decision');
          testRow.also?.call(decision);
        });
      }
    });
  });
}
