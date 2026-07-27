/// Structured telemetry for specified degradation and possible user flows.
///
/// Invalid external data is rejected at its boundary. Inside the engine, types
/// are trusted and programmer/configuration errors are assertions, not warnings.
library;

enum WarningCode {
  /// Plan assembly filled a block only after retrying at the most permissive
  /// experience tier. Comfort, age and safety constraints stay hard.
  experienceTierRelaxed,

  /// The catalog did not have enough distinct eligible exercises to deduplicate
  /// this role across the whole week. The day itself remains deduplicated.
  weeklyDedupRelaxed,

  /// No exercise survived the fixed fallback ladder, so the block was omitted.
  blockDropped,

  /// An excluded planned exercise was replaced from its resolved swap list.
  excludedExerciseSubstituted,

  /// An exercise was excluded but no usable resolved swap remained, so the total
  /// fallback kept the planned exercise.
  excludedExerciseHadNoSwap,

  /// A mid-session event named an exercise that is not in this session.
  unknownSessionExercise,

  /// An event was valid but could not affect an exercise in its current state.
  sessionEventIgnored,

  /// The same idempotent session modifier was requested more than once.
  sessionModifierAlreadyApplied,

  /// No eligible swap remained after tier and exclusion filtering.
  noEligibleSessionSwap,

  /// Calibration hit the safety floor without five clean reps; the movement
  /// stopped and an easier tier-1/2 alternative was offered.
  calibrationFloorFailed,

  /// A plan edit could not find its source slot or resolved replacement.
  planEditTargetMissing,
}

final class EngineWarning {
  const EngineWarning(this.code, [this.detail = '']);

  final WarningCode code;
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is EngineWarning && other.code == code && other.detail == detail;

  @override
  int get hashCode => Object.hash(code, detail);

  @override
  String toString() => detail.isEmpty
      ? 'EngineWarning(${code.name})'
      : 'EngineWarning(${code.name}: $detail)';
}
