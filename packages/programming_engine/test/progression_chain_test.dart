/// Chained decisions: the suggester fed back into itself, session after session.
///
/// `PROGRAMMING.md` "Standing rule" pins one behavioural number on these guardrails:
/// a novice squat with honest "too easy" reports must reach **≥+20% working load by
/// week 4**. The guardrails are all conservative individually, so the only way to
/// know they don't stack into a stall is to run the trajectory.
///
/// This is not `ENGINE.md`'s journey golden — that needs `resolveSession` and comes
/// with step 5. It chains one exercise's load decisions and asserts the shape.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Feeds each decision back as the next session's history, the way
/// `resolveSession` will.
final class Chain {
  Chain({
    required this.exercise,
    required this.range,
    required Kg startLoad,
    this.effort = EffortTarget.rpe7,
    this.bodyMass = referenceBodyMass,
    this.unitSystem = UnitSystem.metric,
    int? startReps,
  })  : load = startLoad,
        targetReps = startReps ?? range.min;

  final ExerciseData exercise;
  final RepRange range;
  final EffortTarget effort;
  final Kg bodyMass;
  final UnitSystem unitSystem;

  Kg load;
  int targetReps;

  final List<LoadDecision> decisions = <LoadDecision>[];

  /// Readable trajectory, for failure messages and for reading the shape by eye.
  List<String> get trajectory =>
      decisions.map((d) => '${d.externalLoad?.value}kg x ${d.targetReps}').toList();

  List<Kg> get loads =>
      decisions.map((d) => d.externalLoad ?? Kg.zero).toList(growable: false);

  /// One session: she does [repsDone] reps (her target, unless told otherwise) and
  /// taps [tap]. Returns what the engine prescribes next.
  LoadDecision session({EffortLevel? tap, int? repsDone, int daysSince = 2}) {
    final decision = suggester.suggest(ProgressionInput(
      profile: exercise,
      range: range,
      effort: effort,
      unitSystem: unitSystem,
      bodyMass: bodyMass,
      daysSinceLastSession: daysSince,
      history: ExerciseSnapshot(
        lastLoad: load,
        lastReps: repsDone ?? targetReps,
        targetReps: targetReps,
        reportedEffort: tap,
      ),
    ));
    load = decision.externalLoad ?? load;
    targetReps = decision.targetReps;
    decisions.add(decision);
    return decision;
  }

  void run(List<EffortLevel?> taps) {
    for (final tap in taps) {
      session(tap: tap);
    }
  }
}

