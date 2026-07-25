/// §4 — effort-based prescription → load suggestion.
///
/// The plan never contains weights. This is the thin edge of the package that turns
/// "sets × rep range × effort target" plus *her own history for this exercise* into
/// "try 12 kg", snapped to what physically exists. kg/lb and equipment-step
/// knowledge live here and nowhere else.
///
/// The guardrails run in the order `PROGRAMMING.md` §4 lists them:
/// calibration regime → ±10%/step cap → asymmetric down-rule → deadband →
/// discretization, with "no feedback → identical" short-circuiting before all of
/// them and the §6 layoff tiers applied before any of it.
///
/// Total by construction: no input makes this throw. Weird-but-possible values are
/// sanitized and reported as [EngineWarning]s.
library;

import 'package:meta/meta.dart';

import '../config/equipment_loads.dart';
import '../config/programming_config.dart';
import '../content/exercise.dart';
import '../core/effort.dart';
import '../core/dose.dart';
import '../core/load_suggestion.dart';
import '../core/prescription.dart';
import '../core/reason_code.dart';
import '../core/units.dart';
import '../core/warnings.dart';
import 'effective_load.dart';
import 'effort_mapping.dart';
import 'layoff.dart';

/// What the fold over the event log knows about one exercise from last time.
final class ExerciseSnapshot {
  const ExerciseSnapshot({
    required this.lastLoad,
    required this.lastReps,
    required this.targetReps,
    this.reportedEffort,
    this.lastHold,
  });

  /// External load actually used, canonical kg.
  final Kg lastLoad;

  /// Reps completed on the set the feel tap refers to (the last set).
  final int lastReps;

  /// The rep target that *was* prescribed for that session — the formula's
  /// `targetReps`, and the yardstick for "she missed the target reps".
  final int targetReps;

  /// `null` means she didn't tap. Silence is never permission (§4.6).
  final EffortLevel? reportedEffort;

  /// Last hold, for timed movements.
  final Duration? lastHold;

  @override
  bool operator ==(Object other) =>
      other is ExerciseSnapshot &&
      other.lastLoad == lastLoad &&
      other.lastReps == lastReps &&
      other.targetReps == targetReps &&
      other.reportedEffort == reportedEffort &&
      other.lastHold == lastHold;

  @override
  int get hashCode =>
      Object.hash(lastLoad, lastReps, targetReps, reportedEffort, lastHold);

  @override
  String toString() =>
      'ExerciseSnapshot(${lastLoad.value}kg x $lastReps '
      '(target $targetReps), ${reportedEffort?.name ?? 'no tap'})';
}

/// Everything one load decision needs. No clock, no catalog, no history beyond the
/// small window the rules actually use.
final class ProgressionInput {
  const ProgressionInput({
    required this.profile,
    required this.range,
    required this.effort,
    required this.unitSystem,
    this.history,
    this.bodyMass = Kg.zero,
    this.daysSinceLastSession = 0,
  });

  final LoadProfile profile;

  /// The rep window the plan prescribes for this exercise.
  final RepRange range;

  /// The effort target for this week (the easier week is just an easier target).
  final EffortTarget effort;
  final UnitSystem unitSystem;

  /// `null` → first exposure, which always goes through the §7 probe.
  final ExerciseSnapshot? history;

  /// Needed only for movements with `bw_contribution > 0`.
  final Kg bodyMass;

  /// Days since her last completed session — injected, never read from a clock.
  final int daysSinceLastSession;
}

/// Which branch of §4 produced the decision. Lets invariant tests scope
/// themselves the way the spec does ("≤1 step normally, ≤2 during calibration").
enum ProgressionRegime {
  /// No prior triple: the §7 probe runs instead of the formula.
  firstExposure,

  /// A §6 layoff tier applied; progression was skipped.
  layoff,

  /// No feel tap: repeat identical.
  noFeedback,

  /// Reported ≤ RPE 4 — finding the weight, not progressing it.
  calibration,

  /// The formula plus §4.2–4.5.
  normal,

  /// Reps-only movement: the progression is the rep count.
  repsOnly,

  /// Timed movement: the progression is the hold.
  timed,
}

/// The decision, with everything a UI, a golden or a support replay needs.
final class LoadDecision {
  const LoadDecision({
    required this.suggestion,
    required this.targetReps,
    required this.regime,
    this.hold,
    this.externalLoad,
    this.bridge,
    this.stepsMoved = 0,
    this.why = const <ReasonCode>[],
    this.warnings = const <EngineWarning>[],
  });

