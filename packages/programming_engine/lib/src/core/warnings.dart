/// Structured warnings. Loud in telemetry, silent for her.
///
/// `ENGINE.md` › "Failure behaviour": everything downstream of plan time is
/// **total** — it returns a value plus warnings and never throws. A crash
/// mid-workout is far worse than a slightly worse suggestion.
library;

enum WarningCode {
  /// Body mass was missing or non-positive; the bodyweight term was dropped and
  /// the math ran on external load only.
  invalidBodyMass,

  /// `bw_contribution` outside 0..1; clamped.
  bwContributionOutOfRange,

  /// Reported reps were non-positive; clamped to 1.
  invalidReps,

  /// The prescribed target reps sat outside the rep range; clamped into it.
  targetRepsOutOfRange,

  /// A rep range arrived inverted (min > max); ends were swapped.
  invertedRepRange,

  /// The last recorded load was lighter than anything this equipment can express;
  /// the equipment floor was used as the base.
  loadBelowEquipmentFloor,

  /// The last recorded load isn't on this equipment's ladder (imported history, or
  /// a gym with odd plates); it was snapped down before the math ran.
  lastLoadNotRepresentable,

  /// A load was NaN or infinite; the equipment floor was used instead.
  nonFiniteLoad,

  /// Days since her last session was negative; treated as 0.
  negativeLayoff,

  /// The equipment step for this exercise was non-positive; the family default
  /// for her unit system was used.
  invalidEquipmentStep,

  /// The suggestion was pinned to the equipment floor because the computed load
  /// fell below it.
  clampedToEquipmentFloor,

  /// A load-metric exercise had no representable load at all; fell back to a rep
  /// target.
  noRepresentableLoad,

  /// Plan assembly exhausted the profile's gym-comfort candidates for a block
  /// and retried at the most permissive comfort level.
  gymComfortRelaxed,

  /// Plan assembly still could not fill a block after relaxing gym comfort and
  /// retried at the most permissive experience tier.
  experienceTierRelaxed,

  /// The catalog did not have enough distinct eligible exercises to deduplicate
  /// this role across the whole week. The day itself remains deduplicated.
  weeklyDedupRelaxed,

  /// No exercise survived the fixed fallback ladder, so the block was omitted.
  blockDropped,

  /// A swap edge pointed at an absent or retired exercise and was skipped.
  danglingSwapSkipped,

  /// A swap edge failed its region/session-purpose compatibility guard.
  invalidSwapSkipped,

  /// An excluded planned exercise was replaced from its resolved swap list.
  excludedExerciseSubstituted,

  /// An exercise was excluded but no usable resolved swap remained, so the total
  /// fallback kept the planned exercise.
  excludedExerciseHadNoSwap,

  /// A plan contained no day to resolve.
  noPlanDayAvailable,

  /// Every planned day for the calendar week was already completed. The total
  /// fallback repeats the final day and reports this warning.
  planWeekAlreadyComplete,

  /// A resolved plan snapshot did not carry the requested week dose. A stable
  /// fallback dose was used.
  missingWeekDose,

  /// A malformed mesocycle configuration was clamped to a usable value.
  invalidMesocycleConfiguration,
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
