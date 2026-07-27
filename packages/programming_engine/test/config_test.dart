/// The tuning numbers, checked against the spec they came from.
///
/// If a number here changes, `PROGRAMMING.md` changed too — that's the point of the
/// test: it makes the config auditable against the doc in one place.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

typedef Scheme = ({
  String rule,
  Goal goal,
  int minSets,
  int maxSets,
  RepRange range,
  int rpe,
  int restSeconds,
  bool extraSetOnEmphasis,
});

void main() {
  group('§2 rep/set schemes by goal', () {
    const schemes = <Scheme>[
      (
        rule: 'Toned & defined: 3 × 10–12, leave 2–3 reps, 60–90s',
        goal: Goal.tonedAndDefined,
        minSets: 3,
        maxSets: 3,
        range: RepRange(10, 12),
        rpe: 7,
        restSeconds: 75,
        extraSetOnEmphasis: false,
      ),
      (
        rule: 'Stronger: 3–4 × 6–8, leave 2 reps, 90–150s',
        goal: Goal.stronger,
        minSets: 3,
        maxSets: 4,
        range: RepRange(6, 8),
        rpe: 8,
        restSeconds: 120,
        extraSetOnEmphasis: false,
      ),
      (
        rule:
            'Build curves: exact Toned & defined hypertrophy scheme, with '
            'emphasis volume supplied by assembly',
        goal: Goal.buildCurves,
        minSets: 3,
        maxSets: 3,
        range: RepRange(10, 12),
        rpe: 7,
        restSeconds: 75,
        extraSetOnEmphasis: false,
      ),
      (
        rule:
            'Feel healthier: 2–3 × 10–12, comfortable, never near failure, 60s',
        goal: Goal.feelHealthier,
        minSets: 2,
        maxSets: 3,
        range: RepRange(10, 12),
        rpe: 6,
        restSeconds: 60,
        extraSetOnEmphasis: false,
      ),
    ];

    for (final entry in schemes) {
      test(entry.rule, () {
        final scheme = config.schemeFor(entry.goal);
        expect(scheme.minSets, entry.minSets);
        expect(scheme.maxSets, entry.maxSets);
        expect(scheme.range, entry.range);
        expect(scheme.effort.rpe, entry.rpe);
        expect(scheme.rest.inSeconds, entry.restSeconds);
        expect(scheme.extraSetOnEmphasis, entry.extraSetOnEmphasis);
      });
    }

    test('every goal has an explicitly authored scheme', () {
      for (final goal in Goal.values) {
        expect(config.repSchemes[goal], isNotNull, reason: goal.name);
      }
    });

    test('build curves is exactly the toned scheme', () {
      final curves = config.schemeFor(Goal.buildCurves);
      final toned = config.schemeFor(Goal.tonedAndDefined);
      expect(curves, toned);

      final dose = curves.openingDose();
      expect(dose.targetReps, 10);
      expect(dose.sets, 3);
      expect(curves.openingDose(isEmphasis: true), dose);
    });
  });

  group('§2 RESOLVED the novice ramp', () {
    test('week zero starts at no more than 3 sets and RPE 7', () {
      expect(config.rpeRampBase, 7);
      expect(config.rpeRampPerWeek, 0.25);
      expect(config.setsRampBase, 3);
      expect(config.setsRampPerWeek, 0.25);
      for (final goal in Goal.values) {
        final ramped = config.schemeFor(goal, weeksTrained: 0);
        expect(ramped.maxSets, lessThanOrEqualTo(3), reason: goal.name);
        expect(ramped.effort.rpe, lessThanOrEqualTo(7), reason: goal.name);
        expect(ramped.effort.rir, greaterThanOrEqualTo(3), reason: goal.name);
      }
    });

    test('the ramp does not make an easier scheme harder', () {
      final ramped = config.schemeFor(Goal.feelHealthier, weeksTrained: 0);
      expect(ramped.effort.rpe, 6);
      expect(ramped.minSets, 2);
    });

    test('the goal anchor is fully reached at week 4', () {
      expect(config.schemeFor(Goal.stronger, weeksTrained: 3).maxSets, 3);
      expect(config.schemeFor(Goal.stronger, weeksTrained: 4).maxSets, 4);
      expect(config.schemeFor(Goal.stronger, weeksTrained: 4).effort.rpe, 8);
    });

    test('novice ramp is monotone in weeksTrained for every goal', () {
      for (final goal in Goal.values) {
        var previous = config.schemeFor(goal, weeksTrained: 0);
        for (var week = 1; week <= 52; week++) {
          final current = config.schemeFor(goal, weeksTrained: week);
          expect(current.maxSets, greaterThanOrEqualTo(previous.maxSets));
          expect(current.effort.rpe, greaterThanOrEqualTo(previous.effort.rpe));
          expect(
            current.maxSets,
            lessThanOrEqualTo(config.repSchemes[goal]!.maxSets),
          );
          expect(
            current.effort.rpe,
            lessThanOrEqualTo(config.repSchemes[goal]!.effort.rpe),
          );
          previous = current;
        }
      }
    });
  });

  group('§3 isolation windows', () {
    test('isolation and single-side work use 10–15 reps', () {
      const scheme = RepScheme(
        minSets: 3,
        maxSets: 3,
        range: RepRange(10, 12),
        effort: EffortTarget.rpe7,
        rest: Duration(seconds: 75),
      );
      expect(config.isolationRange, const RepRange(10, 15));
      expect(config.rangeFor(lateralRaise, scheme), const RepRange(10, 15));
      expect(config.rangeFor(singleArmRow, scheme), const RepRange(10, 15));
      expect(config.rangeFor(gobletSquat, scheme), const RepRange(10, 12));
    });

    test('after a jump, reps restart at 8–10 and the bridge is 4–5 reps', () {
      expect(config.isolationRestartRange, const RepRange(8, 10));
      expect(config.dropBridgeBackOffReps, const RepRange(4, 5));
    });
  });

  group('§5b the 6-week mesocycle', () {
    test('build 1–3, easier 4, push 5, deload 6 — pinned, not floating', () {
      expect(config.mesocycleWeeks, 6);
      expect(config.weekSetsDelta, <int>[0, 0, 0, -1, 0, 0]);
      expect(config.weekRpeDelta, <int>[0, 0, 0, -1, 0, -2]);
      expect(config.weekLoadScale, <double>[1, 1, 1, 1, 1, 0.8]);
      expect(
        [for (var week = 1; week <= 6; week++) config.weekKind(week)],
        <MesocycleWeekKind>[
          MesocycleWeekKind.build,
          MesocycleWeekKind.build,
          MesocycleWeekKind.build,
          MesocycleWeekKind.easier,
          MesocycleWeekKind.push,
          MesocycleWeekKind.deload,
        ],
      );
    });

    test('week 7 is week 1 of the next mesocycle', () {
      expect(config.weekKind(7), MesocycleWeekKind.build);
      expect(config.weekKind(10), MesocycleWeekKind.easier);
      expect(config.weekKind(12), MesocycleWeekKind.deload);
    });

    test(
      'the deload is meaningfully lighter and the easier week is not a stop',
      () {
        expect(config.weekLoadScaleFor(6), lessThan(0.9));
        expect(config.weekSetsDeltaFor(4), lessThan(0));
        expect(config.weekRpeDeltaFor(4), lessThan(0));
      },
    );

    test('week vectors apply deterministically from one base dose', () {
      const base = RepsDose(
        sets: 4,
        range: RepRange(6, 8),
        effort: EffortTarget(8),
        targetReps: 6,
      );
      for (var week = 1; week <= 12; week++) {
        expect(config.doseForWeek(base, week), config.doseForWeek(base, week));
      }
      expect(config.doseForWeek(base, 4), config.doseForWeek(base, 10));
      expect(config.doseForWeek(base, 6), config.doseForWeek(base, 12));
    });
  });

  group('§4 guardrail constants', () {
    test('±10% cap, 2% deadband, RIR clamped at 5, two-step ceiling', () {
      expect(config.maxChangeFraction, 0.10);
      expect(config.deadbandFraction, 0.02);
      expect(config.maxInterpretedRir, 5);
      expect(config.maxStepsPerAdjustment, 2);
      expect(config.loadFractionPerRep, 0.03);
      expect(config.minIncrementStepFraction, 0.50);
      expect(config.epleyConstant, 30);
    });

    test('§4.1 calibration allows +15% / two steps above RPE 4', () {
      expect(config.calibrationRegimeMaxRpe, 4);
      expect(config.calibrationMaxIncreaseFraction, 0.15);
      expect(config.calibrationMaxSteps, 2);
    });

    test('§7 probe coefficients are one movement-class table', () {
      expect(config.calibrationProbeReps, 8);
      expect(config.calibrationMaxTestSets, 2);
      expect(config.calibrationJumpFraction, 0.15);
      expect(config.calibrationMinCleanReps, 5);
      expect(config.probeLoadFractionByMovementClass, <MovementClass, double>{
        MovementClass.compoundLower: 0.6,
        MovementClass.compoundUpperPush: 0.3,
        MovementClass.compoundUpperPull: 0.3,
        MovementClass.isolationLower: 0.15,
        MovementClass.isolationUpper: 0.15,
        MovementClass.core: 0.15,
        MovementClass.cardio: 0.15,
      });
    });

    test(
      '§5 stall and reactive deload numbers are pinned for resolveSession',
      () {
        expect(config.stallSessions, 3);
        expect(config.stallDeloadFraction, 0.10);
        expect(config.missedBottomDropFraction, 0.10);
        expect(config.lowEnergyLoadFraction, 0.90);
      },
    );

    test('§8 assembly numbers', () {
      expect(config.exerciseCountByMinutes, {30: 4, 45: 6, 60: 8});
      expect(config.warmUpMinutesByAgeBand, <int>[5, 5, 5, 6, 7]);
      expect(config.seatedPreferenceWeight, 1);
    });
  });

  group('§8 machine-affinity spectrum', () {
    Profile profile({
      AgeBand age = AgeBand.age18To29,
      ProfileExperienceTier experience = ProfileExperienceTier.newToIt,
      GymComfort comfort = GymComfort.low,
    }) => Profile(
      ageBand: age,
      daysPerWeek: TrainingDaysPerWeek.three,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.tonedAndDefined,
      emphasis: Emphasis.balanced,
      experienceTier: experience,
      gymComfort: comfort,
      weeksTrained: 0,
      mesocycleIndex: 1,
    );

    test('all DRAFT score contributions are pinned in ProgrammingConfig', () {
      expect(config.machineAffinityNewToIt, 0.6);
      expect(config.machineAffinityBeenAWhile, 0.3);
      expect(config.machineAffinityTrainsRegularly, 0.1);
      expect(config.machineAffinityAge50To59, 0.4);
      expect(config.machineAffinityAge60Plus, 0.5);
      expect(config.machineAffinityLowComfort, 0.2);
      expect(config.machineAffinityMostlyFineComfort, 0.1);
      expect(config.machineAffinityTotallyAtHomeComfort, 0);
    });

    test('experience + age + comfort is additive and clamped to 0–1', () {
      expect(machineAffinityFor(profile(), config), 0.8);
      expect(
        machineAffinityFor(
          profile(
            age: AgeBand.age50To59,
            experience: ProfileExperienceTier.beenAWhile,
            comfort: GymComfort.mostlyFine,
          ),
          config,
        ),
        closeTo(0.8, 1e-12),
      );
      expect(
        machineAffinityFor(
          profile(
            age: AgeBand.age60Plus,
            experience: ProfileExperienceTier.trainsRegularly,
            comfort: GymComfort.totallyAtHome,
          ),
          config,
        ),
        0.6,
      );
      expect(
        machineAffinityFor(
          profile(),
          ProgrammingConfig(
            machineAffinityNewToIt: 0.8,
            machineAffinityLowComfort: 0.8,
          ),
        ),
        1,
      );
    });

    test('age 50+ plus new-to-it reaches 1.0 by summation', () {
      expect(
        machineAffinityFor(
          profile(age: AgeBand.age50To59, comfort: GymComfort.totallyAtHome),
          config,
        ),
        1,
      );
      expect(
        machineAffinityFor(
          profile(age: AgeBand.age60Plus, comfort: GymComfort.totallyAtHome),
          config,
        ),
        1,
      );
    });

    test('affinity is monotone in experience, age, and comfort inputs', () {
      final experience = <ProfileExperienceTier>[
        ProfileExperienceTier.trainsRegularly,
        ProfileExperienceTier.beenAWhile,
        ProfileExperienceTier.newToIt,
      ];
      final ages = AgeBand.values;
      final comfort = <GymComfort>[
        GymComfort.totallyAtHome,
        GymComfort.mostlyFine,
        GymComfort.low,
      ];
      for (final age in ages) {
        for (final gymComfort in comfort) {
          final values = [
            for (final tier in experience)
              machineAffinityFor(
                profile(age: age, experience: tier, comfort: gymComfort),
                config,
              ),
          ];
          expect(values[1], greaterThanOrEqualTo(values[0]));
          expect(values[2], greaterThanOrEqualTo(values[1]));
        }
      }
      for (final tier in experience) {
        for (final gymComfort in comfort) {
          final values = [
            for (final age in ages)
              machineAffinityFor(
                profile(age: age, experience: tier, comfort: gymComfort),
                config,
              ),
          ];
          for (var index = 1; index < values.length; index++) {
            expect(values[index], greaterThanOrEqualTo(values[index - 1]));
          }
        }
      }
      for (final age in ages) {
        for (final tier in experience) {
          final values = [
            for (final gymComfort in comfort)
              machineAffinityFor(
                profile(age: age, experience: tier, comfort: gymComfort),
                config,
              ),
          ];
          expect(values[1], greaterThanOrEqualTo(values[0]));
          expect(values[2], greaterThanOrEqualTo(values[1]));
        }
      }
    });
  });

  test('Profile cannot express five training days per week', () {
    expect(TrainingDaysPerWeek.values.map((days) => days.value), <int>[
      2,
      3,
      4,
    ]);
    expect(TrainingDaysPerWeek.values.any((days) => days.value == 5), isFalse);
  });

  group('§3 the two markets', () {
    test(
      'metric: 20 kg bar, 2.5/5 kg bar steps, 2 kg dumbbells, 5 kg pins',
      () {
        final metric = config.loadTable(UnitSystem.metric);
        expect(metric.barbellBar, const Kg(20));
        expect(metric.barbellUpperStep, const Kg(2.5));
        expect(metric.barbellLowerStep, const Kg(5));
        expect(metric.dumbbellStep, const Kg(2));
        expect(metric.machineStep, const Kg(5));
        expect(metric.assistedStackMaxAssistance, const Kg(50));
        expect(metric.assistedStackStep, const Kg(5));
        expect(metric.cableStep, const Kg(2.5));
      },
    );

    test(
      'imperial: 45 lb bar, 5/10 lb bar steps, 5 lb dumbbells, 10 lb pins',
      () {
        final imperial = config.loadTable(UnitSystem.imperial);
        expect(imperial.barbellBar.inLb, closeTo(45, 1e-9));
        expect(imperial.barbellUpperStep.inLb, closeTo(5, 1e-9));
        expect(imperial.barbellLowerStep.inLb, closeTo(10, 1e-9));
        expect(imperial.dumbbellStep.inLb, closeTo(5, 1e-9));
        expect(imperial.machineStep.inLb, closeTo(10, 1e-9));
        expect(imperial.assistedStackMaxAssistance.inLb, closeTo(110, 1e-9));
        expect(imperial.assistedStackStep.inLb, closeTo(10, 1e-9));
        expect(imperial.cableStep.inLb, closeTo(5, 1e-9));
      },
    );
  });

  test('independent shipped configs carry the same decision values', () {
    expect(
      ProgrammingConfig().maxChangeFraction,
      ProgrammingConfig().maxChangeFraction,
    );
  });
}
