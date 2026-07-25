library;

import 'package:programming_engine/programming_engine.dart';

typedef PersonaFixture = ({String name, Profile profile});

const personaFixtures = <PersonaFixture>[
  (
    name: '01 Maya, 24',
    profile: Profile(
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
  ),
  (
    name: '02 Dana, 31',
    profile: Profile(
      ageBand: AgeBand.age30To39,
      daysPerWeek: TrainingDaysPerWeek.two,
      sessionMinutes: SessionMinutes.thirty,
      goal: Goal.feelHealthier,
      emphasis: Emphasis.balanced,
      experienceTier: ProfileExperienceTier.beenAWhile,
      gymComfort: GymComfort.mostlyFine,
      weeksTrained: 4,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '03 Ruth, 63',
    profile: Profile(
      ageBand: AgeBand.age60Plus,
      daysPerWeek: TrainingDaysPerWeek.two,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.feelHealthier,
      emphasis: Emphasis.balanced,
      experienceTier: ProfileExperienceTier.newToIt,
      gymComfort: GymComfort.low,
      weeksTrained: 0,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '04 Shir, 27',
    profile: Profile(
      ageBand: AgeBand.age18To29,
      daysPerWeek: TrainingDaysPerWeek.four,
      sessionMinutes: SessionMinutes.sixty,
      goal: Goal.buildCurves,
      emphasis: Emphasis.glutes,
      experienceTier: ProfileExperienceTier.trainsRegularly,
      gymComfort: GymComfort.totallyAtHome,
      weeksTrained: 12,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '05 Noa, 35',
    profile: Profile(
      ageBand: AgeBand.age30To39,
      daysPerWeek: TrainingDaysPerWeek.three,
      sessionMinutes: SessionMinutes.sixty,
      goal: Goal.stronger,
      emphasis: Emphasis.balanced,
      experienceTier: ProfileExperienceTier.beenAWhile,
      gymComfort: GymComfort.mostlyFine,
      weeksTrained: 8,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '06 Lior, 22',
    profile: Profile(
      ageBand: AgeBand.age18To29,
      daysPerWeek: TrainingDaysPerWeek.three,
      sessionMinutes: SessionMinutes.thirty,
      goal: Goal.tonedAndDefined,
      emphasis: Emphasis.glutes,
      experienceTier: ProfileExperienceTier.newToIt,
      gymComfort: GymComfort.low,
      weeksTrained: 0,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '07 Tamar, 45',
    profile: Profile(
      ageBand: AgeBand.age40To49,
      daysPerWeek: TrainingDaysPerWeek.three,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.tonedAndDefined,
      emphasis: Emphasis.core,
      experienceTier: ProfileExperienceTier.beenAWhile,
      gymComfort: GymComfort.mostlyFine,
      weeksTrained: 8,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '08 Vered, 52',
    profile: Profile(
      ageBand: AgeBand.age50To59,
      daysPerWeek: TrainingDaysPerWeek.two,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.stronger,
      emphasis: Emphasis.balanced,
      experienceTier: ProfileExperienceTier.beenAWhile,
      gymComfort: GymComfort.mostlyFine,
      weeksTrained: 0,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '09 Alma, 29, runs',
    profile: Profile(
      ageBand: AgeBand.age18To29,
      daysPerWeek: TrainingDaysPerWeek.two,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.tonedAndDefined,
      emphasis: Emphasis.balanced,
      experienceTier: ProfileExperienceTier.beenAWhile,
      gymComfort: GymComfort.mostlyFine,
      weeksTrained: 8,
      mesocycleIndex: 1,
      otherActivities: [
        WeeklyActivity(kind: ActivityKind.running, sessionsPerWeek: 3),
      ],
    ),
  ),
  (
    name: '10 Yael, 33',
    profile: Profile(
      ageBand: AgeBand.age30To39,
      daysPerWeek: TrainingDaysPerWeek.four,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.buildCurves,
      emphasis: Emphasis.back,
      experienceTier: ProfileExperienceTier.trainsRegularly,
      gymComfort: GymComfort.totallyAtHome,
      weeksTrained: 12,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '11 Roni, 26',
    profile: Profile(
      ageBand: AgeBand.age18To29,
      daysPerWeek: TrainingDaysPerWeek.three,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.tonedAndDefined,
      emphasis: Emphasis.arms,
      experienceTier: ProfileExperienceTier.beenAWhile,
      gymComfort: GymComfort.mostlyFine,
      weeksTrained: 8,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '12 Michal, 40',
    profile: Profile(
      ageBand: AgeBand.age40To49,
      daysPerWeek: TrainingDaysPerWeek.three,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.feelHealthier,
      emphasis: Emphasis.balanced,
      experienceTier: ProfileExperienceTier.trainsRegularly,
      gymComfort: GymComfort.totallyAtHome,
      weeksTrained: 12,
      mesocycleIndex: 1,
    ),
  ),
  (
    name: '13 Maya, mesocycle 2',
    profile: Profile(
      ageBand: AgeBand.age18To29,
      daysPerWeek: TrainingDaysPerWeek.three,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.tonedAndDefined,
      emphasis: Emphasis.glutes,
      experienceTier: ProfileExperienceTier.newToIt,
      gymComfort: GymComfort.low,
      weeksTrained: 0,
      mesocycleIndex: 2,
    ),
  ),
  (
    name: '14 Efrat, 58',
    profile: Profile(
      ageBand: AgeBand.age50To59,
      daysPerWeek: TrainingDaysPerWeek.three,
      sessionMinutes: SessionMinutes.fortyFive,
      goal: Goal.tonedAndDefined,
      emphasis: Emphasis.glutes,
      experienceTier: ProfileExperienceTier.newToIt,
      gymComfort: GymComfort.low,
      weeksTrained: 0,
      mesocycleIndex: 1,
    ),
  ),
];

Plan successfulPlan(
  Profile profile, {
  ProgrammingConfig config = const ProgrammingConfig(),
  ContentCatalog? catalog,
}) {
  final result = assemblePlan(profile, config, catalog ?? catalogV1);
  if (result case Success<Plan>(:final value)) return value;
  throw StateError((result as Failure<Plan>).error.toString());
}

String semanticProjection(Plan plan) {
  final output = StringBuffer();
  for (final day in plan.days) {
    output.writeln(
      'day ${day.dayIndex}: ${day.kind.name} '
      '(warmup ${day.warmUpMinutes}m${day.hasCardioFinisher ? ', finisher' : ''})',
    );
    for (final exercise in day.exercises) {
      final buildDose = exercise.doseFor(MesocycleWeekKind.build);
      output.writeln(
        '  ${exercise.exerciseId} [${exercise.blockRole.name}] '
        '${_dose(buildDose)}',
      );
    }
  }
  return output.toString().trimRight();
}

String _dose(Dose dose) => switch (dose) {
  RepsDose(:final sets, :final range, :final effort) =>
    '${sets}x$range@${effort.rpe}',
  TimedDose(:final sets, :final hold) => '${sets}x${hold.inSeconds}s',
};
