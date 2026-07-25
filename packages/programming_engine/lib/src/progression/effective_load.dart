/// `effectiveLoad = externalLoad + bw_contribution × bodyMass`.
///
/// `ENGINE.md` › "Effective load": the Epley-ratio formula and **all** percentage
/// guardrails run on effective load, then convert back to external for display and
/// equipment snapping. Otherwise +2 kg on a goblet squat reads as +20% when it is
/// really ~4% for a 70 kg user, and bodyweight movements can't progress at all.
library;

import '../core/units.dart';

final class EffectiveLoad {
  const EffectiveLoad({required this.bwContribution, required this.bodyMass});

  /// External load only — for a leg extension, or when body mass is unknown.
  static const EffectiveLoad externalOnly =
      EffectiveLoad(bwContribution: 0, bodyMass: Kg.zero);

  /// Fraction of body mass in the lift, 0..1.
  final double bwContribution;
  final Kg bodyMass;

  /// The constant part of every effective load for this (exercise, user) pair.
  Kg get bodyTerm => bodyMass * bwContribution;

  Kg effective(Kg external) => external + bodyTerm;

  Kg external(Kg effective) => effective - bodyTerm;

  @override
  bool operator ==(Object other) =>
      other is EffectiveLoad &&
      other.bwContribution == bwContribution &&
      other.bodyMass == bodyMass;

  @override
  int get hashCode => Object.hash(bwContribution, bodyMass);

  @override
  String toString() =>
      'EffectiveLoad(bw $bwContribution × ${bodyMass.value}kg = ${bodyTerm.value}kg)';
}
