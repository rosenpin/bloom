import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/plan_fixtures.dart';

void main() {
  final exercisesById = <String, Exercise>{
    for (final exercise in catalogV1.exercises) exercise.id: exercise,
  };

  test('full profile cross-product succeeds without dropping a block', () {
    var profileCount = 0;
    for (final experience in ProfileExperienceTier.values) {
      for (final age in AgeBand.values) {
        for (final comfort in GymComfort.values) {
          for (final emphasis in Emphasis.values) {
            for (final days in TrainingDaysPerWeek.values) {
              for (final minutes in SessionMinutes.values) {
                final profile = Profile(
                  ageBand: age,
                  daysPerWeek: days,
                  sessionMinutes: minutes,
                  goal: Goal.tonedAndDefined,
                  emphasis: emphasis,
                  experienceTier: experience,
                  gymComfort: comfort,
                  weeksTrained: 0,
                  mesocycleIndex: 1,
                );
                final result = assemblePlan(
                  profile,
                  const ProgrammingConfig(),
                  catalogV1,
                );
                expect(
                  result,
                  isA<Success<Plan>>(),
                  reason: _profileLabel(profile),
                );
                final plan = (result as Success<Plan>).value;
                expect(
                  plan.warnings.where(
                    (warning) => warning.code == WarningCode.blockDropped,
                  ),
                  isEmpty,
                  reason: _profileLabel(profile),
                );
                for (final day in plan.days) {
                  final dayIds = <String>{};
                  for (final slot in day.exercises) {
                    expect(
                      dayIds.add(slot.exerciseId),
                      isTrue,
                      reason: _profileLabel(profile),
                    );
                    expect(
                      eligible(exercisesById[slot.exerciseId]!, profile),
                      isTrue,
                      reason: '${_profileLabel(profile)}/${slot.exerciseId}',
                    );
                  }
                }
                profileCount++;
              }
            }
          }
        }
      }
    }
    expect(profileCount, 2430);
  });

  test('every fixture plan slot is eligible and days are deduplicated', () {
    for (final fixture in personaFixtures) {
      final plan = successfulPlan(fixture.profile);
      for (final day in plan.days) {
        final ids = <String>{};
        for (final slot in day.exercises) {
          expect(ids.add(slot.exerciseId), isTrue, reason: fixture.name);
          expect(
            eligible(exercisesById[slot.exerciseId]!, fixture.profile),
            isTrue,
            reason: '${fixture.name}/${slot.exerciseId}',
          );
        }
      }
    }
  });

  test('weekly dedup is applied when the catalog has enough alternatives', () {
    final plan = successfulPlan(personaFixtures[1].profile);
    final ids = plan.days
        .expand((day) => day.exercises)
        .map((exercise) => exercise.exerciseId)
        .toList(growable: false);
    expect(ids.toSet(), hasLength(ids.length));
    expect(
      plan.warnings.map((warning) => warning.code),
      isNot(contains(WarningCode.weeklyDedupRelaxed)),
    );
  });

  test('30-minute plans retain exactly two primary blocks', () {
    for (final emphasis in Emphasis.values) {
      final profile = _profile(
        minutes: SessionMinutes.thirty,
        emphasis: emphasis,
        days: TrainingDaysPerWeek.four,
      );
      final plan = successfulPlan(profile);
      for (final day in plan.days) {
        final primaries = day.exercises.where(
          (exercise) => exercise.blockRole.isPrimary,
        );
        expect(
          primaries,
          hasLength(2),
          reason: '${emphasis.name}/${day.kind.name}',
        );
        expect(
          primaries.every((exercise) => exercise.dropPriority == 0),
          isTrue,
        );
      }
    }
  });

  test('machine affinity is the rounded machine-variant fraction per day', () {
    for (final fixture in personaFixtures) {
      final plan = successfulPlan(fixture.profile);
      final affinity = machineAffinityFor(
        fixture.profile,
        const ProgrammingConfig(),
      );
      for (final day in plan.days) {
        final primaries = day.exercises
            .where((exercise) => exercise.blockRole.isPrimary)
            .toList(growable: false);
        final expected = (primaries.length * affinity).round();
        final actual = primaries
            .where(
              (exercise) => exercisesById[exercise.exerciseId]!.machineLeanOk,
            )
            .length;
        expect(
          (actual - expected).abs(),
          lessThanOrEqualTo(1),
          reason: '${fixture.name}/${day.kind.name}/affinity=$affinity',
        );
        if (affinity == 1) {
          expect(
            actual,
            primaries.length,
            reason: '${fixture.name}/${day.kind.name}/forced edge',
          );
        }
      }
    }
  });

  test('machine affinity does not change isolation-slot selection', () {
    final profile = _profile(
      experience: ProfileExperienceTier.beenAWhile,
      comfort: GymComfort.mostlyFine,
    );
    const noMachines = ProgrammingConfig(
      machineAffinityBeenAWhile: 0,
      machineAffinityMostlyFineComfort: 0,
    );
    const allMachines = ProgrammingConfig(
      machineAffinityBeenAWhile: 1,
      machineAffinityMostlyFineComfort: 0,
    );
    final low = successfulPlan(profile, config: noMachines);
    final high = successfulPlan(profile, config: allMachines);
    for (var dayIndex = 0; dayIndex < low.days.length; dayIndex++) {
      List<String> isolationIds(PlanDay day) => day.exercises
          .where((exercise) => !exercise.blockRole.isPrimary)
          .map((exercise) => exercise.exerciseId)
          .toList(growable: false);
      expect(
        isolationIds(high.days[dayIndex]),
        isolationIds(low.days[dayIndex]),
      );
    }
  });

  test(
    'glute emphasis stays first; non-glute emphasis keeps compounds first',
    () {
      final glutePlan = successfulPlan(personaFixtures.first.profile);
      for (final day in glutePlan.days.where(
        (day) => day.kind == PlanDayKind.lower,
      )) {
        expect(day.exercises.first.blockRole, BlockRole.gluteIsolation);
        expect(day.exercises.first.isEmphasis, isTrue);
      }

      for (final fixture in <PersonaFixture>[
        personaFixtures[6],
        personaFixtures[9],
        personaFixtures[10],
      ]) {
        final plan = successfulPlan(fixture.profile);
        for (final day in plan.days) {
          if (day.kind == PlanDayKind.lowerGluteLed) continue;
          expect(
            day.exercises.first.blockRole.isPrimary,
            isTrue,
            reason: '${fixture.name}/${day.kind.name}',
          );
        }
      }
    },
  );

  test(
    'back, arms and core emphasis each add one occurrence where applicable',
    () {
      const cases = <(Emphasis, BlockRole)>[
        (Emphasis.back, BlockRole.upperPull),
        (Emphasis.arms, BlockRole.armShoulderIsolation),
        (Emphasis.core, BlockRole.core),
      ];
      for (final (emphasis, role) in cases) {
        final profile = _profile(
          days: TrainingDaysPerWeek.three,
          emphasis: emphasis,
          experience: ProfileExperienceTier.trainsRegularly,
          comfort: GymComfort.totallyAtHome,
        );
        final emphasized = successfulPlan(profile);
        final balanced = successfulPlan(
          profile.copyWith(emphasis: Emphasis.balanced),
        );
        var changedDays = 0;
        for (var dayIndex = 0; dayIndex < emphasized.days.length; dayIndex++) {
          int occurrences(PlanDay day) => day.exercises
              .where((exercise) => exercise.blockRole == role)
              .length;
          final delta =
              occurrences(emphasized.days[dayIndex]) -
              occurrences(balanced.days[dayIndex]);
          expect(delta, anyOf(0, 1), reason: '${emphasis.name}/day $dayIndex');
          if (delta == 1) changedDays++;
        }
        expect(changedDays, greaterThan(0), reason: emphasis.name);
      }
    },
  );

  test('session shapes are 4, 6, and 7 plus a cardio finisher', () {
    final expected = <SessionMinutes, int>{
      SessionMinutes.thirty: 4,
      SessionMinutes.fortyFive: 6,
      SessionMinutes.sixty: 7,
    };
    for (final entry in expected.entries) {
      final plan = successfulPlan(_profile(minutes: entry.key));
      for (final day in plan.days) {
        expect(day.exercises, hasLength(entry.value));
        expect(day.hasCardioFinisher, entry.key == SessionMinutes.sixty);
      }
    }
  });

  test('every instantiated rotating slot carries at least two candidates', () {
    for (final fixture in personaFixtures) {
      final plan = successfulPlan(fixture.profile);
      for (final slot in plan.days.expand((day) => day.exercises)) {
        if (slot.rotatesAcrossMesocycles) {
          expect(
            slot.rotationCandidateIds,
            hasLength(greaterThanOrEqualTo(2)),
            reason: '${fixture.name}/${slot.exerciseId}',
          );
        }
      }
    }
  });

  test(
    'mesocycle index selects the exact k-th authored variation modulo length',
    () {
      final baseProfile = _profile(
        experience: ProfileExperienceTier.trainsRegularly,
        comfort: GymComfort.totallyAtHome,
        minutes: SessionMinutes.thirty,
      );
      final firstSlot = successfulPlan(
        baseProfile.copyWith(mesocycleIndex: 1),
      ).days.first.exercises.first;
      final candidates = firstSlot.rotationCandidateIds;
      for (
        var mesocycleIndex = 1;
        mesocycleIndex <= candidates.length + 1;
        mesocycleIndex++
      ) {
        final selected = successfulPlan(
          baseProfile.copyWith(mesocycleIndex: mesocycleIndex),
        ).days.first.exercises.first;
        expect(
          selected.exerciseId,
          candidates[(mesocycleIndex - 1) % candidates.length],
        );
      }
    },
  );

  test(
    'same input produces equal objects and byte-identical canonical plans',
    () {
      for (final fixture in personaFixtures) {
        final first = successfulPlan(fixture.profile);
        final second = successfulPlan(fixture.profile);
        expect(second, first, reason: fixture.name);
        expect(second.toCanonicalString(), first.toCanonicalString());
      }
    },
  );

  test('calendar and per-week doses are fully stamped', () {
    final plan = successfulPlan(personaFixtures.first.profile);
    expect(plan.mesocycleCalendar.map((week) => week.kind), const [
      MesocycleWeekKind.build,
      MesocycleWeekKind.build,
      MesocycleWeekKind.build,
      MesocycleWeekKind.easier,
      MesocycleWeekKind.push,
      MesocycleWeekKind.deload,
    ]);
    for (final slot in plan.days.expand((day) => day.exercises)) {
      expect(
        slot.doseByWeekKind.keys.toSet(),
        MesocycleWeekKind.values.toSet(),
      );
      final build = slot.doseFor(MesocycleWeekKind.build);
      final easier = slot.doseFor(MesocycleWeekKind.easier);
      if (build case RepsDose(:final effort)) {
        expect(
          (easier as RepsDose).effort.rpe,
          lessThan(effort.rpe),
          reason: slot.exerciseId,
        );
        expect(
          (slot.doseFor(MesocycleWeekKind.deload) as RepsDose).effort.rpe,
          lessThan(effort.rpe),
          reason: slot.exerciseId,
        );
      } else {
        expect(easier.sets, lessThan(build.sets), reason: slot.exerciseId);
        expect(
          slot.doseFor(MesocycleWeekKind.deload).sets,
          lessThan(build.sets),
          reason: slot.exerciseId,
        );
      }
    }
  });

  test('stamps change with each decision-bearing input family', () {
    final profile = _profile();
    final base = successfulPlan(profile);
    final profileChange = successfulPlan(profile.copyWith(mesocycleIndex: 2));
    final configChange = successfulPlan(
      profile,
      config: const ProgrammingConfig(warmUpMinutes: 6),
    );
    final contentChange = successfulPlan(
      profile,
      catalog: ContentCatalogData(
        contentVersion: 'different',
        exercises: catalogV1.exercises,
        swapEdges: catalogV1.swapEdges,
        rotatingBlockRoles: catalogV1.rotatingBlockRoles,
      ),
    );
    expect(profileChange.stamps.profileHash, isNot(base.stamps.profileHash));
    expect(configChange.stamps.configHash, isNot(base.stamps.configHash));
    expect(contentChange.stamps.contentHash, isNot(base.stamps.contentHash));
  });

  group('fixed fallback ladder', () {
    test('never relaxes low-comfort intimidation gating', () {
      final result = assemblePlan(
        _profile(comfort: GymComfort.low),
        const ProgrammingConfig(),
        _singleExerciseCatalog(intimidation: IntimidationTier.high),
      );
      expect(result, isA<Failure<Plan>>());
      expect(
        (result as Failure<Plan>).error.code,
        PlanAssemblyErrorCode.noUsableExercises,
      );
    });

    test('relaxes experience while preserving the comfort gate', () {
      final plan = successfulPlan(
        _profile(
          comfort: GymComfort.low,
          experience: ProfileExperienceTier.newToIt,
        ),
        catalog: _singleExerciseCatalog(
          minimumExperience: ExperienceTier.trainsRegularly,
        ),
      );
      expect(
        plan.warnings.map((warning) => warning.code),
        contains(WarningCode.experienceTierRelaxed),
      );
      expect(
        plan.warnings.map((warning) => warning.code),
        isNot(contains(WarningCode.gymComfortRelaxed)),
      );
    });

    test('never relaxes self-guided safety', () {
      final result = assemblePlan(
        _profile(),
        const ProgrammingConfig(),
        _singleExerciseCatalog(safety: SafetyEligibility.instructorRequired),
      );
      expect(result, isA<Failure<Plan>>());
      expect(
        (result as Failure<Plan>).error.code,
        PlanAssemblyErrorCode.noUsableExercises,
      );
    });

    test('never relaxes hard age eligibility', () {
      final result = assemblePlan(
        _profile(age: AgeBand.age60Plus),
        const ProgrammingConfig(),
        _singleExerciseCatalog(ageEligibility: AgeEligibility.under60),
      );
      expect(result, isA<Failure<Plan>>());
    });

    test('empty content is a genuinely unbuildable rich error', () {
      final result = assemblePlan(
        _profile(),
        const ProgrammingConfig(),
        ContentCatalogData(
          contentVersion: 'empty',
          exercises: const <Exercise>[],
          swapEdges: const <SwapEdge>[],
          rotatingBlockRoles: const <BlockRole>[],
        ),
      );
      expect(result, isA<Failure<Plan>>());
      final error = (result as Failure<Plan>).error;
      expect(error.code, PlanAssemblyErrorCode.noUsableExercises);
      expect(error.affectedRoles, isNotEmpty);
    });

    test(
      'missing scheme configuration returns an error instead of throwing',
      () {
        final result = assemblePlan(
          _profile(),
          const ProgrammingConfig(repSchemes: <Goal, RepScheme>{}),
          catalogV1,
        );
        expect(result, isA<Failure<Plan>>());
        expect(
          (result as Failure<Plan>).error.code,
          PlanAssemblyErrorCode.missingRepSchemeConfiguration,
        );
      },
    );

    test('dangling swaps skip to same-role fallback candidates and warn', () {
      final baseExercises = catalogV1.exercises
          .where((exercise) => exercise.blockRole == BlockRole.lowerSquat)
          .toList(growable: false);
      final plan = successfulPlan(
        _profile(minutes: SessionMinutes.thirty),
        config: const ProgrammingConfig(
          machineAffinityBeenAWhile: 0,
          machineAffinityMostlyFineComfort: 0,
        ),
        catalog: ContentCatalogData(
          contentVersion: 'dangling-swap-fixture',
          exercises: baseExercises,
          swapEdges: const <SwapEdge>[
            SwapEdge(
              fromId: 'dumbbell-goblet-squat',
              toId: 'missing',
              tier: 1,
              rank: 0,
            ),
          ],
          rotatingBlockRoles: const <BlockRole>[],
        ),
      );
      expect(
        plan.warnings.map((warning) => warning.code),
        contains(WarningCode.danglingSwapSkipped),
      );
      final goblet = plan.days
          .expand((day) => day.exercises)
          .firstWhere(
            (exercise) => exercise.exerciseId == 'dumbbell-goblet-squat',
          );
      expect(goblet.orderedSwapCandidates, isNotEmpty);
    });
  });
}