  final LoadSuggestion suggestion;

  /// The rep target for the coming session.
  final int targetReps;

  /// The hold for the coming session, on timed movements.
  final Duration? hold;

  final ProgressionRegime regime;

  /// The external load behind [suggestion], when there is one. Always
  /// representable on this equipment family in her unit system.
  final Kg? externalLoad;

  final DropBridge? bridge;

  /// Signed equipment steps between her last load and [externalLoad].
  final int stepsMoved;

  final List<ReasonCode> why;
  final List<EngineWarning> warnings;

  bool get loadChanged => stepsMoved != 0;

  @override
  String toString() =>
      'LoadDecision($suggestion, $targetReps reps, '
      '${regime.name}, steps $stepsMoved, why [${why.map((r) => r.name).join(', ')}]'
      '${warnings.isEmpty ? '' : ', warnings $warnings'})';
}

/// §4's decision logic. Const-constructible and stateless — the same inputs always
/// produce the same output.
final class LoadSuggester {
  const LoadSuggester([this.config = const ProgrammingConfig()]);

  final ProgrammingConfig config;

  @useResult
  LoadDecision suggest(ProgressionInput input) => _Pass(config, input).run();
}

/// One invocation's sanitized context plus its accumulating explanation. Private:
/// the public surface is [LoadSuggester.suggest].
final class _Pass {
  _Pass(this.config, this.input)
    : loads = config.availableLoads(input.profile, input.unitSystem);

  final ProgrammingConfig config;
  final ProgressionInput input;
  final AvailableLoads loads;

  final List<ReasonCode> why = <ReasonCode>[];
  final List<EngineWarning> warnings = <EngineWarning>[];

  /// Sanitized lazily, so a warning is only raised about a value the decision
  /// actually depended on. The access order is fixed per branch, so two identical
  /// inputs still produce identical warning lists.
  late final RepRange range = _sanitizedRange(input.range);

  /// The reps we may legally prescribe. Isolation work can sit below the range's
  /// bottom right after a weight jump (§3: "restart at 8–10 reps" under a 10–15
  /// range).
  late final RepRange window = _prescribableWindow();
  late final EffectiveLoad effectiveLoad = _sanitizedEffectiveLoad();
  late final int days = _sanitizedDays();

  bool get isIsolationLike =>
      input.profile.movementClass.isIsolation ||
      input.profile.laterality.isPerSide;

  /// Where reps land when the load moves.
  int get resetReps => isIsolationLike
      ? window.clamp(config.isolationRestartRange.min)
      : range.min;

  /// Whether this report licenses *any* progress this session.
  ///
  /// Keyed to the label first, the arithmetic second. §4's question copy is phrased
  /// against the week's target ("could you have done 2 more?"), so "just right"
  /// means "I hit what you asked for" whatever the target RPE is — and §4.7 says
  /// that always moves. Without this, a "Feel healthier" user (target RPE 6, 4 RIR)
  /// tapping "just right" (3 RIR) would read as *harder* than target every session
  /// and never progress at all.
  ///
  /// The same rule going the other way: anything she calls harder than "just right"
  /// never buys progress, even where the arithmetic says she is on target — at an
  /// RPE 8 target, "harder than I'd like" is numerically at target, but she has just
  /// told us it was harder than she'd like.
  bool supportsProgress(InterpretedEffort report) =>
      report.level.index <= EffortLevel.justRight.index ||
      report.rir > input.effort.rir;

  LoadDecision run() {
    switch (input.profile.metricType) {
      case MetricType.timed:
        return _timed();
      case MetricType.repsOnly:
        return _repsOnly();
      case MetricType.loadReps:
        return _loadReps();
    }
  }

  // ── Load × reps: the §4 pipeline ──────────────────────────────────────────

