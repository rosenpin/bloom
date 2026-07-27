import '../data/exercise_video_cache.dart';
import '../data/exercise_video_source.dart';

List<String> streamedVideoUrlsForExerciseIds(Iterable<String> exerciseIds) {
  final urls = <String>{};
  for (final exerciseId in exerciseIds) {
    final source = resolveExerciseVideoSource(exerciseId);
    if (source is StreamedExerciseVideoSource) {
      urls
        ..add(source.sideUrl)
        ..add(source.frontUrl);
    }
  }
  return List<String>.unmodifiable(urls);
}

Future<void> prefetchExerciseVideos(
  ExerciseVideoCache cache,
  Iterable<String> exerciseIds,
) => cache.prefetch(streamedVideoUrlsForExerciseIds(exerciseIds));
