import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/features/onboarding/domain/onboarding_answers.dart';

void main() {
  test('legacy no-emphasis value migrates to balanced', () {
    final answers = OnboardingAnswers.fromJson(
      '{"schemaVersion":1,"unitSystem":"metric","ageBand":"age30To39",'
      '"goal":"tonedAndDefined","daysPerWeek":"three",'
      '"sessionMinutes":"fortyFive","experienceTier":"beenAWhile",'
      '"gymComfort":"mostlyFine","emphasis":"none"}',
      fallbackUnitSystem: engine.UnitSystem.metric,
    );

    expect(answers.emphasis, engine.Emphasis.balanced);
    expect(answers.hasAllQuizAnswers, isTrue);
    expect(answers.resumePath, '/onboarding/activities');
  });

  test('balanced emphasis round-trips as the single no-emphasis value', () {
    const answers = OnboardingAnswers(
      unitSystem: engine.UnitSystem.metric,
      emphasis: engine.Emphasis.balanced,
    );

    final decoded = OnboardingAnswers.fromJson(
      answers.toJson(),
      fallbackUnitSystem: engine.UnitSystem.imperial,
    );

    expect(decoded.emphasis, engine.Emphasis.balanced);
    expect(decoded.toJson(), contains('"emphasis":"balanced"'));
  });
}