  LoadDecision _loadReps() {
    final history = input.history;

    // Cold start: the formula needs a prior (load, reps, effort) triple.
    if (history == null) {
      why.add(ReasonCode.firstExposure);
      return _decision(
        suggestion: NeedsCalibration(
          floor: loads.floor,
          probeReps: config.calibrationProbeReps,
        ),
        targetReps: config.calibrationProbeReps,
        regime: ProgressionRegime.firstExposure,
        externalLoad: loads.floor,
      );
    }

    final base = _sanitizedBaseLoad(history.lastLoad);
    final targetReps = _sanitizedTargetReps(history.targetReps);

    // §6 layoff tiers, before progression.
    final tier = layoffTierFor(days, config);
    if (tier != LayoffTier.none) return _applyLayoff(tier, base, targetReps);

    // §4.6 no feedback → repeat identical.
    final level = history.reportedEffort;
    if (level == null) {
      why.add(ReasonCode.noFeedbackHold);
      return _decision(
        suggestion: _wrapLoad(base),
        targetReps: targetReps,
        regime: ProgressionRegime.noFeedback,
        externalLoad: base,
      );
    }

    final report = interpretEffort(level, config);
    final lastReps = _sanitizedReps(history.lastReps);
    final calibrating = isCalibrationReport(report, config);
    final regime = calibrating
        ? ProgressionRegime.calibration
        : ProgressionRegime.normal;

    final lastEffective = effectiveLoad.effective(base);
    if (!lastEffective.isPositive) {
      if (input.profile.resistanceEquipment ==
              ResistanceEquipment.assistedStack &&
          calibrating) {
        final stepped = loads.shift(base, 1);
        why
          ..add(ReasonCode.calibrationRegimeJump)
          ..add(ReasonCode.calibrationMinimumStep);
        if (stepped > base) {
          why
            ..add(ReasonCode.weightStep)
            ..add(ReasonCode.repsReset);
        }
        return _decision(
          suggestion: _wrapLoad(stepped),
          targetReps: stepped > base ? resetReps : targetReps,
          regime: regime,
          externalLoad: stepped,
          base: base,
        );
      }
      // Nothing to scale — a bodyweight-metric movement with no body mass known.
      warnings.add(
        const EngineWarning(
          WarningCode.invalidBodyMass,
          'effective load is zero; holding',
        ),
      );
      why.add(ReasonCode.deadbandHold);
      return _decision(
        suggestion: _wrapLoad(base),
        targetReps: targetReps,
        regime: regime,
        externalLoad: base,
      );
    }

    // The formula, on effective load (ENGINE.md "Effective load").
    final numerator = config.epleyConstant + lastReps + report.rir;
    final denominator = config.epleyConstant + targetReps + input.effort.rir;
    final desiredEffective = lastEffective * (numerator / denominator);

    // A step's absolute size is the same in effective and external terms, so the
    // guardrails can work on a single delta.
    final oneStep = _stepAt(base);
    final maxSteps = calibrating
        ? config.calibrationMaxSteps
        : config.maxStepsPerAdjustment;
    final capFraction = calibrating
        ? config.calibrationMaxIncreaseFraction
        : config.maxChangeFraction;

    var delta = desiredEffective - lastEffective;
    var capped = false;
    var forcedStep = false;
    var heldByDownRule = false;
    var heldByEffortAboveTarget = false;
    var heldByDeadband = false;

    // §4.2 cap: ±10% (±15% calibrating) or one step, whichever is larger at light
    // absolute loads — and never more than two steps.
    var maxDelta = lastEffective * capFraction;
    if (maxDelta < oneStep) maxDelta = oneStep;
    final stepCeiling = oneStep * maxSteps;
    if (maxDelta > stepCeiling) maxDelta = stepCeiling;
    if (delta > maxDelta) {
      delta = maxDelta;
      capped = true;
    } else if (delta < -maxDelta) {
      delta = -maxDelta;
      capped = true;
    }

    // §4.1 calibration regime: jump at least one equipment step. Applied after the
    // cap so the cap can't erase it, and before the deadband so silence in the
    // noise floor can't either.
    if (calibrating && delta < oneStep) {
      delta = oneStep;
      forcedStep = true;
      capped = false;
    }

    final progressAllowed = supportsProgress(report);

    // §4.3 asymmetric down-rule.
    if (delta.isNegative &&
        !licensesDecrease(
          effort: report,
          lastReps: lastReps,
          targetReps: targetReps,
        )) {
      delta = Kg.zero;
      heldByDownRule = true;
      capped = false;
    }

    // The other half of the asymmetry: a report *harder* than the target never
    // buys more load, even when she beat the rep target and the formula therefore
    // asks for more. §1.3 — when the feedback is ambiguous, hold. (ENGINE.md's
    // invariant "'too hard' ⇒ load never increases" depends on this.)
    if (delta.isPositive && !progressAllowed) {
      delta = Kg.zero;
      heldByEffortAboveTarget = true;
      capped = false;
    }

    // §4.4 deadband — below the reporting noise floor.
    if (!forcedStep &&
        !heldByDownRule &&
        !heldByEffortAboveTarget &&
        delta.abs < lastEffective * config.deadbandFraction) {
      delta = Kg.zero;
      heldByDeadband = true;
      capped = false;
    }

    if (calibrating) {
      why.add(ReasonCode.calibrationRegimeJump);
      if (forcedStep) why.add(ReasonCode.calibrationMinimumStep);
    }
    if (capped) why.add(ReasonCode.cappedAtMaxChange);
    if (heldByDownRule) why.add(ReasonCode.asymmetricDownRuleHold);
    if (heldByEffortAboveTarget) why.add(ReasonCode.effortAboveTargetHold);
    if (heldByDeadband) why.add(ReasonCode.deadbandHold);

    // §4.5 discretization.
    if (delta.isPositive) {
      return _applyIncrease(
        base: base,
        desiredExternal: base + delta,
        desiredEffective: lastEffective + delta,
        lastEffective: lastEffective,
        targetReps: targetReps,
        oneStep: oneStep,
        regime: regime,
      );
    }
    if (delta.isNegative) {
      return _applyDecrease(
        base: base,
        desiredExternal: base + delta,
        targetReps: targetReps,
        maxSteps: maxSteps,
        regime: regime,
      );
    }
    // No load change. §4.7: at target effort progress still has to come from
    // somewhere, so it comes from reps.
    if (progressAllowed) {
      return _spendOnReps(
        base: base,
        targetReps: targetReps,
        shortfallFraction: 0,
        regime: regime,
        incrementWasTooSmall: false,
      );
    }
    return _decision(
      suggestion: _wrapLoad(base),
      targetReps: targetReps,
      regime: regime,
      externalLoad: base,
    );
  }

