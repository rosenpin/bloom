import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/plan_fixtures.dart';

void main() {
  final exercisesById = <String, Exercise>{
    for (final exercise in catalogV1.exercises) exercise.id: exercise,
  };
  test('EXERCISES.md has exactly 40 unique fixture rows', () {
    expect(catalogV1.exercises, hasLength(40));
    expect(exercisesById, hasLength(40));
  });

  test('rows 29 and 29b are signed assisted-stack compounds', () {
    final pullUp = exercisesById['bodyweight-assisted-chin-up']!;
    final dip = exercisesById['assisted-dip']!;
    expect(pullUp.name, 'Assisted Pull-Up');
    expect(pullUp.blockRole, BlockRole.upperPull);
    expect(pullUp.resistanceEquipment, ResistanceEquipment.assistedStack);
    expect(pullUp.bwContribution, 0.85);
    expect(dip.name, 'Assisted Dip');
    expect(dip.blockRole, BlockRole.upperPush);
    expect(dip.resistanceEquipment, ResistanceEquipment.assistedStack);
    expect(dip.bwContribution, 0.85);
    expect(
      catalogV1.swapEdges.any(
        (edge) => edge.fromId == 'assisted-dip' || edge.toId == 'assisted-dip',
      ),
      isTrue,
    );
  });

  test('no swap edge has a dangling from or to id', () {
    for (final edge in catalogV1.swapEdges) {
      expect(exercisesById, contains(edge.fromId), reason: '$edge');
      expect(exercisesById, contains(edge.toId), reason: '$edge');
      expect(exercisesById[edge.fromId]!.isRetired, isFalse, reason: '$edge');
      expect(exercisesById[edge.toId]!.isRetired, isFalse, reason: '$edge');
    }
  });

  test('swaps preserve region/session purpose', () {
    for (final edge in catalogV1.swapEdges) {
      final from = exercisesById[edge.fromId]!;
      final to = exercisesById[edge.toId]!;
      expect(
        to.blockRole.swapRegionPurpose,
        from.blockRole.swapRegionPurpose,
        reason: '$edge',
      );
    }
  });

  test('every edge has a valid three-tier tag', () {
    for (final edge in catalogV1.swapEdges) {
      expect(edge.tier, inInclusiveRange(1, 3), reason: '$edge');
    }
  });

  test('the six restored candidates carry the documented tiers', () {
    const expected = <String, int>{
      'barbell-deadlift->machine-leg-press': 2,
      'machine-back-extension->dumbbell-glute-bridge': 2,
      'machine-leg-extension->machine-leg-press': 3,
      'dumbbell-seated-overhead-press->dumbbell-lateral-raise': 3,
      'machine-leg-press->dumbbell-bulgarian-split-squat': 2,
      'dumbbell-row-unilateral->machine-seated-cable-row': 2,
    };
    final actual = <String, int>{
      for (final edge in catalogV1.swapEdges)
        if (expected.containsKey('${edge.fromId}->${edge.toId}'))
          '${edge.fromId}->${edge.toId}': edge.tier,
    };
    expect(actual, expected);
  });

  test('tier 3 is reserved for compound-isolation crossings', () {
    for (final edge in catalogV1.swapEdges.where((edge) => edge.tier == 3)) {
      final from = exercisesById[edge.fromId]!.movementClass;
      final to = exercisesById[edge.toId]!.movementClass;
      expect(
        from.isCompound && to.isIsolation || from.isIsolation && to.isCompound,
        isTrue,
        reason: '$edge',
      );
    }
  });

  test('assembly snapshots each swap target with its own dose', () {
    final plan = successfulPlan(
      const Profile(
        ageBand: AgeBand.age18To29,
        daysPerWeek: TrainingDaysPerWeek.three,
        sessionMinutes: SessionMinutes.fortyFive,
        goal: Goal.tonedAndDefined,
        emphasis: Emphasis.glutes,
        experienceTier: ProfileExperienceTier.newToIt,
        gymComfort: GymComfort.low,
        weeksTrained: 0,
        mesocycleIndex: 1,
      ),
      config: const ProgrammingConfig(
        machineAffinityNewToIt: 0,
        machineAffinityLowComfort: 0,
      ),
    );
    final shoulderPress = plan.days
        .expand((day) => day.exercises)
        .firstWhere(
          (exercise) => exercise.exerciseId == 'dumbbell-seated-overhead-press',
        );
    final lateralRaise = shoulderPress.orderedSwapCandidates.firstWhere(
      (candidate) =>
          candidate.exerciseId == 'dumbbell-lateral-raise' &&
          candidate.tier == 3,
    );
    expect(lateralRaise.repRange, const RepRange(10, 15));
    expect((lateralRaise.baseDose as RepsDose).range, const RepRange(10, 15));
  });

  test('swap ranks are unique per from id and tier', () {
    final ranks = <String, Set<int>>{};
    for (final edge in catalogV1.swapEdges) {
      final key = '${edge.fromId}/tier${edge.tier}';
      expect(
        (ranks[key] ??= <int>{}).add(edge.rank),
        isTrue,
        reason: '$key rank ${edge.rank}',
      );
    }
  });

  test('every exercise has a shown-by-default authored candidate', () {
    final missing = <String>[
      for (final exercise in catalogV1.exercises)
        if (!catalogV1.swapEdges.any(
          (edge) => edge.fromId == exercise.id && edge.tier <= 2,
        ))
          exercise.id,
    ];
    expect(missing, isEmpty);
  });

  test(
    'every launchable exercise has every required attribute and copy field',
    () {
      for (final exercise in catalogV1.exercises) {
        expect(exercise.id, isNotEmpty);
        expect(exercise.slug, isNotEmpty, reason: exercise.id);
        expect(exercise.name, isNotEmpty, reason: exercise.id);
        expect(exercise.bwContribution.isFinite, isTrue, reason: exercise.id);
        expect(
          exercise.bwContribution,
          inInclusiveRange(0, 1),
          reason: exercise.id,
        );
        expect(exercise.targetMuscles, isNotEmpty, reason: exercise.id);
        expect(exercise.primaryJointActions, isNotEmpty, reason: exercise.id);
        expect(exercise.romRank, inInclusiveRange(1, 5), reason: exercise.id);
        expect(
          exercise.stabilityRank,
          inInclusiveRange(1, 5),
          reason: exercise.id,
        );
        expect(exercise.setupSteps, hasLength(4), reason: exercise.id);
        expect(exercise.shouldFeel, isNotEmpty, reason: exercise.id);
        expect(exercise.stopIf, isNotEmpty, reason: exercise.id);
        expect(exercise.findIt, isNotEmpty, reason: exercise.id);
        expect(exercise.dos, isNotEmpty, reason: exercise.id);
        expect(exercise.donts, isNotEmpty, reason: exercise.id);
      }
    },
  );

  test('every rotating catalog role has at least two authored candidates', () {
    for (final role in catalogV1.rotatingBlockRoles) {
      expect(
        catalogV1.exercises
            .where((exercise) => exercise.blockRole == role)
            .length,
        greaterThanOrEqualTo(2),
        reason: role.name,
      );
    }
  });
}
