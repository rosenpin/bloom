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

  test(
    'cross-pattern edges are never top-ranked when a preserving edge exists',
    () {
      final grouped = <String, List<SwapEdge>>{};
      for (final edge in catalogV1.swapEdges) {
        (grouped['${edge.fromId}/${edge.reason.name}'] ??= <SwapEdge>[]).add(
          edge,
        );
      }
      for (final entry in grouped.entries) {
        final preserving = entry.value.where(
          (edge) =>
              edge.patternRelation == SwapPatternRelation.patternPreserving,
        );
        if (preserving.isEmpty) continue;
        final firstPreserving = preserving
            .map((edge) => edge.rank)
            .reduce((left, right) => left < right ? left : right);
        for (final edge in entry.value.where(
          (edge) => edge.patternRelation == SwapPatternRelation.crossPattern,
        )) {
          expect(
            edge.rank,
            greaterThan(firstPreserving),
            reason: '${entry.key}: $edge',
          );
        }
      }
    },
  );

  test('the six revised cross-pattern candidates are restored and tagged', () {
    const expected = <String>{
      'barbell-deadlift->machine-leg-press',
      'machine-back-extension->dumbbell-glute-bridge',
      'machine-leg-extension->machine-leg-press',
      'dumbbell-seated-overhead-press->dumbbell-lateral-raise',
      'machine-leg-press->dumbbell-bulgarian-split-squat',
      'dumbbell-row-unilateral->machine-seated-cable-row',
    };
    final actual = catalogV1.swapEdges
        .where(
          (edge) => edge.patternRelation == SwapPatternRelation.crossPattern,
        )
        .map((edge) => '${edge.fromId}->${edge.toId}')
        .toSet();
    expect(actual, expected);
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
    );
    final shoulderPress = plan.days
        .expand((day) => day.exercises)
        .firstWhere(
          (exercise) => exercise.exerciseId == 'dumbbell-seated-overhead-press',
        );
    final lateralRaise = shoulderPress.orderedSwapCandidates.firstWhere(
      (candidate) =>
          candidate.exerciseId == 'dumbbell-lateral-raise' &&
          candidate.patternRelation == SwapPatternRelation.crossPattern,
    );
    expect(lateralRaise.repRange, const RepRange(10, 15));
    expect(
      (lateralRaise.doseFor(MesocycleWeekKind.build)! as RepsDose).range,
      const RepRange(10, 15),
    );
  });

  test('swap ranks are unique per from id and reason', () {
    final ranks = <String, Set<int>>{};
    for (final edge in catalogV1.swapEdges) {
      final key = '${edge.fromId}/${edge.reason.name}';
      expect(
        (ranks[key] ??= <int>{}).add(edge.rank),
        isTrue,
        reason: '$key rank ${edge.rank}',
      );
    }
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