  /// The load wants to go up. It moves only if a whole step is reachable;
  /// otherwise the progress is spent on reps.
  LoadDecision _applyIncrease({
    required Kg base,
    required Kg desiredExternal,
    required Kg desiredEffective,
    required Kg lastEffective,
    required int targetReps,
    required Kg oneStep,
    required ProgressionRegime regime,
  }) {
    final snapped = loads.snapDown(desiredExternal);
    final increment = desiredExternal - base;
    final realizable =
        snapped > base &&
        increment >= oneStep * config.minIncrementStepFraction;

    if (!realizable) {
      return _spendOnReps(
        base: base,
        targetReps: targetReps,
        shortfallFraction: (desiredEffective - lastEffective).fractionOf(
          desiredEffective,
        ),
        regime: regime,
        incrementWasTooSmall: true,
      );
    }

    // Rounded down, never up: make up the shortfall in reps (~1 rep per 3%).
    final shortfall = (desiredEffective - effectiveLoad.effective(snapped))
        .fractionOf(desiredEffective);
    final extraReps = (shortfall / config.loadFractionPerRep).floor();
    why.add(ReasonCode.weightStep);
    why.add(ReasonCode.repsReset);
    if (extraReps > 0) why.add(ReasonCode.roundedDownAddedReps);
    return _decision(
      suggestion: _wrapLoad(snapped),
      targetReps: window.clamp(resetReps + extraReps),
      regime: regime,
      externalLoad: snapped,
      base: base,
      bridge: _bridgeFor(base),
    );
  }

  /// §4.3 licensed a decrease. Rounding down keeps it representable and errs light;
  /// the two-step ceiling keeps it from becoming a collapse.
  LoadDecision _applyDecrease({
    required Kg base,
    required Kg desiredExternal,
    required int targetReps,
    required int maxSteps,
    required ProgressionRegime regime,
  }) {
    var snapped = loads.snapDown(desiredExternal);
    final floorOfDecrease = loads.shift(base, -maxSteps);
    if (snapped < floorOfDecrease) snapped = floorOfDecrease;
    why.add(ReasonCode.loadDecrease);
    // Coarse dumbbells cannot express 10%: the nearest representable value below
    // the target is often further down than the cap allows. Going lighter than
    // asked is safe; going heavier is not.
    if (snapped < desiredExternal && !snapped.isCloseTo(desiredExternal)) {
      why.add(ReasonCode.decreaseRoundedDown);
    }
    if (snapped.isCloseTo(loads.floor)) why.add(ReasonCode.atEquipmentFloor);
    return _decision(
      suggestion: _wrapLoad(snapped),
      targetReps: targetReps,
      regime: regime,
      externalLoad: snapped,
      base: base,
    );
  }

