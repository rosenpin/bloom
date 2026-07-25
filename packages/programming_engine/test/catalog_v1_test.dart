import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

void main() {
  final exercisesById = <String, Exercise>{
    for (final exercise in catalogV1.exercises) exercise.id: exercise,
  };
  const config = ProgrammingConfig();
  final compatibilityScheme = config.schemeFor(Goal.tonedAndDefined);

  test('EXERCISES.md has exactly 39 unique fixture rows', () {
    expect(catalogV1.exercises, hasLength(39));
    expect(exercisesById, hasLength(39));
  });

  test('no swap edge has a dangling from or to id', () {
    for (final edge in catalogV1.swapEdges) {
      expect(exercisesById, contains(edge.fromId), reason: '$edge');
      expect(exercisesById, contains(edge.toId), reason: '$edge');
      expect(exercisesById[edge.fromId]!.isRetired, isFalse, reason: '$edge');
      expect(exercisesById[edge.toId]!.isRetired, isFalse, reason: '$edge');
    }
  });

  test('swap edges preserve block role, difficulty and rep compatibility', () {
    for (final edge in catalogV1.swapEdges) {
      final from = exercisesById[edge.fromId]!;
      final to = exercisesById[edge.toId]!;
      expect(to.blockRole, from.blockRole, reason: '$edge role');
      expect(to.difficultyTier, from.difficultyTier, reason: '$edge tier');
      if (from.metricType == MetricType.timed ||
          to.metricType == MetricType.timed) {
        expect(to.metricType, from.metricType, reason: '$edge timed metric');
      } else {
        expect(
          config.rangeFor(to, compatibilityScheme),
          config.rangeFor(from, compatibilityScheme),
          reason: '$edge rep range',
        );
      }
    }
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
