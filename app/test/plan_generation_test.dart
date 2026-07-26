import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/features/onboarding/domain/onboarding_answers.dart';
import 'package:womens_gym/features/plan/data/plan_codec.dart';

void main() {
  final cases = <String, OnboardingAnswers>{
    'two-day older beginner': _answers(
      age: engine.AgeBand.age60Plus,
      days: engine.TrainingDaysPerWeek.two,
      minutes: engine.SessionMinutes.thirty,
      goal: engine.Goal.feelHealthier,
      emphasis: engine.Emphasis.balanced,
      experience: engine.ProfileExperienceTier.newToIt,
      comfort: engine.GymComfort.low,
    ),
    'three-day glute returner': _answers(
      age: engine.AgeBand.age30To39,
      days: engine.TrainingDaysPerWeek.three,
      minutes: engine.SessionMinutes.fortyFive,
      goal: engine.Goal.buildCurves,
      emphasis: engine.Emphasis.glutes,
      experience: engine.ProfileExperienceTier.beenAWhile,
      comfort: engine.GymComfort.mostlyFine,
    ),
    'four-day regular lifter': _answers(
      age: engine.AgeBand.age18To29,
      days: engine.TrainingDaysPerWeek.four,
      minutes: engine.SessionMinutes.sixty,
      goal: engine.Goal.stronger,
      emphasis: engine.Emphasis.back,
      experience: engine.ProfileExperienceTier.trainsRegularly,
      comfort: engine.GymComfort.totallyAtHome,
    ),
  };

  for (final testCase in cases.entries) {
    test('${testCase.key} generates and persists a replayable plan', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 7, 26, 10)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      await container.read(onboardingRepositoryProvider).save(testCase.value);

      final generated = await container
          .read(planGenerationServiceProvider)
          .generate();
      final rows = await database.select(database.plans).get();
      final profile = await container.read(onboardingRepositoryProvider).load();

      expect(generated.plan.days, hasLength(testCase.value.daysPerWeek!.value));
      expect(rows, hasLength(1));
      expect(rows.single.engineVersion, generated.plan.stamps.engineVersion);
      expect(rows.single.configHash, generated.plan.stamps.configHash);
      expect(rows.single.contentHash, generated.plan.stamps.contentHash);
      expect(rows.single.profileHash, generated.plan.stamps.profileHash);
      expect(
        PlanCodec.decode(rows.single.documentJson),
        equals(generated.plan),
      );
      expect(profile?.completed, isTrue);
    });
  }
}

OnboardingAnswers _answers({
  required engine.AgeBand age,
  required engine.TrainingDaysPerWeek days,
  required engine.SessionMinutes minutes,
  required engine.Goal goal,
  required engine.Emphasis emphasis,
  required engine.ProfileExperienceTier experience,
  required engine.GymComfort comfort,
}) => OnboardingAnswers(
  unitSystem: engine.UnitSystem.metric,
  ageBand: age,
  goal: goal,
  daysPerWeek: days,
  sessionMinutes: minutes,
  experienceTier: experience,
  gymComfort: comfort,
  emphasis: emphasis,
  otherActivities: const {
    engine.ActivityKind.yogaPilates: 2,
    engine.ActivityKind.running: 1,
  },
);