void main() {
  test('the golden trajectory: a novice squat with honest "too easy" reports gains '
      '≥20% working load by week 4', () {
    // She starts at the empty bar — where §7's probe starts a true novice — with the
    // novice-capped scheme (3 sets, RPE 7, 10–12 reps) and trains 3 times a week.
    final chain = Chain(
      exercise: barbellSquat,
      range: compoundRange,
      startLoad: config.loadTable(UnitSystem.metric).barbellBar,
    );

    // Honest reports, decelerating as the bar gets heavy — she stops calling it
    // "way too easy" once it isn't.
    chain.run(<EffortLevel?>[
      ...List.filled(6, EffortLevel.wayTooEasy),
      ...List.filled(3, EffortLevel.aBitEasy),
      ...List.filled(3, EffortLevel.justRight),
    ]);

    expect(chain.decisions, hasLength(12));
    final start = config.loadTable(UnitSystem.metric).barbellBar;
    final finish = chain.load;
    expect(
      finish.value,
      greaterThanOrEqualTo(start.value * 1.20),
      reason: 'the guardrails must never prevent the fast-early-compound '
          'trajectory. Trajectory: ${chain.trajectory}',
    );
    // For the record, so a tuning change that quietly halves the trajectory shows up
    // in review rather than in a support ticket.
    expect(chain.trajectory.last, '60.0kg x 10');
  });

  test('the same trajectory never moves more than two steps in one session and never '
      'goes backwards on easier-than-target reports', () {
    final chain = Chain(
      exercise: barbellSquat,
      range: compoundRange,
      startLoad: const Kg(20),
    )..run(<EffortLevel?>[
        ...List.filled(6, EffortLevel.wayTooEasy),
        ...List.filled(6, EffortLevel.aBitEasy),
      ]);

    for (final decision in chain.decisions) {
      expect(decision.stepsMoved, inInclusiveRange(0, 2), reason: '$decision');
      expect(decision.warnings, isEmpty, reason: '$decision');
    }
    for (var i = 1; i < chain.loads.length; i++) {
      expect(
        chain.loads[i] >= chain.loads[i - 1],
        isTrue,
        reason: 'trajectory went backwards: ${chain.trajectory}',
      );
    }
  });

  test('§3 the isolation ladder: reps climb 10→15, then the weight steps and reps '
      'restart at 8 with a bridge offered', () {
    final chain = Chain(
      exercise: lateralRaise,
      range: isolationRange,
      startLoad: const Kg(4),
      bodyMass: referenceBodyMass,
    )..run(List<EffortLevel?>.filled(10, EffortLevel.justRight));

    expect(chain.trajectory, <String>[
      '4.0kg x 11',
      '4.0kg x 12',
      '4.0kg x 13',
      '4.0kg x 14',
      '4.0kg x 15',
      '6.0kg x 8', // overdue at 15: +1 step, restart at 8
      '6.0kg x 9',
      '6.0kg x 10',
      '6.0kg x 11',
      '6.0kg x 12',
    ]);
    final theJump = chain.decisions[5];
    expect(theJump.bridge, isA<DropSetBridge>());
    expect((theJump.bridge! as DropSetBridge).backOffLoad, const Kg(4));
    expect(theJump.why, contains(ReasonCode.topOfRangeStepUp));
    // The 8-rep restart sits below the 10–15 range on purpose (§3.3) and must not
    // read as corrupt data on the next session.
    for (final decision in chain.decisions) {
      expect(decision.warnings, isEmpty, reason: '$decision');
    }
  });

  test('§4.6 silence changes nothing, however long it goes on', () {
    final chain = Chain(
      exercise: gobletSquat,
      range: compoundRange,
      startLoad: const Kg(12),
    )..run(<EffortLevel?>[null, null, null, null]);

    expect(chain.trajectory, List<String>.filled(4, '12.0kg x 10'));
  });

  group('§6 a layoff inside a trajectory', () {
    test('a fortnight off eases her back, then progression resumes', () {
      final chain = Chain(
        exercise: gobletSquat,
        range: compoundRange,
        startLoad: const Kg(12),
      )..run(List<EffortLevel?>.filled(3, EffortLevel.justRight));
      expect(chain.load, const Kg(14), reason: '${chain.trajectory}');

      final backAfterTwoWeeks =
          chain.session(tap: EffortLevel.justRight, daysSince: 16);
      expect(backAfterTwoWeeks.why, contains(ReasonCode.layoffTier2));
      expect(chain.load, const Kg(12), reason: '14 kg × 0.9 → the 12 kg dumbbells');

      final next = chain.session(tap: EffortLevel.justRight);
      expect(next.regime, ProgressionRegime.normal);
      expect(next.why, contains(ReasonCode.repsProgress));
    });

    test('28+ days re-probes the compound, and converting the probe target back to '
        'the working window is resolveSession\'s job — feeding the probe reps '
        'straight back is flagged, not silently prescribed', () {
      final chain = Chain(
        exercise: gobletSquat,
        range: compoundRange,
        startLoad: const Kg(14),
      );

      final back = chain.session(tap: EffortLevel.justRight, daysSince: 45);
      expect(back.suggestion, isA<NeedsCalibration>());
      expect(back.targetReps, config.calibrationProbeReps, reason: '8-rep probe');
      expect(back.warnings, isEmpty);

      // The probe's 8 reps are not a working target in a 10–12 window. If a caller
      // feeds them back anyway, the engine clamps and says so rather than
      // prescribing 8 reps of a 10–12 exercise.
      final naive = chain.session(tap: EffortLevel.justRight);
      expect(
        naive.warnings.map((w) => w.code),
        contains(WarningCode.targetRepsOutOfRange),
      );
      expect(naive.targetReps, greaterThanOrEqualTo(compoundRange.min));
    });
  });

  test('a "Feel healthier" trajectory (RPE 6) progresses instead of stalling', () {
    final chain = Chain(
      exercise: gobletSquat,
      range: compoundRange,
      effort: const EffortTarget(6),
      startLoad: const Kg(12),
    )..run(List<EffortLevel?>.filled(6, EffortLevel.justRight));

    expect(chain.trajectory, <String>[
      '12.0kg x 11',
      '12.0kg x 12',
      '14.0kg x 10',
      '14.0kg x 11',
      '14.0kg x 12',
      '16.0kg x 10',
    ]);
  });

  test('a lb-market trajectory stays on 5 lb dumbbells throughout', () {
    final chain = Chain(
      exercise: dumbbellBench,
      range: compoundRange,
      startLoad: Kg(20 * kgPerLb),
      unitSystem: UnitSystem.imperial,
    )..run(List<EffortLevel?>.filled(6, EffortLevel.justRight));

    final pounds = chain.loads.map((load) => load.inLb.round()).toList();
    expect(pounds, <int>[20, 20, 25, 25, 25, 30]);
    for (final load in chain.loads) {
      expect(
        config.availableLoads(dumbbellBench, UnitSystem.imperial).isRepresentable(load),
        isTrue,
      );
    }
  });
}
