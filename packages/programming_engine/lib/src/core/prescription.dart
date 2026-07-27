/// What one exercise looks like once the plan layer and the session layer meet.
library;

import 'package:collection/collection.dart';

import 'dose.dart';
import 'load_suggestion.dart';
import 'reason_code.dart';
import 'units.dart';

/// Whether the dose is per side. A single-arm row prescribed 10 reps means 10 per arm.
enum Laterality {
  bilateral,
  perSide;

  bool get isPerSide => this == Laterality.perSide;
}

/// §3.4 — the two legitimate ways to bridge a jump that is too big to take cleanly.
/// Offered on the final set of isolation and single-side work, where the smallest
/// available jump is proportionally huge.
sealed class DropBridge {
  const DropBridge();
}

/// "Do what you can at the new weight, then drop straight back to the old one for
/// another 4–5 reps."
final class DropSetBridge extends DropBridge {
  const DropSetBridge({
    required this.backOffLoad,
    required this.backOffRepsMin,
    required this.backOffRepsMax,
  });

  /// The weight she was using before the step — always representable.
  final Kg backOffLoad;
  final int backOffRepsMin;
  final int backOffRepsMax;

  @override
  bool operator ==(Object other) =>
      other is DropSetBridge &&
      other.backOffLoad == backOffLoad &&
      other.backOffRepsMin == backOffRepsMin &&
      other.backOffRepsMax == backOffRepsMax;

  @override
  int get hashCode => Object.hash(backOffLoad, backOffRepsMin, backOffRepsMax);

  @override
  String toString() =>
      'DropSetBridge(back off to ${backOffLoad.value}kg for $backOffRepsMin-$backOffRepsMax)';
}

/// "Use the easier variation of this movement until you're strong enough."
/// The target is chosen from the swap graph, so this is filled at session-resolve
/// time, not by the load math.
final class EasierVariationBridge extends DropBridge {
  const EasierVariationBridge({required this.exerciseId});

  final String exerciseId;

  @override
  bool operator ==(Object other) =>
      other is EasierVariationBridge && other.exerciseId == exerciseId;

  @override
  int get hashCode => exerciseId.hashCode;

  @override
  String toString() => 'EasierVariationBridge($exerciseId)';
}

/// One exercise, fully resolved: what the plan asked for, what to load, and why.
final class ExercisePrescription {
  const ExercisePrescription({
    required this.exerciseId,
    required this.dose,
    required this.suggestion,
    required this.laterality,
    this.bridge,
    this.why = const <ReasonCode>[],
  });

  final String exerciseId;

  /// From the plan — the effort-target world.
  final Dose dose;

  /// From `LoadSuggester` — the concrete world.
  final LoadSuggestion suggestion;
  final Laterality laterality;

  /// §3 bridge on the final set, when one is offered.
  final DropBridge? bridge;
  final List<ReasonCode> why;

  @override
  bool operator ==(Object other) =>
      other is ExercisePrescription &&
      other.exerciseId == exerciseId &&
      other.dose == dose &&
      other.suggestion == suggestion &&
      other.laterality == laterality &&
      other.bridge == bridge &&
      const ListEquality<ReasonCode>().equals(other.why, why);

  @override
  int get hashCode => Object.hash(
    exerciseId,
    dose,
    suggestion,
    laterality,
    bridge,
    Object.hashAll(why),
  );

  @override
  String toString() =>
      'ExercisePrescription($exerciseId, $dose, $suggestion, '
      '${laterality.name}${bridge == null ? '' : ', $bridge'}, why: '
      '[${why.map((r) => r.name).join(', ')}])';
}
