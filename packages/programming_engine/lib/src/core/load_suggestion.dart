/// The session layer: what `LoadSuggester` hands the UI.
///
/// `NeedsCalibration` is a case rather than a null weight on purpose — it forces
/// every consumer (UI, goldens, recap) through an exhaustive switch.
library;

import 'units.dart';

sealed class LoadSuggestion {
  const LoadSuggestion();
}

/// "Try 12 kg." Always representable on the exercise's equipment family in her
/// unit system; display conversion happens at the UI.
final class SuggestedLoad extends LoadSuggestion {
  const SuggestedLoad(this.kg);

  final Kg kg;

  @override
  bool operator ==(Object other) => other is SuggestedLoad && other.kg == kg;

  @override
  int get hashCode => kg.hashCode;

  @override
  String toString() => 'SuggestedLoad(${kg.value}kg)';
}

/// Bodyweight movement that can carry extra load. [added] is `Kg.zero` for pure
/// bodyweight.
final class BodyweightOnly extends LoadSuggestion {
  const BodyweightOnly({this.added = Kg.zero});

  final Kg added;

  @override
  bool operator ==(Object other) => other is BodyweightOnly && other.added == added;

  @override
  int get hashCode => added.hashCode;

  @override
  String toString() => added.isZero
      ? 'BodyweightOnly()'
      : 'BodyweightOnly(+${added.value}kg)';
}

/// First exposure: there is no prior (load, reps, effort) triple, so the §7 probe
/// runs instead. [floor] is where the probe starts — the lowest load that exists
/// on this equipment, or a history-derived floor after a long layoff.
final class NeedsCalibration extends LoadSuggestion {
  const NeedsCalibration({required this.floor, required this.probeReps});

  final Kg floor;

  /// Reps to ask for on the probe set (§7: 8 easy reps).
  final int probeReps;

  @override
  bool operator ==(Object other) =>
      other is NeedsCalibration && other.floor == floor && other.probeReps == probeReps;

  @override
  int get hashCode => Object.hash(floor, probeReps);

  @override
  String toString() => 'NeedsCalibration(floor: ${floor.value}kg, $probeReps reps)';
}

/// Bodyweight and timed movements: the progression *is* the rep count or the hold.
final class RepOrDurationTarget extends LoadSuggestion {
  const RepOrDurationTarget.reps(this.reps)
      : hold = null,
        assert(reps >= 1);

  const RepOrDurationTarget.hold(Duration this.hold) : reps = 1;

  /// Reps to aim for. Meaningful for rep-metric movements; 1 (one hold) for timed.
  final int reps;

  /// Hold duration, for timed movements only.
  final Duration? hold;

  bool get isTimed => hold != null;

  @override
  bool operator ==(Object other) =>
      other is RepOrDurationTarget && other.reps == reps && other.hold == hold;

  @override
  int get hashCode => Object.hash(reps, hold);

  @override
  String toString() => isTimed
      ? 'RepOrDurationTarget(${hold!.inSeconds}s)'
      : 'RepOrDurationTarget($reps reps)';
}
