/// Effort vocabulary: the 5-level feel tap, the internal RPE/RIR anchors, and
/// the effort target the plan carries.
///
/// `PROGRAMMING.md` §4 "Feedback capture". None of these words are ever shown to
/// her — the UI asks "how did that feel" and carries the week's target in the
/// question copy.
library;

/// The five positions on the feel tap, in order from easiest to hardest.
///
/// Five, not three: novices cannot reliably discriminate finer, but three throws
/// away the difference between "a bit easy" and "way too easy" — which is the
/// difference between progression and calibration.
enum EffortLevel {
  /// "Way too easy" — RPE ≤4, 6+ nominal RIR. Triggers the calibration regime.
  wayTooEasy(1),

  /// "A bit easy" — RPE 5–6.
  aBitEasy(2),

  /// "Just right" — RPE 7. The default target for beginners.
  justRight(3),

  /// "Harder than I'd like" — RPE 8.
  harderThanIdLike(4),

  /// "Too hard" — RPE 9–10. The only report that licenses a load decrease.
  tooHard(5);

  const EffortLevel(this.value);

  /// 1..5, the number the UI and the event log carry.
  final int value;

  /// Total lookup: returns `null` rather than throwing on an out-of-range value.
  static EffortLevel? fromValue(int value) {
    for (final level in EffortLevel.values) {
      if (level.value == value) return level;
    }
    return null;
  }
}

/// An RPE band. The scale is coarse below 7 and we operate coarse, so a report
/// maps to a band rather than a point value.
final class RpeBand {
  const RpeBand(this.min, this.max) : assert(min <= max);

  final int min;
  final int max;

  bool contains(int rpe) => rpe >= min && rpe <= max;

  @override
  bool operator ==(Object other) =>
      other is RpeBand && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => min == max ? 'RPE $min' : 'RPE $min-$max';
}

/// What the plan prescribes: an effort target on the RIR-anchored RPE scale.
///
/// Internal only. Beginners are programmed at RPE ≤7 (3+ RIR); the near-failure
/// zone exists in the format but is not used in the first mesocycles.
final class EffortTarget {
  const EffortTarget(this.rpe) : assert(rpe >= 1 && rpe <= 10);

  /// RPE 7 — "leave 3 reps in the tank". The beginner default.
  static const EffortTarget rpe7 = EffortTarget(7);

  final int rpe;

  /// Reps in reserve implied by the target. RPE 10 = 0 RIR.
  int get rir => 10 - rpe;

  /// A target [delta] RPE points easier, floored at RPE 1. Used by the easier
  /// week and the deload week, which are "just easier effort targets".
  EffortTarget easierBy(int delta) => EffortTarget((rpe - delta).clamp(1, 10));

  @override
  bool operator ==(Object other) => other is EffortTarget && other.rpe == rpe;

  @override
  int get hashCode => rpe.hashCode;

  @override
  String toString() => 'EffortTarget(RPE $rpe / ${rir}RIR)';
}

/// A feel tap turned into numbers the formula can use.
final class InterpretedEffort {
  const InterpretedEffort({
    required this.level,
    required this.band,
    required this.rpe,
    required this.rir,
    required this.rirWasClamped,
  });

  final EffortLevel level;
  final RpeBand band;

  /// Representative RPE for the band — the conservative (harder) end.
  final int rpe;

  /// Reps in reserve, clamped at `ProgrammingConfig.maxInterpretedRir`.
  final int rir;

  /// True when the nominal RIR was above the clamp (the scale is meaningless
  /// out there, so we refuse to act on the difference).
  final bool rirWasClamped;

  @override
  bool operator ==(Object other) =>
      other is InterpretedEffort &&
      other.level == level &&
      other.band == band &&
      other.rpe == rpe &&
      other.rir == rir &&
      other.rirWasClamped == rirWasClamped;

  @override
  int get hashCode => Object.hash(level, band, rpe, rir, rirWasClamped);

  @override
  String toString() =>
      'InterpretedEffort(${level.name}, $band, rpe: $rpe, rir: $rir'
      '${rirWasClamped ? ', clamped' : ''})';
}
