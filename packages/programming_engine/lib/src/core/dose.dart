/// The plan layer: sets × rep range × effort target. **No weights anywhere.**
///
/// `ENGINE.md` › "Two layers". Plan documents and their goldens are unit-free and
/// market-independent; concrete loads appear only at session-resolve time.
library;

import 'effort.dart';

/// An inclusive rep window. Double progression climbs it, then the load steps and
/// the reps reset to [min].
final class RepRange {
  const RepRange(this.min, this.max) : assert(min >= 1 && max >= min);

  final int min;
  final int max;

  bool contains(int reps) => reps >= min && reps <= max;
  int clamp(int reps) => reps.clamp(min, max);
  bool isTop(int reps) => reps >= max;
  bool isBottom(int reps) => reps <= min;
  int get span => max - min;

  @override
  bool operator ==(Object other) =>
      other is RepRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => '$min-$max';
}

/// What she is asked to do for one exercise, in effort-target terms.
sealed class Dose {
  const Dose({required this.sets});

  final int sets;
}

/// Load × reps work: sets of a rep range at an effort target.
final class RepsDose extends Dose {
  const RepsDose({
    required super.sets,
    required this.range,
    required this.effort,
    required this.targetReps,
  }) : assert(sets >= 1),
       assert(targetReps >= 1);

  final RepRange range;
  final EffortTarget effort;

  /// The rung of the rep ladder currently prescribed, inside [range]. The
  /// formula's `targetReps`.
  final int targetReps;

  RepsDose copyWith({
    int? sets,
    RepRange? range,
    EffortTarget? effort,
    int? targetReps,
  }) => RepsDose(
    sets: sets ?? this.sets,
    range: range ?? this.range,
    effort: effort ?? this.effort,
    targetReps: targetReps ?? this.targetReps,
  );

  @override
  bool operator ==(Object other) =>
      other is RepsDose &&
      other.sets == sets &&
      other.range == range &&
      other.effort == effort &&
      other.targetReps == targetReps;

  @override
  int get hashCode => Object.hash(sets, range, effort, targetReps);

  @override
  String toString() => 'RepsDose(${sets}x$range @$targetReps, $effort)';
}

/// Timed work (planks). Nothing to resolve into a load.
final class TimedDose extends Dose {
  const TimedDose({required super.sets, required this.hold})
    : assert(sets >= 1);

  final Duration hold;

  TimedDose copyWith({int? sets, Duration? hold}) =>
      TimedDose(sets: sets ?? this.sets, hold: hold ?? this.hold);

  @override
  bool operator ==(Object other) =>
      other is TimedDose && other.sets == sets && other.hold == hold;

  @override
  int get hashCode => Object.hash(sets, hold);

  @override
  String toString() => 'TimedDose(${sets}x${hold.inSeconds}s)';
}
