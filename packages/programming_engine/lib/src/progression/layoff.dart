/// §6 Layoff handling — measured from her last completed session.
///
/// "Never punish absence": layoffs reduce load automatically and silently, and the
/// tier is applied **before** progression, so a returning user is never asked to
/// beat the session she did a month ago.
library;

import 'package:meta/meta.dart';

import '../config/programming_config.dart';
import '../core/reason_code.dart';

enum LayoffTier {
  /// 0–6 days: normal progression, nothing said.
  none,

  /// 7–13 days: repeat last weights, no increase. "Picking up right where you
  /// left off."
  hold,

  /// 14–27 days: −10% on all working weights. "Eased this week back a little."
  reduce,

  /// 28+ days: −20%, and the compound lifts re-calibrate. "Let's re-find your
  /// weights — it comes back fast."
  reCalibrate;

  bool get changesLoad => this == reduce || this == reCalibrate;
}

/// A negative day count is treated as 0 by the caller as clock-skew normalization.
@useResult
LayoffTier layoffTierFor(int daysSinceLastSession, ProgrammingConfig config) {
  final days = daysSinceLastSession < 0 ? 0 : daysSinceLastSession;
  if (days >= config.layoffTier3Days) return LayoffTier.reCalibrate;
  if (days >= config.layoffTier2Days) return LayoffTier.reduce;
  if (days >= config.layoffTier1Days) return LayoffTier.hold;
  return LayoffTier.none;
}

/// The multiplier this tier applies to her last working load.
double layoffLoadFraction(LayoffTier tier, ProgrammingConfig config) =>
    switch (tier) {
      LayoffTier.none => 1,
      LayoffTier.hold => 1,
      LayoffTier.reduce => config.layoffTier2LoadFraction,
      LayoffTier.reCalibrate => config.layoffTier3LoadFraction,
    };

ReasonCode? layoffReason(LayoffTier tier) => switch (tier) {
  LayoffTier.none => null,
  LayoffTier.hold => ReasonCode.layoffTier1,
  LayoffTier.reduce => ReasonCode.layoffTier2,
  LayoffTier.reCalibrate => ReasonCode.layoffTier3,
};
