sealed class ExerciseVisualSource {
  const ExerciseVisualSource();
}

final class BundledExerciseVideoSource extends ExerciseVisualSource {
  const BundledExerciseVideoSource(this.assetPath);

  final String assetPath;

  @override
  bool operator ==(Object other) =>
      other is BundledExerciseVideoSource && other.assetPath == assetPath;

  @override
  int get hashCode => assetPath.hashCode;
}

final class BundledStillsSource extends ExerciseVisualSource {
  const BundledStillsSource(this.pos1Asset, this.pos2Asset);

  final String pos1Asset;
  final String pos2Asset;

  @override
  bool operator ==(Object other) =>
      other is BundledStillsSource &&
      other.pos1Asset == pos1Asset &&
      other.pos2Asset == pos2Asset;

  @override
  int get hashCode => Object.hash(pos1Asset, pos2Asset);
}

const bundledExerciseVideoSources = <String, BundledExerciseVideoSource>{
  'dumbbell-goblet-squat': BundledExerciseVideoSource(
    'assets/videos/goblet-squat-loop.mp4',
  ),
  'dumbbell-lateral-raise': BundledExerciseVideoSource(
    'assets/videos/lateral-raise-loop.mp4',
  ),
};

const exercisesWithStills = <String>{
  'assisted-dip',
  'barbell-bench-press',
  'barbell-deadlift',
  'barbell-hip-thrust',
  'barbell-romanian-deadlift',
  'barbell-squat',
  'bodyweight-assisted-chin-up',
  'bodyweight-push-up',
  'bodyweight-reverse-lunge',
  'bodyweight-squat',
  'cable-pull-through',
  'cable-rope-kneeling-crunch',
  'cable-rope-pushdown',
  'cable-standing-glute-kickback',
  'crunches',
  'dead-bug',
  'dumbbell-bench-press',
  'dumbbell-bulgarian-split-squat',
  'dumbbell-curl',
  'dumbbell-glute-bridge',
  'dumbbell-goblet-squat',
  'dumbbell-hip-thrust',
  'dumbbell-incline-bench-press',
  'dumbbell-lateral-raise',
  'dumbbell-romanian-deadlift',
  'dumbbell-row-unilateral',
  'dumbbell-seated-overhead-press',
  'elbow-side-plank',
  'machine-back-extension',
  'machine-chest-press',
  'machine-glute-kickback',
  'machine-hip-abduction',
  'machine-leg-extension',
  'machine-leg-press',
  'machine-pulldown',
  'machine-rear-deltoid-row',
  'machine-seated-cable-row',
  'machine-seated-hamstring-curl',
  'machine-standing-calf-raises',
  'plank',
};

ExerciseVisualSource? resolveExerciseVisualSource(String exerciseId) =>
    bundledExerciseVideoSources[exerciseId] ?? exerciseStills(exerciseId);

BundledStillsSource? exerciseStills(String exerciseId) =>
    exercisesWithStills.contains(exerciseId)
    ? BundledStillsSource(
        'assets/images/exercises/$exerciseId-1.jpg',
        'assets/images/exercises/$exerciseId-2.jpg',
      )
    : null;
