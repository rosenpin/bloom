import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/plan_fixtures.dart';

void main() {
  group('applyPlanEdit', () {
    test(
      'KeepSwap thisSlot replaces the first matching slot and stamps it',
      () {
        final plan = successfulPlan(personaFixtures[0].profile);
        final source = plan.days
            .expand((day) => day.exercises)
            .firstWhere(
              (exercise) => exercise.orderedSwapCandidates.isNotEmpty,
            );
        final replacement = source.orderedSwapCandidates.first;
        final before = plan.days
            .expand((day) => day.exercises)
            .where((exercise) => exercise.exerciseId == source.exerciseId)
            .length;

        final edited = applyPlanEdit(
          plan,
          KeepSwap(
            exerciseId: source.exerciseId,
            replacementId: replacement.exerciseId,
            scope: PlanEditScope.thisSlot,
          ),
        );

        final afterSource = edited.days
            .expand((day) => day.exercises)
            .where((exercise) => exercise.exerciseId == source.exerciseId)
            .length;
        expect(afterSource, before - 1);
        expect(
          edited.days
              .expand((day) => day.exercises)
              .where(
                (exercise) => exercise.exerciseId == replacement.exerciseId,
              ),
          isNotEmpty,
        );
        expect(edited.editStamps, hasLength(1));
        expect(edited.reference, isNot(plan.reference));
      },
    );

    test('KeepSwap allSlotsOfExercise replaces every matching slot', () {
      final plan = successfulPlan(personaFixtures[0].profile);
      final grouped = <String, List<PlanExercise>>{};
      for (final exercise in plan.days.expand((day) => day.exercises)) {
        (grouped[exercise.exerciseId] ??= <PlanExercise>[]).add(exercise);
      }
      final source = grouped.values
          .where(
            (items) =>
                items.length > 1 &&
                items.every((item) => item.orderedSwapCandidates.isNotEmpty),
          )
          .first
          .first;
      final replacement = source.orderedSwapCandidates.first;

      final edited = applyPlanEdit(
        plan,
        KeepSwap(
          exerciseId: source.exerciseId,
          replacementId: replacement.exerciseId,
          scope: PlanEditScope.allSlotsOfExercise,
        ),
      );

      expect(
        edited.days
            .expand((day) => day.exercises)
            .where((exercise) => exercise.exerciseId == source.exerciseId),
        isEmpty,
      );
    });

    test(
      'ExcludeExercise substitutes slots while the preference stays external',
      () {
        final plan = successfulPlan(personaFixtures[1].profile);
        final exerciseId = plan.days.first.exercises.first.exerciseId;
        const source = ExclusionSource.pain;
        final edit = ExcludeExercise(exerciseId: exerciseId, source: source);

        final edited = applyPlanEdit(plan, edit);
        final rerun = applyPlanEdit(plan, edit);

        expect(
          edited.days
              .expand((day) => day.exercises)
              .where((exercise) => exercise.exerciseId == exerciseId),
          isEmpty,
        );
        expect(edited.editStamps.single.editId, 'exclude:$exerciseId:pain');
        expect(edited, rerun);
        expect(applyPlanEdit(edited, edit), same(edited));
      },
    );

    test('missing target is a total warned no-op', () {
      final plan = successfulPlan(personaFixtures[1].profile);
      final edited = applyPlanEdit(
        plan,
        const KeepSwap(
          exerciseId: 'missing',
          replacementId: 'also-missing',
          scope: PlanEditScope.thisSlot,
        ),
      );

      expect(edited.days, plan.days);
      expect(
        edited.warnings.map((warning) => warning.code),
        contains(WarningCode.planEditTargetMissing),
      );
    });
  });
}
