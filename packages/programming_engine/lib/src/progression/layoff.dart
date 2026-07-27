/// §6 layoff handling — one continuous curve measured from the last completed
/// session.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../config/programming_config.dart';

/// A negative day count is clock-skew normalization and behaves like day zero.
@useResult
double layoffMultiplier(int daysSinceLastSession, ProgrammingConfig config) {
  final days = math.max(0, daysSinceLastSession);
  final daysPastGrace = math.max(0, days - config.layoffGraceDays);
  return (1 - config.layoffSlopePerDay * daysPastGrace).clamp(
    config.layoffFloor,
    1.0,
  );
}

/// Progression is suppressed for every point after the grace period. Keeping
/// this predicate next to the curve prevents resolve-time rules and the load
/// suggester from interpreting absence differently.
@useResult
bool layoffSuppressesProgression(
  int daysSinceLastSession,
  ProgrammingConfig config,
) =>
    daysSinceLastSession > config.layoffGraceDays ||
    layoffMultiplier(daysSinceLastSession, config) < 1;

@useResult
bool layoffMultiplierIsAtFloor(double multiplier, ProgrammingConfig config) =>
    multiplier <= config.layoffFloor + 1e-12;
