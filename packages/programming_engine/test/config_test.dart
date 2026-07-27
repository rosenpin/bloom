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

  group('§2 RESOLVED the novice cap', () {
    test('first 4 weeks: every scheme capped at 3 sets and 3+ RIR', () {
      expect(config.noviceWeeks, 4);
      for (final goal in Goal.values) {
        final capped = config.schemeFor(goal, weeksTrained: 0);
        expect(capped.maxSets, lessThanOrEqualTo(3), reason: goal.name);
        expect(capped.effort.rpe, lessThanOrEqualTo(7), reason: goal.name);
        expect(capped.effort.rir, greaterThanOrEqualTo(3), reason: goal.name);
      }
    });

    test('the cap does not make an easier scheme harder', () {
      final capped = config.schemeFor(Goal.feelHealthier, weeksTrained: 0);
      expect(capped.effort.rpe, 6);
      expect(capped.minSets, 2);
    });

    test('goal schemes unlock from week 5', () {
      expect(config.schemeFor(Goal.stronger, weeksTrained: 3).maxSets, 3);
      expect(config.schemeFor(Goal.stronger, weeksTrained: 4).maxSets, 4);
      expect(config.schemeFor(Goal.stronger, weeksTrained: 4).effort.rpe, 8);
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
      expect(config.easierWeekIndex, 4);
      expect(config.deloadWeekIndex, 6);
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
        expect(config.deloadWeekLoadFraction, lessThan(0.9));
        expect(config.easierWeekSetsDelta, lessThan(0));
        expect(config.easierWeekRpeDelta, lessThan(0));
      },
    );
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

    test(
      '§7 the probe: 8 reps, max 2 test sets, +2 steps, 5 clean reps minimum',
      () {
        expect(config.calibrationProbeReps, 8);
        expect(config.calibrationMaxTestSets, 2);
        expect(config.calibrationProbeStepJump, 2);
        expect(config.calibrationMinCleanReps, 5);
      },
    );

    test('§7 RESOLVED lower-body machines probe at +50–100% per test set', () {
      expect(config.lowerBodyMachineProbeJumpMin, 0.50);
      expect(config.lowerBodyMachineProbeJumpMax, 1.00);
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
      expect(config.warmUpMinutes, 5);
      expect(config.seatedPreferenceAge, 60);
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
      expect(config.machineAffinityNewToIt, 0.5);
      expect(config.machineAffinityBeenAWhile, 0.3);
      expect(config.machineAffinityTrainsRegularly, 0.1);
      expect(config.machineAffinityAge50To59, 0.3);
      expect(config.machineAffinityAge60Plus, 0.4);
      expect(config.machineAffinityLowComfort, 0.2);
      expect(config.machineAffinityMostlyFineComfort, 0.1);
      expect(config.machineAffinityTotallyAtHomeComfort, 0);
      expect(config.machineAffinityForcedAge, 50);
    });

    test('experience + age + comfort is additive and clamped to 0–1', () {
      expect(machineAffinityFor(profile(), config), 0.7);
      expect(
        machineAffinityFor(
          profile(
            age: AgeBand.age50To59,
            experience: ProfileExperienceTier.beenAWhile,
            comfort: GymComfort.mostlyFine,
          ),
          config,
        ),
        closeTo(0.7, 1e-12),
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
        0.5,
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

    test('age 50+ plus new-to-it is forced to 1.0', () {
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
