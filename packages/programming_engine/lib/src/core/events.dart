/// The event vocabulary — **the one schema that can't be cheaply migrated**.
///
/// `ENGINE.md` › "State": the append-only event log is the single source of truth,
/// the only thing synced, and it doubles as the local Drift schema and the Supabase
/// sync schema. Everything the engine knows is a fold over this list.
///
/// Events carry no timestamps: time is injected as a parameter wherever a decision
/// needs it, and the log's storage layer owns ordering and clock stamps.
library;

import 'effort.dart';
import 'units.dart';

/// Why she wants a different exercise (§9). Each reason has its own ranked edge
/// list in the swap graph.
enum SwapReason {
  /// The equipment is occupied — same muscle, different equipment family.
  busy,

  /// The setup or the corner of the gym is intimidating — simpler setup, more
  /// private spot.
  intimidating,

  /// It doesn't feel good — same muscle, different joint angle.
  uncomfortable,

  /// Her gym doesn't have it at all.
  unavailable,
}

/// Where it hurt (§11). Coarse on purpose — this drives an exclusion, not a
/// diagnosis, and we are not a medical product.
enum PainSite { knee, hip, lowBack, midBack, shoulder, elbow, wrist, neck, ankle, other }

/// Everything that can happen inside a session.
sealed class SessionEvent {
  const SessionEvent();
}

/// A set she finished. [load] is the canonical kg actually used; [unitSystem] is
/// the market in force at entry, so replay never double-rounds.
final class SetCompleted extends SessionEvent {
  const SetCompleted({
    required this.exerciseId,
    required this.setIndex,
    required this.load,
    required this.reps,
    required this.unitSystem,
  })  : assert(setIndex >= 0),
        assert(reps >= 0);

  final String exerciseId;

  /// 0-based within the exercise.
  final int setIndex;
  final Kg load;
  final int reps;
  final UnitSystem unitSystem;

  @override
  bool operator ==(Object other) =>
      other is SetCompleted &&
      other.exerciseId == exerciseId &&
      other.setIndex == setIndex &&
      other.load == load &&
      other.reps == reps &&
      other.unitSystem == unitSystem;

  @override
  int get hashCode => Object.hash(exerciseId, setIndex, load, reps, unitSystem);

  @override
  String toString() =>
      'SetCompleted($exerciseId, set $setIndex, ${load.value}kg x $reps, ${unitSystem.name})';
}

/// The feel tap — once per exercise, on the last set, during rest. Optional,
/// never blocking.
final class EffortReported extends SessionEvent {
  const EffortReported({required this.exerciseId, required this.level});

  /// Decodes a raw 1..5 from the UI or the log. Returns `null` for anything else
  /// rather than throwing.
  static EffortReported? fromLevelValue({required String exerciseId, required int level}) {
    final decoded = EffortLevel.fromValue(level);
    return decoded == null ? null : EffortReported(exerciseId: exerciseId, level: decoded);
  }

  final String exerciseId;
  final EffortLevel level;

  @override
  bool operator ==(Object other) =>
      other is EffortReported && other.exerciseId == exerciseId && other.level == level;

  @override
  int get hashCode => Object.hash(exerciseId, level);

  @override
  String toString() => 'EffortReported($exerciseId, ${level.name}/${level.value})';
}

/// "Give me something else for this."
final class SwapRequested extends SessionEvent {
  const SwapRequested({required this.exerciseId, required this.reason});

  final String exerciseId;
  final SwapReason reason;

  @override
  bool operator ==(Object other) =>
      other is SwapRequested && other.exerciseId == exerciseId && other.reason == reason;

  @override
  int get hashCode => Object.hash(exerciseId, reason);

  @override
  String toString() => 'SwapRequested($exerciseId, ${reason.name})';
}

/// "I've only got 20 minutes." Isolation drops from the end; primaries never.
final class Shorten extends SessionEvent {
  const Shorten(this.minutes) : assert(minutes > 0);

  /// Minutes she actually has.
  final int minutes;

  @override
  bool operator ==(Object other) => other is Shorten && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;

  @override
  String toString() => 'Shorten(${minutes}min)';
}

/// "Low energy today": same exercises, −10%, bottom of the rep range — and we say so.
final class LowEnergy extends SessionEvent {
  const LowEnergy();

  @override
  bool operator ==(Object other) => other is LowEnergy;

  @override
  int get hashCode => (LowEnergy).hashCode;

  @override
  String toString() => 'LowEnergy()';
}

/// Sharp or joint pain (§11). Stops the exercise, offers a swap, and folds into the
/// per-exercise exclusion set so it isn't silently re-suggested.
final class PainReported extends SessionEvent {
  const PainReported({required this.exerciseId, required this.site});

  final String exerciseId;
  final PainSite site;

  @override
  bool operator ==(Object other) =>
      other is PainReported && other.exerciseId == exerciseId && other.site == site;

  @override
  int get hashCode => Object.hash(exerciseId, site);

  @override
  String toString() => 'PainReported($exerciseId, ${site.name})';
}

/// She left. Never punished — the streak pauses rather than breaks.
final class SessionAbandoned extends SessionEvent {
  const SessionAbandoned();

  @override
  bool operator ==(Object other) => other is SessionAbandoned;

  @override
  int get hashCode => (SessionAbandoned).hashCode;

  @override
  String toString() => 'SessionAbandoned()';
}
