import 'package:test/test.dart';

import 'support/plan_fixtures.dart';

void main() {
  group('PERSONAS.md semantic plan snapshots', () {
    for (var index = 0; index < personaFixtures.length; index++) {
      final fixture = personaFixtures[index];
      test(fixture.name, () {
        expect(
          semanticProjection(successfulPlan(fixture.profile)),
          _expected[index],
        );
      });
    }
  });

  test('persona 9 is byte-identical to her non-runner twin', () {
    final runner = successfulPlan(personaFixtures[8].profile);
    final twin = successfulPlan(
      personaFixtures[8].profile.copyWith(otherActivities: const []),
    );
    expect(runner, twin);
    expect(runner.toCanonicalString(), twin.toCanonicalString());
  });

  test('persona 13 advances every comparable rotating slot by one', () {
    final first = successfulPlan(personaFixtures[0].profile);
    final second = successfulPlan(personaFixtures[12].profile);
    expect(
      second.days.map((day) => day.kind),
      first.days.map((day) => day.kind),
    );
    expect(
      second.days.map((day) => day.exercises.length),
      first.days.map((day) => day.exercises.length),
    );

    var compared = 0;
    for (var dayIndex = 0; dayIndex < first.days.length; dayIndex++) {
      for (
        var slotIndex = 0;
        slotIndex < first.days[dayIndex].exercises.length;
        slotIndex++
      ) {
        final before = first.days[dayIndex].exercises[slotIndex];
        final after = second.days[dayIndex].exercises[slotIndex];
        if (!before.rotatesAcrossMesocycles ||
            before.blockRole != after.blockRole) {
          continue;
        }
        expect(after.exerciseId, isNot(before.exerciseId));
        compared++;
      }
    }
    expect(compared, greaterThan(0));
  });
}

