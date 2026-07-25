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
  String toString() =>
      detail.isEmpty ? 'EngineWarning(${code.name})' : 'EngineWarning(${code.name}: $detail)';
}
