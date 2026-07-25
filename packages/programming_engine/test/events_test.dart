/// The event vocabulary — value semantics and exhaustiveness.
///
/// `ENGINE.md`: the append-only log is the single source of truth and the one schema
/// that can't be cheaply migrated, so it is worth pinning that these are plain
/// immutable values that compare structurally and switch exhaustively.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

/// Exhaustive over the sealed hierarchy: adding a case to `SessionEvent` breaks
/// compilation here, which is the point.
String describe(SessionEvent event) => switch (event) {
      SetCompleted(:final exerciseId, :final reps) => 'set:$exerciseId:$reps',
      EffortReported(:final level) => 'effort:${level.value}',
      SwapRequested(:final reason) => 'swap:${reason.name}',
      Shorten(:final minutes) => 'shorten:$minutes',
      LowEnergy() => 'lowEnergy',
      PainReported(:final site) => 'pain:${site.name}',
      SessionAbandoned() => 'abandoned',
    };

void main() {
  const events = <SessionEvent>[
    SetCompleted(
      exerciseId: 'dumbbell-goblet-squat',
      setIndex: 2,
      load: Kg(12),
      reps: 11,
      unitSystem: UnitSystem.metric,
    ),
    EffortReported(
      exerciseId: 'dumbbell-goblet-squat',
      level: EffortLevel.justRight,
    ),
    SwapRequested(exerciseId: 'barbell-squat', reason: SwapReason.intimidating),
    Shorten(20),
    LowEnergy(),
    PainReported(exerciseId: 'machine-leg-extension', site: PainSite.knee),
    SessionAbandoned(),
  ];

  test('every event is const-constructible', () {
    expect(events, hasLength(7));
  });

  test('every event compares structurally', () {
    for (final event in events) {
      expect(event == event, isTrue);
    }
    expect(
      const SetCompleted(
        exerciseId: 'a',
        setIndex: 0,
        load: Kg(10),
        reps: 8,
        unitSystem: UnitSystem.imperial,
      ),
      const SetCompleted(
        exerciseId: 'a',
        setIndex: 0,
        load: Kg(10),
        reps: 8,
        unitSystem: UnitSystem.imperial,
      ),
    );
    expect(
      const SetCompleted(
            exerciseId: 'a',
            setIndex: 0,
            load: Kg(10),
            reps: 8,
            unitSystem: UnitSystem.imperial,
          ) ==
          const SetCompleted(
            exerciseId: 'a',
            setIndex: 0,
            load: Kg(10),
            reps: 8,
            unitSystem: UnitSystem.metric,
          ),
      isFalse,
      reason: 'the unit system in force at entry is part of the event',
    );
    expect(const LowEnergy(), const LowEnergy());
    expect(const SessionAbandoned() == const LowEnergy(), isFalse);
  });

  test('equal events hash equally, so a log can be de-duplicated', () {
    final seen = <SessionEvent>{...events, ...events};
    expect(seen, hasLength(events.length));
  });

  test('the sealed hierarchy switches exhaustively', () {
    expect(events.map(describe).toList(), <String>[
      'set:dumbbell-goblet-squat:11',
      'effort:3',
      'swap:intimidating',
      'shorten:20',
      'lowEnergy',
      'pain:knee',
      'abandoned',
    ]);
  });

  test('every swap reason and pain site is representable', () {
    expect(SwapReason.values.map((r) => r.name), <String>[
      'busy',
      'intimidating',
      'uncomfortable',
      'unavailable',
    ]);
    expect(PainSite.values, isNotEmpty);
    for (final site in PainSite.values) {
      expect(describe(PainReported(exerciseId: 'x', site: site)), startsWith('pain:'));
    }
  });

  test('an event prints readably for a support replay', () {
    expect(
      describe(events.first),
      'set:dumbbell-goblet-squat:11',
    );
    expect(events.first.toString(), contains('12.0kg x 11'));
    expect(const LowEnergy().toString(), 'LowEnergy()');
  });

  group('the resolved prescription', () {
    test('carries the dose, the suggestion, laterality, the bridge and the why', () {
      const prescription = ExercisePrescription(
        exerciseId: 'dumbbell-lateral-raise',
        dose: RepsDose(
          sets: 3,
          range: RepRange(10, 15),
          effort: EffortTarget.rpe7,
          targetReps: 8,
        ),
        suggestion: SuggestedLoad(Kg(6)),
        laterality: Laterality.bilateral,
        bridge: DropSetBridge(
          backOffLoad: Kg(4),
          backOffRepsMin: 4,
          backOffRepsMax: 5,
        ),
        why: [ReasonCode.topOfRangeStepUp, ReasonCode.repsReset],
      );
      expect(prescription.dose, isA<RepsDose>());
      expect(prescription.why, hasLength(2));
      expect(prescription.toString(), contains('lateral-raise'));
    });

    test('compares structurally, reason codes included', () {
      const one = ExercisePrescription(
        exerciseId: 'x',
        dose: TimedDose(sets: 3, hold: Duration(seconds: 30)),
        suggestion: BodyweightOnly(),
        laterality: Laterality.perSide,
        why: [ReasonCode.timedHoldProgress],
      );
      const same = ExercisePrescription(
        exerciseId: 'x',
        dose: TimedDose(sets: 3, hold: Duration(seconds: 30)),
        suggestion: BodyweightOnly(),
        laterality: Laterality.perSide,
        why: [ReasonCode.timedHoldProgress],
      );
      const differentWhy = ExercisePrescription(
        exerciseId: 'x',
        dose: TimedDose(sets: 3, hold: Duration(seconds: 30)),
        suggestion: BodyweightOnly(),
        laterality: Laterality.perSide,
        why: [ReasonCode.variationDue],
      );
      expect(one, same);
      expect(one.hashCode, same.hashCode);
      expect(one == differentWhy, isFalse);
    });

    test('a load suggestion is a closed set, so every consumer must handle '
        'NeedsCalibration', () {
      const suggestions = <LoadSuggestion>[
        SuggestedLoad(Kg(12)),
        BodyweightOnly(added: Kg(5)),
        NeedsCalibration(floor: Kg(2), probeReps: 8),
        RepOrDurationTarget.reps(12),
        RepOrDurationTarget.hold(Duration(seconds: 45)),
      ];
      final rendered = suggestions.map((suggestion) => switch (suggestion) {
            SuggestedLoad(:final kg) => 'try ${kg.value}kg',
            BodyweightOnly(:final added) =>
              added.isZero ? 'bodyweight' : 'bodyweight +${added.value}kg',
            NeedsCalibration(:final floor) => 'find it from ${floor.value}kg',
            RepOrDurationTarget(isTimed: true, :final hold) => 'hold ${hold!.inSeconds}s',
            RepOrDurationTarget(:final reps) => '$reps reps',
          });
      expect(rendered, <String>[
        'try 12.0kg',
        'bodyweight +5.0kg',
        'find it from 2.0kg',
        '12 reps',
        'hold 45s',
      ]);
    });
  });

  group('the dose', () {
    test('a rep range knows its own ends', () {
      const range = RepRange(10, 12);
      expect(range.contains(11), isTrue);
      expect(range.isTop(12), isTrue);
      expect(range.isBottom(10), isTrue);
      expect(range.clamp(99), 12);
      expect(range.span, 2);
      expect(range.toString(), '10-12');
    });

    test('doses compare structurally and copy cleanly', () {
      const dose = RepsDose(
        sets: 3,
        range: RepRange(10, 12),
        effort: EffortTarget.rpe7,
        targetReps: 10,
      );
      expect(dose.copyWith(targetReps: 11).targetReps, 11);
      expect(dose.copyWith(), dose);
      expect(
        const TimedDose(sets: 3, hold: Duration(seconds: 30))
            .copyWith(hold: const Duration(seconds: 35)),
        const TimedDose(sets: 3, hold: Duration(seconds: 35)),
      );
    });
  });

  group('the content interfaces', () {
    test('mirror the EXERCISES.md schema', () {
      const goblet = ExerciseData(
        id: 'dumbbell-goblet-squat',
        slug: 'dumbbell-goblet-squat',
        name: 'Goblet Squat',
        blockRole: BlockRole.lowerSquat,
        movementClass: MovementClass.compoundLower,
        metricType: MetricType.loadReps,
        resistanceEquipment: ResistanceEquipment.dumbbell,
        bwContribution: 0.65,
        targetMuscles: [
          MuscleTarget.primary(MuscleGroup.quads),
          MuscleTarget.primary(MuscleGroup.glutes),
          MuscleTarget.secondary(MuscleGroup.core),
        ],
        primaryJointActions: [JointAction.kneeExtension, JointAction.hipExtension],
        secondaryJointActions: [JointAction.trunkBrace, JointAction.grip],
        romRank: 4,
        stabilityRank: 3,
        difficultyTier: DifficultyTier.beginner,
        minExperience: ExperienceTier.neverTrained,
        setupSteps: ['Take a dumbbell', 'Hold it at your chest'],
        shouldFeel: 'Quads and glutes working, chest tall',
        stopIf: 'Sharp knee pain',
        findIt: 'The dumbbell rack, any open floor space',
        dos: ['Keep your chest up'],
        donts: ['Let the dumbbell drift away from your body'],
      );
      expect(goblet.primaryMuscles, <MuscleGroup>[MuscleGroup.quads, MuscleGroup.glutes]);
      expect(goblet.isRetired, isFalse);
      expect(goblet.movementClass.isCompound, isTrue);
      expect(goblet.movementClass.isLowerBody, isTrue);
      expect(goblet.blockRole.isPrimary, isTrue);
      expect(goblet.metricType.hasLoad, isTrue);
      expect(goblet.laterality.isPerSide, isFalse);
    });

    test('a retired exercise is tombstoned, never deleted', () {
      final retired = ExerciseData(
        id: 'smith-machine-squat',
        name: 'Smith Machine Squat',
        blockRole: BlockRole.lowerSquat,
        movementClass: MovementClass.compoundLower,
        metricType: MetricType.loadReps,
        resistanceEquipment: ResistanceEquipment.machine,
        bwContribution: 0.5,
        retiredAt: DateTime.utc(2026, 7, 25),
      );
      expect(retired.isRetired, isTrue);
    });

    test('swap edges are ranked and comparable', () {
      const edge = SwapEdge(
        fromId: 'barbell-squat',
        toId: 'dumbbell-goblet-squat',
        reason: SwapReason.intimidating,
        rank: 0,
      );
      expect(
        edge,
        const SwapEdge(
          fromId: 'barbell-squat',
          toId: 'dumbbell-goblet-squat',
          reason: SwapReason.intimidating,
          rank: 0,
        ),
      );
      expect(edge.toString(), contains('#0'));
    });

    test('block roles know which ones "shorten today" may drop', () {
      expect(BlockRole.lowerSquat.isPrimary, isTrue);
      expect(BlockRole.gluteIsolation.isPrimary, isFalse);
      expect(BlockRole.gluteIsolation.isIsolation, isTrue);
      expect(BlockRole.finisherCardio.isPrimary, isFalse);
    });
  });

  test('an engine warning prints its code and detail', () {
    expect(
      const EngineWarning(WarningCode.invalidReps, '-3').toString(),
      'EngineWarning(invalidReps: -3)',
    );
    expect(
      const EngineWarning(WarningCode.invalidReps),
      const EngineWarning(WarningCode.invalidReps),
    );
  });
}
