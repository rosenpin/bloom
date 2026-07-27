import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/features/session/data/exercise_video_source.dart';

void main() {
  test('every engine exercise has an intentional video resolution', () {
    final unresolved = <String>{};
    for (final exercise in engine.catalogV1.exercises) {
      if (resolveExerciseVideoSource(exercise.id) == null) {
        unresolved.add(exercise.id);
      }
    }

    expect(unresolved, placeholderExerciseVideoIds);
    expect(
      engine.catalogV1.exercises,
      everyElement(
        predicate<engine.Exercise>(
          (exercise) =>
              resolveExerciseVideoSource(exercise.id) != null ||
              placeholderExerciseVideoIds.contains(exercise.id),
          'resolves to bundled media, streamed media, or a named placeholder',
        ),
      ),
    );
  });

  test('every streamed URL is female MuscleWiki HTTPS media', () {
    for (final exercise in engine.catalogV1.exercises) {
      final source = resolveExerciseVideoSource(exercise.id);
      if (source is! StreamedExerciseVideoSource) continue;

      final urls = [
        source.frontUrl,
        source.sideUrl,
        source.frontThumbnailUrl,
        source.sideThumbnailUrl,
      ];
      for (final url in urls) {
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https', reason: '${exercise.id}: $url');
        expect(
          uri.host,
          'media.musclewiki.com',
          reason: '${exercise.id}: $url',
        );
        expect(url, contains('female'), reason: '${exercise.id}: $url');
      }
    }
  });
}
