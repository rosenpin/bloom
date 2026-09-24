import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/features/session/data/exercise_visual_source.dart';

void main() {
  test('bundled loops take priority over owned stills', () {
    expect(
      resolveExerciseVisualSource('dumbbell-goblet-squat'),
      const BundledExerciseVideoSource('assets/videos/goblet-squat-loop.mp4'),
    );
    expect(
      resolveExerciseVisualSource('dumbbell-lateral-raise'),
      const BundledExerciseVideoSource('assets/videos/lateral-raise-loop.mp4'),
    );
  });

  test(
    'owned stills use both frames and unknown exercises use placeholders',
    () {
      expect(
        resolveExerciseVisualSource('barbell-hip-thrust'),
        const BundledStillsSource(
          'assets/images/exercises/barbell-hip-thrust-1.jpg',
          'assets/images/exercises/barbell-hip-thrust-2.jpg',
        ),
      );
      expect(resolveExerciseVisualSource('machine-chest-press'), isNull);
      expect(resolveExerciseVisualSource('dead-bug'), isNull);
      expect(resolveExerciseVisualSource('unmapped-exercise'), isNull);
    },
  );

  test(
    'every listed still pair exists and belongs to the exercise catalog',
    () {
      final ids = engine.catalogV1.exercises
          .map((exercise) => exercise.id)
          .toSet();
      for (final id in exercisesWithStills) {
        expect(ids, contains(id));
        expect(File('assets/images/exercises/$id-1.jpg').existsSync(), isTrue);
        expect(File('assets/images/exercises/$id-2.jpg').existsSync(), isTrue);
      }
    },
  );
}
