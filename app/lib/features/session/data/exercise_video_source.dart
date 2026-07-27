import 'exercise_media_catalog.dart';

enum ExerciseVideoAngle { front, side }

sealed class ExerciseVideoSource {
  const ExerciseVideoSource();
}

final class BundledExerciseVideoSource extends ExerciseVideoSource {
  const BundledExerciseVideoSource(this.assetPath);

  final String assetPath;

  @override
  bool operator ==(Object other) =>
      other is BundledExerciseVideoSource && other.assetPath == assetPath;

  @override
  int get hashCode => assetPath.hashCode;
}

final class StreamedExerciseVideoSource extends ExerciseVideoSource {
  const StreamedExerciseVideoSource({
    required this.frontUrl,
    required this.sideUrl,
    required this.frontThumbnailUrl,
    required this.sideThumbnailUrl,
  });

  final String frontUrl;
  final String sideUrl;
  final String frontThumbnailUrl;
  final String sideThumbnailUrl;

  String videoUrl(ExerciseVideoAngle angle) => switch (angle) {
    ExerciseVideoAngle.front => frontUrl,
    ExerciseVideoAngle.side => sideUrl,
  };

  String thumbnailUrl(ExerciseVideoAngle angle) => switch (angle) {
    ExerciseVideoAngle.front => frontThumbnailUrl,
    ExerciseVideoAngle.side => sideThumbnailUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is StreamedExerciseVideoSource &&
      other.frontUrl == frontUrl &&
      other.sideUrl == sideUrl &&
      other.frontThumbnailUrl == frontThumbnailUrl &&
      other.sideThumbnailUrl == sideThumbnailUrl;

  @override
  int get hashCode =>
      Object.hash(frontUrl, sideUrl, frontThumbnailUrl, sideThumbnailUrl);
}

const bundledExerciseVideoSources = <String, BundledExerciseVideoSource>{
  'dumbbell-goblet-squat': BundledExerciseVideoSource(
    'assets/videos/goblet-squat-loop.mp4',
  ),
  'dumbbell-lateral-raise': BundledExerciseVideoSource(
    'assets/videos/lateral-raise-loop.mp4',
  ),
};

const placeholderExerciseVideoIds = <String>{
  // TODO: Fill these from the MuscleWiki API once the commercial key is active.
  'machine-chest-press',
  'dead-bug',
};

ExerciseVideoSource? resolveExerciseVideoSource(String exerciseId) {
  final bundled = bundledExerciseVideoSources[exerciseId];
  if (bundled != null) return bundled;

  final media = exerciseMediaCatalog[exerciseId];
  if (media == null) return null;
  return StreamedExerciseVideoSource(
    frontUrl: media.frontVideoUrl,
    sideUrl: media.sideVideoUrl,
    frontThumbnailUrl: media.frontThumbnailUrl,
    sideThumbnailUrl: media.sideThumbnailUrl,
  );
}