  /// §4.5 first clause, and §4.7's backstop: the load can't move, so the reps do.
  /// At the top of the window that means one step up with the reps reset.
  LoadDecision _spendOnReps({
    required Kg base,
    required int targetReps,
    required double shortfallFraction,
    required ProgressionRegime regime,
    required bool incrementWasTooSmall,
  }) {
    if (targetReps < range.max) {
      final compensating = (shortfallFraction / config.loadFractionPerRep)
          .floor();
      final extraReps = compensating < 1 ? 1 : compensating;
      if (incrementWasTooSmall) why.add(ReasonCode.incrementTooSmallForStep);
      why.add(ReasonCode.repsProgress);
      return _decision(
        suggestion: _wrapLoad(base),
        targetReps: window.clamp(targetReps + extraReps),
        regime: regime,
        externalLoad: base,
      );
    }

    // Top of the rep window at target effort → jump one step, reset the reps.
    final stepped = loads.shift(base, 1);
    if (stepped <= base) {
      why.add(ReasonCode.atEquipmentFloor);
      return _decision(
        suggestion: _wrapLoad(base),
        targetReps: range.max,
        regime: regime,
        externalLoad: base,
      );
    }
    why.add(ReasonCode.topOfRangeStepUp);
    why.add(ReasonCode.weightStep);
    why.add(ReasonCode.repsReset);
    return _decision(
      suggestion: _wrapLoad(stepped),
      targetReps: resetReps,
      regime: regime,
      externalLoad: stepped,
      base: base,
      bridge: _bridgeFor(base),
    );
  }

  LoadDecision _applyLayoff(LayoffTier tier, Kg base, int targetReps) {
    final reason = layoffReason(tier);
    if (reason != null) why.add(reason);
    switch (tier) {
      case LayoffTier.none:
      case LayoffTier.hold:
        return _decision(
          suggestion: _wrapLoad(base),
          targetReps: targetReps,
          regime: ProgressionRegime.layoff,
          externalLoad: base,
        );
      case LayoffTier.reduce:
      case LayoffTier.reCalibrate:
        final fraction = layoffLoadFraction(tier, config);
        // Assistance is signed, so multiplying external load directly would move
        // −30 toward −27 and make the exercise harder after an absence. Reduce
        // the effective load, then convert back to the signed external value.
        final reducedTarget =
            input.profile.resistanceEquipment ==
                ResistanceEquipment.assistedStack
            ? effectiveLoad.external(effectiveLoad.effective(base) * fraction)
            : base * fraction;
        final reduced = loads.snapDown(reducedTarget);
        if (reduced.isCloseTo(loads.floor)) {
          why.add(ReasonCode.atEquipmentFloor);
        }
        // 28+ days: the compound lifts re-find their weights. Isolation and
        // machine work is safe to resume at −20% without a probe.
        final needsProbe =
            tier == LayoffTier.reCalibrate &&
            input.profile.movementClass.isCompound;
        return _decision(
          suggestion: needsProbe
              ? NeedsCalibration(
                  floor: reduced,
                  probeReps: config.calibrationProbeReps,
                )
              : _wrapLoad(reduced),
          targetReps: needsProbe ? config.calibrationProbeReps : targetReps,
          regime: ProgressionRegime.layoff,
          externalLoad: reduced,
          base: base,
        );
    }
  }

  // ── Bodyweight and timed: no load to resolve ──────────────────────────────

