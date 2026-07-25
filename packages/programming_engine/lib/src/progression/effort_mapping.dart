/// The 5-level feel tap → RPE band → RIR, clamped at 5.
///
/// `PROGRAMMING.md` §4 "Feedback capture". The RPE we read a tap as is the end of
/// its band that implies the *smaller* change: novice reports are imprecise in both
/// directions (Halperin et al. 2022 — they report ~1 rep closer to failure than they
/// are), and §1.3 says hold rather than guess.
library;

import 'package:meta/meta.dart';

import '../config/programming_config.dart';
import '../core/effort.dart';

/// Turns a tap into the `(rpe, rir)` pair the formula consumes.
@useResult
InterpretedEffort interpretEffort(EffortLevel level, ProgrammingConfig config) {
  final rpe = config.reportedRpeByLevel[level] ?? (10 - _fallbackRir(level));
  final band = config.rpeBandByLevel[level] ?? RpeBand(rpe, rpe);
  final nominalRir = 10 - rpe;
  final clamped = nominalRir > config.maxInterpretedRir;
  return InterpretedEffort(
    level: level,
    band: band,
    rpe: rpe,
    rir: clamped ? config.maxInterpretedRir : nominalRir,
    rirWasClamped: clamped,
  );
}

/// Only reachable if a config drops a level from the map; keeps the function total.
int _fallbackRir(EffortLevel level) => switch (level) {
      EffortLevel.wayTooEasy => 6,
      EffortLevel.aBitEasy => 4,
      EffortLevel.justRight => 3,
      EffortLevel.harderThanIdLike => 2,
      EffortLevel.tooHard => 1,
    };

/// True when the report says she is far under her working weight (§4.1) — the
/// calibration regime, where big jumps are *finding the weight*, not progression.
bool isCalibrationReport(InterpretedEffort effort, ProgrammingConfig config) =>
    effort.rpe <= config.calibrationRegimeMaxRpe;

/// §4.3: the only two reports that license a load decrease are "she missed the
/// target reps" and "RPE ≥9".
bool licensesDecrease({
  required InterpretedEffort effort,
  required int lastReps,
  required int targetReps,
}) =>
    lastReps < targetReps || effort.rpe >= 9;