Profile _profile({
  AgeBand age = AgeBand.age30To39,
  TrainingDaysPerWeek days = TrainingDaysPerWeek.two,
  SessionMinutes minutes = SessionMinutes.fortyFive,
  Emphasis emphasis = Emphasis.balanced,
  ProfileExperienceTier experience = ProfileExperienceTier.beenAWhile,
  GymComfort comfort = GymComfort.mostlyFine,
}) => Profile(
  ageBand: age,
  daysPerWeek: days,
  sessionMinutes: minutes,
  goal: Goal.tonedAndDefined,
  emphasis: emphasis,
  experienceTier: experience,
  gymComfort: comfort,
  weeksTrained: 8,
  mesocycleIndex: 1,
);

ContentCatalog _singleExerciseCatalog({
  IntimidationTier intimidation = IntimidationTier.low,
  ExperienceTier minimumExperience = ExperienceTier.neverTrained,
  AgeEligibility ageEligibility = AgeEligibility.allAges,
  SafetyEligibility safety = SafetyEligibility.selfGuided,
}) => ContentCatalogData(
  contentVersion: 'fallback-fixture',
  exercises: <Exercise>[
    ExerciseData(
      id: 'fallback-squat',
      name: 'Fallback Squat',
      slug: 'fallback-squat',
      blockRole: BlockRole.lowerSquat,
      movementClass: MovementClass.compoundLower,
      metricType: MetricType.repsOnly,
      resistanceEquipment: ResistanceEquipment.bodyweight,
      bwContribution: 0.65,
      targetMuscles: const [MuscleTarget.primary(MuscleGroup.quads)],
      primaryJointActions: const [JointAction.kneeExtension],
      intimidationTier: intimidation,
      minExperience: minimumExperience,
      ageEligibility: ageEligibility,
      safetyEligibility: safety,
    ),
  ],
  swapEdges: const <SwapEdge>[],
  rotatingBlockRoles: const <BlockRole>[],
);

String _profileLabel(Profile profile) =>
    '${profile.experienceTier.name}/${profile.ageBand.name}/'
    '${profile.gymComfort.name}/${profile.emphasis.name}/'
    '${profile.daysPerWeek.value}d/${profile.sessionMinutes.value}m';