  LoadDecision _repsOnly() {
    final history = input.history;
    if (history == null) {
      why.add(ReasonCode.firstExposure);
      return _decision(
        suggestion: RepOrDurationTarget.reps(range.min),
        targetReps: range.min,
        regime: ProgressionRegime.repsOnly,
      );
    }
    final targetReps = _sanitizedTargetReps(history.targetReps);
    final lastReps = _sanitizedReps(history.lastReps);

    final tier = layoffTierFor(days, config);
    if (tier.changesLoad) {
      final reason = layoffReason(tier);
      if (reason != null) why.add(reason);
      return _decision(
        suggestion: RepOrDurationTarget.reps(range.min),
        targetReps: range.min,
        regime: ProgressionRegime.repsOnly,
      );
    }
    if (tier == LayoffTier.hold) {
      why.add(ReasonCode.layoffTier1);
      return _decision(
        suggestion: RepOrDurationTarget.reps(targetReps),
        targetReps: targetReps,
        regime: ProgressionRegime.repsOnly,
      );
    }

    final level = history.reportedEffort;
    if (level == null) {
      why.add(ReasonCode.noFeedbackHold);
      return _decision(
        suggestion: RepOrDurationTarget.reps(targetReps),
        targetReps: targetReps,
        regime: ProgressionRegime.repsOnly,
      );
    }
    final report = interpretEffort(level, config);
    if (!supportsProgress(report)) {
      // Harder than target: meet her where she is, never above the target.
      final next =
          licensesDecrease(
            effort: report,
            lastReps: lastReps,
            targetReps: targetReps,
          )
          ? window.clamp(lastReps)
          : targetReps;
      why.add(
        next < targetReps
            ? ReasonCode.loadDecrease
            : ReasonCode.asymmetricDownRuleHold,
      );
      return _decision(
        suggestion: RepOrDurationTarget.reps(next),
        targetReps: next,
        regime: ProgressionRegime.repsOnly,
      );
    }
    if (targetReps >= range.max) {
      // §3: add reps, then add a variation.
      why.add(ReasonCode.variationDue);
      return _decision(
        suggestion: RepOrDurationTarget.reps(range.max),
        targetReps: range.max,
        regime: ProgressionRegime.repsOnly,
      );
    }
    final step = report.rir >= input.effort.rir + 2
        ? config.bodyweightRepStep * 2
        : config.bodyweightRepStep;
    final next = window.clamp(targetReps + step);
    why.add(ReasonCode.bodyweightRepProgress);
    return _decision(
      suggestion: RepOrDurationTarget.reps(next),
      targetReps: next,
      regime: ProgressionRegime.repsOnly,
    );
  }

  LoadDecision _timed() {
    final history = input.history;
    final lastHold = history?.lastHold ?? config.timedHoldFloor;
    if (history == null) {
      why.add(ReasonCode.firstExposure);
      return _timedDecision(config.timedHoldFloor);
    }

    final tier = layoffTierFor(days, config);
    if (tier.changesLoad) {
      final reason = layoffReason(tier);
      if (reason != null) why.add(reason);
      return _timedDecision(_shiftHold(lastHold, -1));
    }
    if (tier == LayoffTier.hold) {
      why.add(ReasonCode.layoffTier1);
      return _timedDecision(lastHold);
    }

    final level = history.reportedEffort;
    if (level == null) {
      why.add(ReasonCode.noFeedbackHold);
      return _timedDecision(lastHold);
    }
    final report = interpretEffort(level, config);
    if (!supportsProgress(report)) {
      if (report.rpe >= 9) {
        why.add(ReasonCode.loadDecrease);
        return _timedDecision(_shiftHold(lastHold, -1));
      }
      why.add(ReasonCode.asymmetricDownRuleHold);
      return _timedDecision(lastHold);
    }
    if (lastHold >= config.timedHoldCeiling) {
      why.add(ReasonCode.variationDue);
      return _timedDecision(config.timedHoldCeiling);
    }
    why.add(ReasonCode.timedHoldProgress);
    final steps = report.rir >= input.effort.rir + 2 ? 2 : 1;
    return _timedDecision(_shiftHold(lastHold, steps));
  }

  Duration _shiftHold(Duration hold, int steps) {
    final shifted = hold + config.timedHoldStep * steps;
    if (shifted < config.timedHoldFloor) return config.timedHoldFloor;
    if (shifted > config.timedHoldCeiling) return config.timedHoldCeiling;
    return shifted;
  }

  LoadDecision _timedDecision(Duration hold) => _decision(
    suggestion: RepOrDurationTarget.hold(hold),
    targetReps: 1,
    regime: ProgressionRegime.timed,
    hold: hold,
  );

  // ── Plumbing ──────────────────────────────────────────────────────────────

  /// Bodyweight movements that can take extra load report the *added* load; a
  /// pure bodyweight suggestion is `BodyweightOnly()`.
  LoadSuggestion _wrapLoad(Kg load) =>
      input.profile.resistanceEquipment == ResistanceEquipment.bodyweight
      ? BodyweightOnly(added: load)
      : SuggestedLoad(load);

