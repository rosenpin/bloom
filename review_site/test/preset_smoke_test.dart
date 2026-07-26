import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart';
import 'package:review_site/models/persona_presets.dart';

void main() {
  test('all 14 presets exist', () {
    expect(personaPresets, hasLength(14));
  });

  test('presets 1 and 3 assemble non-empty plans', () {
    for (final index in const <int>[0, 2]) {
      final result = assemblePlan(
        personaPresets[index].state.toProfile(),
        const ProgrammingConfig(),
        catalogV1,
      );
      expect(result, isA<Success<Plan>>(), reason: personaPresets[index].name);
      final plan = result.valueOrNull!;
      expect(plan.days, isNotEmpty, reason: personaPresets[index].name);
      expect(
        plan.days.expand((day) => day.exercises),
        isNotEmpty,
        reason: personaPresets[index].name,
      );
    }
  });
}