const _expected = <String>[
  '''
day 1: lower (warmup 5m)
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  dumbbell-goblet-squat [lowerSquat] 3x10-12@7
  machine-back-extension [lowerHinge] 3x10-12@7
  machine-leg-press [lowerSquat] 3x10-12@7
  machine-leg-extension [legIsolation] 3x10-15@7
  machine-hip-abduction [gluteIsolation] 3x10-15@7
day 2: upper (warmup 5m)
  machine-chest-press [upperPush] 3x10-12@7
  machine-pulldown [upperPull] 3x10-12@7
  dumbbell-seated-overhead-press [upperPush] 3x10-12@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  plank [core] 3x20s
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
day 3: lower (warmup 5m)
  machine-glute-kickback [gluteIsolation] 3x10-15@7
  bodyweight-squat [lowerSquat] 3x10-12@7
  machine-back-extension [lowerHinge] 3x10-12@7
  bodyweight-reverse-lunge [lowerSquat] 3x10-15@7
  machine-seated-hamstring-curl [legIsolation] 3x10-15@7
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7''',
  '''
day 1: fullBodyA (warmup 5m)
  dumbbell-goblet-squat [lowerSquat] 3x10-12@6
  machine-pulldown [upperPull] 3x10-12@6
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@6
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@6
day 2: fullBodyB (warmup 5m)
  cable-pull-through [lowerHinge] 3x10-12@6
  dumbbell-bench-press [upperPush] 3x10-12@6
  dumbbell-hip-thrust [gluteIsolation] 3x10-15@6
  dumbbell-curl [armShoulderIsolation] 3x10-15@6''',
  '''
day 1: fullBodyA (warmup 7m)
  machine-leg-press [lowerSquat] 3x10-12@6
  machine-pulldown [upperPull] 3x10-12@6
  machine-chest-press [upperPush] 3x10-12@6
  machine-hip-abduction [gluteIsolation] 3x10-15@6
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@6
  machine-leg-extension [legIsolation] 3x10-15@6
day 2: fullBodyB (warmup 7m)
  machine-back-extension [lowerHinge] 3x10-12@6
  bodyweight-push-up [upperPush] 3x10-12@6
  machine-seated-cable-row [upperPull] 3x10-12@6
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@6
  dumbbell-curl [armShoulderIsolation] 3x10-15@6
  machine-seated-hamstring-curl [legIsolation] 3x10-15@6''',
  '''
day 1: lower (warmup 5m, finisher)
  barbell-hip-thrust [gluteIsolation] 3x10-15@7
  dumbbell-goblet-squat [lowerSquat] 3x10-12@7
  barbell-romanian-deadlift [lowerHinge] 3x10-12@7
  barbell-squat [lowerSquat] 3x10-12@7
  machine-leg-extension [legIsolation] 3x10-15@7
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  plank [core] 3x20s
day 2: upper (warmup 5m, finisher)
  dumbbell-bench-press [upperPush] 3x10-12@7
  dumbbell-row-unilateral [upperPull] 3x10-15@7
  barbell-bench-press [upperPush] 3x10-12@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  cable-rope-kneeling-crunch [core] 3x10-12@7
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
  crunches [core] 3x10-12@7
day 3: lowerGluteLed (warmup 5m, finisher)
  dumbbell-hip-thrust [gluteIsolation] 3x10-15@7
  dumbbell-bulgarian-split-squat [lowerSquat] 3x10-15@7
  dumbbell-romanian-deadlift [lowerHinge] 3x10-12@7
  bodyweight-reverse-lunge [lowerSquat] 3x10-15@7
  machine-seated-hamstring-curl [legIsolation] 3x10-15@7
  machine-hip-abduction [gluteIsolation] 3x10-15@7
  elbow-side-plank [core] 3x20s
day 4: upper (warmup 5m, finisher)
  dumbbell-incline-bench-press [upperPush] 3x10-12@7
  dumbbell-row-unilateral [upperPull] 3x10-15@7
  dumbbell-seated-overhead-press [upperPush] 3x10-12@7
  cable-rope-pushdown [armShoulderIsolation] 3x10-15@7
  dead-bug [core] 3x10-12@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  plank [core] 3x20s''',
  '''
day 1: lower (warmup 5m, finisher)
  dumbbell-goblet-squat [lowerSquat] 4x6-8@8
  barbell-romanian-deadlift [lowerHinge] 4x6-8@8
  machine-leg-press [lowerSquat] 4x6-8@8
  machine-leg-extension [legIsolation] 4x10-15@8
  dumbbell-glute-bridge [gluteIsolation] 4x10-15@8
  plank [core] 4x20s
  machine-seated-hamstring-curl [legIsolation] 4x10-15@8
day 2: upper (warmup 5m, finisher)
  dumbbell-bench-press [upperPush] 4x6-8@8
  machine-pulldown [upperPull] 4x6-8@8
  dumbbell-incline-bench-press [upperPush] 4x6-8@8
  dumbbell-lateral-raise [armShoulderIsolation] 4x10-15@8
  cable-rope-kneeling-crunch [core] 4x6-8@8
  dumbbell-curl [armShoulderIsolation] 4x10-15@8
  crunches [core] 4x6-8@8
day 3: fullBodyA (warmup 5m, finisher)
  dumbbell-bulgarian-split-squat [lowerSquat] 4x10-15@8
  machine-seated-cable-row [upperPull] 4x6-8@8
  dumbbell-seated-overhead-press [upperPush] 4x6-8@8
  dumbbell-hip-thrust [gluteIsolation] 4x10-15@8
  cable-rope-pushdown [armShoulderIsolation] 4x10-15@8
  machine-standing-calf-raises [legIsolation] 4x10-15@8
  elbow-side-plank [core] 4x20s''',
  '''
day 1: lower (warmup 5m)
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  machine-leg-press [lowerSquat] 3x10-12@7
  machine-back-extension [lowerHinge] 3x10-12@7
  machine-hip-abduction [gluteIsolation] 3x10-15@7
day 2: upper (warmup 5m)
  machine-chest-press [upperPush] 3x10-12@7
  machine-pulldown [upperPull] 3x10-12@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  plank [core] 3x20s
day 3: lower (warmup 5m)
  machine-glute-kickback [gluteIsolation] 3x10-15@7
  bodyweight-squat [lowerSquat] 3x10-12@7
  machine-back-extension [lowerHinge] 3x10-12@7
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7''',
  '''
day 1: lower (warmup 5m)
  dumbbell-goblet-squat [lowerSquat] 3x10-12@7
  barbell-romanian-deadlift [lowerHinge] 3x10-12@7
  machine-leg-press [lowerSquat] 3x10-12@7
  machine-leg-extension [legIsolation] 3x10-15@7
  plank [core] 3x20s
  cable-rope-kneeling-crunch [core] 3x10-12@7
day 2: upper (warmup 5m)
  dumbbell-bench-press [upperPush] 3x10-12@7
  machine-pulldown [upperPull] 3x10-12@7
  dumbbell-incline-bench-press [upperPush] 3x10-12@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  crunches [core] 3x10-12@7
  elbow-side-plank [core] 3x20s
day 3: fullBodyA (warmup 5m)
  dumbbell-bulgarian-split-squat [lowerSquat] 3x10-15@7
  machine-seated-cable-row [upperPull] 3x10-12@7
  dumbbell-seated-overhead-press [upperPush] 3x10-12@7
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
  dead-bug [core] 3x10-12@7''',
  '''
day 1: fullBodyA (warmup 6m)
  machine-leg-press [lowerSquat] 3x6-8@7
  machine-pulldown [upperPull] 3x6-8@7
  dumbbell-bench-press [upperPush] 3x6-8@7
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  machine-leg-extension [legIsolation] 3x10-15@7
day 2: fullBodyB (warmup 6m)
  barbell-romanian-deadlift [lowerHinge] 3x6-8@7
  machine-chest-press [upperPush] 3x6-8@7
  machine-seated-cable-row [upperPull] 3x6-8@7
  dumbbell-hip-thrust [gluteIsolation] 3x10-15@7
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
  machine-seated-hamstring-curl [legIsolation] 3x10-15@7''',
  '''
day 1: fullBodyA (warmup 5m)
  dumbbell-goblet-squat [lowerSquat] 3x10-12@7
  machine-pulldown [upperPull] 3x10-12@7
  dumbbell-bench-press [upperPush] 3x10-12@7
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  machine-leg-extension [legIsolation] 3x10-15@7
day 2: fullBodyB (warmup 5m)
  barbell-romanian-deadlift [lowerHinge] 3x10-12@7
  machine-chest-press [upperPush] 3x10-12@7
  dumbbell-row-unilateral [upperPull] 3x10-15@7
  dumbbell-hip-thrust [gluteIsolation] 3x10-15@7
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
  machine-seated-hamstring-curl [legIsolation] 3x10-15@7''',
  '''
day 1: lower (warmup 5m)
  dumbbell-goblet-squat [lowerSquat] 3x10-12@7
  barbell-romanian-deadlift [lowerHinge] 3x10-12@7
  barbell-squat [lowerSquat] 3x10-12@7
  machine-leg-extension [legIsolation] 3x10-15@7
  barbell-hip-thrust [gluteIsolation] 3x10-15@7
  plank [core] 3x20s
day 2: upper (warmup 5m)
  dumbbell-bench-press [upperPush] 3x10-12@7
  machine-pulldown [upperPull] 3x10-12@7
  dumbbell-row-unilateral [upperPull] 3x10-15@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  cable-rope-kneeling-crunch [core] 3x10-12@7
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
day 3: lowerGluteLed (warmup 5m)
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  dumbbell-bulgarian-split-squat [lowerSquat] 3x10-15@7
  dumbbell-romanian-deadlift [lowerHinge] 3x10-12@7
  bodyweight-reverse-lunge [lowerSquat] 3x10-15@7
  machine-seated-hamstring-curl [legIsolation] 3x10-15@7
  dumbbell-hip-thrust [gluteIsolation] 3x10-15@7
day 4: upper (warmup 5m)
  barbell-bench-press [upperPush] 3x10-12@7
  machine-seated-cable-row [upperPull] 3x10-12@7
  dumbbell-row-unilateral [upperPull] 3x10-15@7
  cable-rope-pushdown [armShoulderIsolation] 3x10-15@7
  crunches [core] 3x10-12@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7''',
  '''
day 1: lower (warmup 5m)
  dumbbell-goblet-squat [lowerSquat] 3x10-12@7
  barbell-romanian-deadlift [lowerHinge] 3x10-12@7
  machine-leg-press [lowerSquat] 3x10-12@7
  machine-leg-extension [legIsolation] 3x10-15@7
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  plank [core] 3x20s
day 2: upper (warmup 5m)
  dumbbell-bench-press [upperPush] 3x10-12@7
  machine-pulldown [upperPull] 3x10-12@7
  dumbbell-incline-bench-press [upperPush] 3x10-12@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
  cable-rope-pushdown [armShoulderIsolation] 3x10-15@7
day 3: fullBodyA (warmup 5m)
  dumbbell-bulgarian-split-squat [lowerSquat] 3x10-15@7
  machine-seated-cable-row [upperPull] 3x10-12@7
  dumbbell-seated-overhead-press [upperPush] 3x10-12@7
  dumbbell-hip-thrust [gluteIsolation] 3x10-15@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  dumbbell-curl [armShoulderIsolation] 3x10-15@7''',
  '''
day 1: lower (warmup 5m)
  dumbbell-goblet-squat [lowerSquat] 3x10-12@6
  barbell-romanian-deadlift [lowerHinge] 3x10-12@6
  barbell-squat [lowerSquat] 3x10-12@6
  machine-leg-extension [legIsolation] 3x10-15@6
  barbell-hip-thrust [gluteIsolation] 3x10-15@6
  plank [core] 3x20s
day 2: upper (warmup 5m)
  dumbbell-bench-press [upperPush] 3x10-12@6
  dumbbell-row-unilateral [upperPull] 3x10-15@6
  barbell-bench-press [upperPush] 3x10-12@6
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@6
  cable-rope-kneeling-crunch [core] 3x10-12@6
  dumbbell-curl [armShoulderIsolation] 3x10-15@6
day 3: fullBodyA (warmup 5m)
  dumbbell-bulgarian-split-squat [lowerSquat] 3x10-15@6
  dumbbell-row-unilateral [upperPull] 3x10-15@6
  dumbbell-incline-bench-press [upperPush] 3x10-12@6
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@6
  cable-rope-pushdown [armShoulderIsolation] 3x10-15@6
  machine-seated-hamstring-curl [legIsolation] 3x10-15@6''',
  '''
day 1: lower (warmup 5m)
  machine-hip-abduction [gluteIsolation] 3x10-15@7
  bodyweight-reverse-lunge [lowerSquat] 3x10-15@7
  machine-back-extension [lowerHinge] 3x10-12@7
  bodyweight-squat [lowerSquat] 3x10-12@7
  machine-leg-extension [legIsolation] 3x10-15@7
  machine-glute-kickback [gluteIsolation] 3x10-15@7
day 2: upper (warmup 5m)
  dumbbell-seated-overhead-press [upperPush] 3x10-12@7
  machine-seated-cable-row [upperPull] 3x10-12@7
  bodyweight-push-up [upperPush] 3x10-12@7
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
  crunches [core] 3x10-12@7
  cable-rope-pushdown [armShoulderIsolation] 3x10-15@7
day 3: lower (warmup 5m)
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  machine-leg-press [lowerSquat] 3x10-12@7
  machine-back-extension [lowerHinge] 3x10-12@7
  dumbbell-goblet-squat [lowerSquat] 3x10-12@7
  machine-seated-hamstring-curl [legIsolation] 3x10-15@7
  machine-glute-kickback [gluteIsolation] 3x10-15@7''',
  '''
day 1: lower (warmup 6m)
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7
  machine-leg-press [lowerSquat] 3x10-12@7
  machine-back-extension [lowerHinge] 3x10-12@7
  bodyweight-squat [lowerSquat] 3x10-12@7
  machine-leg-extension [legIsolation] 3x10-15@7
  machine-hip-abduction [gluteIsolation] 3x10-15@7
day 2: upper (warmup 6m)
  machine-chest-press [upperPush] 3x10-12@7
  machine-pulldown [upperPull] 3x10-12@7
  bodyweight-push-up [upperPush] 3x10-12@7
  dumbbell-lateral-raise [armShoulderIsolation] 3x10-15@7
  plank [core] 3x20s
  dumbbell-curl [armShoulderIsolation] 3x10-15@7
day 3: lower (warmup 6m)
  machine-glute-kickback [gluteIsolation] 3x10-15@7
  machine-leg-press [lowerSquat] 3x10-12@7
  machine-back-extension [lowerHinge] 3x10-12@7
  bodyweight-squat [lowerSquat] 3x10-12@7
  machine-seated-hamstring-curl [legIsolation] 3x10-15@7
  dumbbell-glute-bridge [gluteIsolation] 3x10-15@7''',
];