  /// §3.4: after a jump on isolation or single-side work, offer the drop-set
  /// bridge back to the old weight.
  DropBridge? _bridgeFor(Kg previousLoad) => isIsolationLike
      ? DropSetBridge(
          backOffLoad: previousLoad,
          backOffRepsMin: config.dropBridgeBackOffReps.min,
          backOffRepsMax: config.dropBridgeBackOffReps.max,
        )
      : null;

  LoadDecision _decision({
    required LoadSuggestion suggestion,
    required int targetReps,
    required ProgressionRegime regime,
    Kg? externalLoad,
    Kg? base,
    Duration? hold,
    DropBridge? bridge,
  }) {
    if (bridge != null) why.add(ReasonCode.dropBridgeOffered);
    return LoadDecision(
      suggestion: suggestion,
      targetReps: targetReps,
      regime: regime,
      hold: hold,
      externalLoad: externalLoad,
      bridge: bridge,
      stepsMoved: base == null || externalLoad == null
          ? 0
          : loads.stepsBetween(base, externalLoad),
      why: List<ReasonCode>.unmodifiable(why),
      warnings: List<EngineWarning>.unmodifiable(warnings),
    );
  }

  Kg _stepAt(Kg load) {
    final step = loads.stepAt(load);
    if (!step.isFinite || !step.isPositive) {
      warnings.add(const EngineWarning(WarningCode.invalidEquipmentStep));
      return config.loadTable(input.unitSystem).dumbbellStep;
    }
    return step;
  }

  // ── Sanitizers: every one of these keeps the function total ────────────────

  RepRange _sanitizedRange(RepRange range) {
    if (range.min <= range.max) return range;
    warnings.add(EngineWarning(WarningCode.invertedRepRange, '$range'));
    return RepRange(range.max, range.min);
  }

  RepRange _prescribableWindow() =>
      isIsolationLike && config.isolationRestartRange.min < range.min
      ? RepRange(config.isolationRestartRange.min, range.max)
      : range;

  int _sanitizedTargetReps(int reps) {
    if (window.contains(reps)) return reps;
    warnings.add(
      EngineWarning(WarningCode.targetRepsOutOfRange, '$reps not in $window'),
    );
    return window.clamp(reps);
  }

  int _sanitizedReps(int reps) {
    if (reps >= 1) return reps;
    warnings.add(EngineWarning(WarningCode.invalidReps, '$reps'));
    return 1;
  }

  int _sanitizedDays() {
    if (input.daysSinceLastSession >= 0) return input.daysSinceLastSession;
    warnings.add(
      EngineWarning(
        WarningCode.negativeLayoff,
        '${input.daysSinceLastSession}',
      ),
    );
    return 0;
  }

  EffectiveLoad _sanitizedEffectiveLoad() {
    var contribution = input.profile.bwContribution;
    if (!contribution.isFinite || contribution < 0 || contribution > 1) {
      warnings.add(
        EngineWarning(WarningCode.bwContributionOutOfRange, '$contribution'),
      );
      contribution = contribution.isFinite ? contribution.clamp(0.0, 1.0) : 0.0;
    }
    final bodyMass = input.bodyMass;
    if (contribution == 0) return EffectiveLoad.externalOnly;
    if (!bodyMass.isFinite || !bodyMass.isPositive) {
      // No body mass: run on external load only. The ratio formula is
      // scale-invariant in external load, so this degrades rather than breaks —
      // the percentage guardrails just read tighter than they should.
      warnings.add(
        EngineWarning(WarningCode.invalidBodyMass, '${bodyMass.value}'),
      );
      return EffectiveLoad.externalOnly;
    }
    return EffectiveLoad(bwContribution: contribution, bodyMass: bodyMass);
  }

  Kg _sanitizedBaseLoad(Kg load) {
    if (!load.isFinite) {
      warnings.add(EngineWarning(WarningCode.nonFiniteLoad, '${load.value}'));
      return loads.floor;
    }
    if (load < loads.floor) {
      warnings.add(
        EngineWarning(
          WarningCode.loadBelowEquipmentFloor,
          '${load.value} < ${loads.floor.value}',
        ),
      );
      return loads.floor;
    }
    if (loads.isRepresentable(load)) return load;
    final snapped = loads.snapDown(load);
    warnings.add(
      EngineWarning(
        WarningCode.lastLoadNotRepresentable,
        '${load.value} -> ${snapped.value}',
      ),
    );
    return snapped;
  }
}
