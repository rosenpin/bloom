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
/// Stored data is validated at the app boundary. This layer trusts its types;
/// programmer and configuration mistakes are assertions.
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
import 'effective_load.dart';
import 'effort_mapping.dart';
import 'layoff.dart';

/// What the fold over the event log knows about one exercise from last time.
final class ExerciseSnapshot {
  ExerciseSnapshot({
    required this.lastLoad,
    required this.lastReps,
    required this.targetReps,
    this.reportedEffort,
    this.lastHold,
  }) : assert(
         lastLoad.value > double.negativeInfinity &&
             lastLoad.value < double.infinity,
       ),
       assert(lastReps >= 1),
       assert(targetReps >= 1),
       assert(lastHold == null || lastHold.inMicroseconds > 0);

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
  ProgressionInput({
    required this.profile,
    required this.range,
    required this.effort,
    required this.unitSystem,
    this.history,
    this.bodyMass,
    this.daysSinceLastSession = 0,
    this.preSuggesterAdjustment,
  }) : assert(
         bodyMass == null ||
             (bodyMass.value > 0 && bodyMass.value < double.infinity),
       );

  final LoadProfile profile;

  /// The rep window the plan prescribes for this exercise.
  final RepRange range;

  /// The effort target for this week (the easier week is just an easier target).
  final EffortTarget effort;
  final UnitSystem unitSystem;

  /// `null` → first exposure, which always goes through the §7 probe.
  final ExerciseSnapshot? history;

  /// Needed only for movements with `bw_contribution > 0`.
  ///
  /// Absence is a designed state: effective-load math then uses the external
  /// load only.
  final Kg? bodyMass;

  /// Days since her last completed session — injected, never read from a clock.
  final int daysSinceLastSession;

  /// A session-resolve rule selected from the folded history before this
  /// suggester is invoked. The load edge owns the actual equipment snapping.
  final PreSuggesterAdjustment? preSuggesterAdjustment;
}

enum PreSuggesterAdjustmentKind { hold, fractionalDeload, stepUp }

/// A higher-order session rule already selected by `resolveSession`.
///
/// Keeping its realization here preserves the architecture rule that equipment
/// ladders and signed assisted-stack snapping live only in [LoadSuggester].
final class PreSuggesterAdjustment {
  const PreSuggesterAdjustment.hold(this.reason)
    : kind = PreSuggesterAdjustmentKind.hold,
      loadFraction = 1,
      steps = 0,
      strictlyLighter = false;

  const PreSuggesterAdjustment.fractionalDeload({
    required this.reason,
    required this.loadFraction,
    this.strictlyLighter = true,
  }) : kind = PreSuggesterAdjustmentKind.fractionalDeload,
       steps = 0,
       assert(loadFraction > 0 && loadFraction < 1);

  const PreSuggesterAdjustment.stepUp({
    required this.reason,
    required this.steps,
  }) : kind = PreSuggesterAdjustmentKind.stepUp,
       loadFraction = 1,
       strictlyLighter = false,
       assert(steps > 0);

  final PreSuggesterAdjustmentKind kind;
  final ReasonCode reason;
  final double loadFraction;
  final int steps;
  final bool strictlyLighter;

  @override
  bool operator ==(Object other) =>
      other is PreSuggesterAdjustment &&
      other.kind == kind &&
      other.reason == reason &&
      other.loadFraction == loadFraction &&
      other.steps == steps &&
      other.strictlyLighter == strictlyLighter;

  @override
  int get hashCode =>
      Object.hash(kind, reason, loadFraction, steps, strictlyLighter);
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

  bool get loadChanged => stepsMoved != 0;

  @override
  String toString() =>
      'LoadDecision($suggestion, $targetReps reps, '
      '${regime.name}, steps $stepsMoved, why [${why.map((r) => r.name).join(', ')}]'
      ')';
}

/// §4's decision logic. Const-constructible and stateless — the same inputs always
/// produce the same output.
final class LoadSuggester {
  const LoadSuggester([this.config = const ProgrammingConfig()]);

  final ProgrammingConfig config;

  @useResult
  LoadDecision suggest(ProgressionInput input) => _Pass(config, input).run();
}

enum _DoseStep { loadSteps, repSteps, holdSteps }

/// One invocation's trusted context plus its accumulating explanation. Private:
/// the public surface is [LoadSuggester.suggest].
final class _Pass {
  _Pass(this.config, this.input)
    : loads = config.availableLoads(input.profile, input.unitSystem);

  final ProgrammingConfig config;
  final ProgressionInput input;
  final AvailableLoads loads;

  final List<ReasonCode> why = <ReasonCode>[];

  late final RepRange range = input.range;

  /// The reps we may legally prescribe. Isolation work can sit below the range's
  /// bottom right after a weight jump (§3: "restart at 8–10 reps" under a 10–15
  /// range).
  late final RepRange window = _prescribableWindow();
  late final EffectiveLoad effectiveLoad = _effectiveLoad();

  /// A stored session can appear in the future after device clock skew. This is
  /// elapsed-time normalization, not a training-data warning.
  late final int days = input.daysSinceLastSession < 0
      ? 0
      : input.daysSinceLastSession;

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
    if (input.profile.metricType == MetricType.timed) {
      config.assertTimedDoseConfiguration();
    }
    return _progress(switch (input.profile.metricType) {
      MetricType.loadReps => _DoseStep.loadSteps,
      MetricType.repsOnly => _DoseStep.repSteps,
      MetricType.timed => _DoseStep.holdSteps,
    });
  }

  /// The shared §4 decision skeleton. Each strategy supplies only how its dose
  /// starts, holds, decreases, and progresses; ordering stays identical:
  /// first exposure → preselected session rule → layoff → no feedback →
  /// effort interpretation → progress/hold/decrease.
  LoadDecision _progress(_DoseStep step) {
    final history = input.history;
    if (history == null) return _firstExposure(step);

    final base = step == _DoseStep.loadSteps
        ? _baseLoad(history.lastLoad)
        : null;
    final targetReps = step == _DoseStep.holdSteps
        ? null
        : _targetReps(history.targetReps);
    final lastHold = step == _DoseStep.holdSteps
        ? history.lastHold ?? config.timedHoldFloor
        : null;

    final adjustment = input.preSuggesterAdjustment;
    if (adjustment != null) {
      return _applyStepAdjustment(
        step,
        adjustment,
        base: base,
        targetReps: targetReps,
        lastHold: lastHold,
      );
    }

    final tier = layoffTierFor(days, config);
    if (tier != LayoffTier.none) {
      return _applyStepLayoff(
        step,
        tier,
        base: base,
        targetReps: targetReps,
        lastHold: lastHold,
      );
    }

    final level = history.reportedEffort;
    if (level == null) {
      why.add(ReasonCode.noFeedbackHold);
      return _holdStep(
        step,
        base: base,
        targetReps: targetReps,
        lastHold: lastHold,
      );
    }

    final report = interpretEffort(level, config);
    return switch (step) {
      _DoseStep.loadSteps => _interpretLoad(
        history,
        report,
        base: base!,
        targetReps: targetReps!,
      ),
      _DoseStep.repSteps => _interpretReps(
        history,
        report,
        targetReps: targetReps!,
      ),
      _DoseStep.holdSteps => _interpretHold(report, lastHold: lastHold!),
    };
  }

  LoadDecision _firstExposure(_DoseStep step) {
    why.add(ReasonCode.firstExposure);
    return switch (step) {
      _DoseStep.loadSteps => _decision(
        suggestion: NeedsCalibration(
          floor: loads.floor,
          probeReps: config.calibrationProbeReps,
        ),
        targetReps: config.calibrationProbeReps,
        regime: ProgressionRegime.firstExposure,
        externalLoad: loads.floor,
      ),
      _DoseStep.repSteps => _decision(
        suggestion: RepOrDurationTarget.reps(range.min),
        targetReps: range.min,
        regime: ProgressionRegime.repsOnly,
      ),
      _DoseStep.holdSteps => _timedDecision(config.timedHoldFloor),
    };
  }

  LoadDecision _applyStepAdjustment(
    _DoseStep step,
    PreSuggesterAdjustment adjustment, {
    required Kg? base,
    required int? targetReps,
    required Duration? lastHold,
  }) {
    switch (step) {
      case _DoseStep.loadSteps:
        return _applyPreSuggesterAdjustment(adjustment, base!, targetReps!);
      case _DoseStep.repSteps:
        why.add(adjustment.reason);
        return switch (adjustment.kind) {
          PreSuggesterAdjustmentKind.hold => _repsDecision(targetReps!),
          PreSuggesterAdjustmentKind.fractionalDeload => _repsDecision(
            range.min,
          ),
          PreSuggesterAdjustmentKind.stepUp => _repsDecision(
            window.clamp(
              targetReps! + config.bodyweightRepStep * adjustment.steps,
            ),
          ),
        };
      case _DoseStep.holdSteps:
        why.add(adjustment.reason);
        return switch (adjustment.kind) {
          PreSuggesterAdjustmentKind.hold => _timedDecision(lastHold!),
          PreSuggesterAdjustmentKind.fractionalDeload => _timedDecision(
            _shiftHold(lastHold!, -1),
          ),
          PreSuggesterAdjustmentKind.stepUp => _timedDecision(
            _shiftHold(lastHold!, adjustment.steps),
          ),
        };
    }
  }

  LoadDecision _applyStepLayoff(
    _DoseStep step,
    LayoffTier tier, {
    required Kg? base,
    required int? targetReps,
    required Duration? lastHold,
  }) {
    switch (step) {
      case _DoseStep.loadSteps:
        return _applyLayoff(tier, base!, targetReps!);
      case _DoseStep.repSteps:
        final reason = layoffReason(tier);
        if (reason != null) why.add(reason);
        return _repsDecision(tier.changesLoad ? range.min : targetReps!);
      case _DoseStep.holdSteps:
        final reason = layoffReason(tier);
        if (reason != null) why.add(reason);
        return _timedDecision(
          tier.changesLoad ? _shiftHold(lastHold!, -1) : lastHold!,
        );
    }
  }

  LoadDecision _holdStep(
    _DoseStep step, {
    required Kg? base,
    required int? targetReps,
    required Duration? lastHold,
  }) => switch (step) {
    _DoseStep.loadSteps => _decision(
      suggestion: _wrapLoad(base!),
      targetReps: targetReps!,
      regime: ProgressionRegime.noFeedback,
      externalLoad: base,
    ),
    _DoseStep.repSteps => _repsDecision(targetReps!),
    _DoseStep.holdSteps => _timedDecision(lastHold!),
  };

  // ── Load × reps: the §4 formula and guardrail pipeline ─────────────────────

  LoadDecision _interpretLoad(
    ExerciseSnapshot history,
    InterpretedEffort report, {
    required Kg base,
    required int targetReps,
  }) {
    final lastReps = history.lastReps;
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
      // With body mass absent, a zero external load has no scale for percentage
      // math. External-only mode therefore holds until a load or mass exists.
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
    // somewhere, so it comes from reps. The rule row says "+1-2 reps": exactly
    // at target earns +1; reporting easier than target earns +2, so "a bit
    // easy" visibly outpaces "just right" and struggling visibly lags both.
    if (progressAllowed) {
      return _spendOnReps(
        base: base,
        targetReps: targetReps,
        shortfallFraction: 0,
        regime: regime,
        incrementWasTooSmall: false,
        minExtraReps: report.rir > input.effort.rir ? 2 : 1,
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
    int minExtraReps = 1,
  }) {
    if (targetReps < range.max) {
      final compensating = (shortfallFraction / config.loadFractionPerRep)
          .floor();
      final extraReps = compensating < minExtraReps
          ? minExtraReps
          : compensating;
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

  LoadDecision _applyPreSuggesterAdjustment(
    PreSuggesterAdjustment adjustment,
    Kg base,
    int targetReps,
  ) {
    why.add(adjustment.reason);
    switch (adjustment.kind) {
      case PreSuggesterAdjustmentKind.hold:
        return _decision(
          suggestion: _wrapLoad(base),
          targetReps: targetReps,
          regime: ProgressionRegime.normal,
          externalLoad: base,
        );
      case PreSuggesterAdjustmentKind.stepUp:
        final stepped = loads.shift(base, adjustment.steps);
        if (stepped > base) {
          why
            ..add(ReasonCode.weightStep)
            ..add(ReasonCode.repsReset);
        }
        return _decision(
          suggestion: _wrapLoad(stepped),
          targetReps: targetReps,
          regime: ProgressionRegime.normal,
          externalLoad: stepped,
          base: base,
        );
      case PreSuggesterAdjustmentKind.fractionalDeload:
        final fraction = adjustment.loadFraction;
        final lastEffective = effectiveLoad.effective(base);
        final desired = lastEffective.isPositive
            ? effectiveLoad.external(lastEffective * fraction)
            : base * fraction;
        var reduced = loads.snapDown(desired);
        if (adjustment.strictlyLighter && reduced >= base) {
          reduced = loads.shift(base, -1);
        }
        if (reduced < base) why.add(ReasonCode.loadDecrease);
        if (reduced.isCloseTo(loads.floor)) {
          why.add(ReasonCode.atEquipmentFloor);
        }
        return _decision(
          suggestion: _wrapLoad(reduced),
          targetReps: targetReps,
          regime: ProgressionRegime.normal,
          externalLoad: reduced,
          base: base,
        );
    }
  }

  // ── Bodyweight and timed strategy steps ───────────────────────────────────

  LoadDecision _interpretReps(
    ExerciseSnapshot history,
    InterpretedEffort report, {
    required int targetReps,
  }) {
    final lastReps = history.lastReps;
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

  LoadDecision _interpretHold(
    InterpretedEffort report, {
    required Duration lastHold,
  }) {
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

  LoadDecision _repsDecision(int reps) => _decision(
    suggestion: RepOrDurationTarget.reps(reps),
    targetReps: reps,
    regime: ProgressionRegime.repsOnly,
  );

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
    );
  }

  Kg _stepAt(Kg load) {
    final step = loads.stepAt(load);
    assert(step.isFinite && step.isPositive);
    return step;
  }

  RepRange _prescribableWindow() =>
      isIsolationLike && config.isolationRestartRange.min < range.min
      ? RepRange(config.isolationRestartRange.min, range.max)
      : range;

  /// Legacy events without prescription context use actual reps as their target;
  /// a later plan may have a different window, so that real migration path clamps
  /// here without treating it as malformed data.
  int _targetReps(int reps) => window.clamp(reps);

  EffectiveLoad _effectiveLoad() {
    final contribution = input.profile.bwContribution;
    assert(contribution.isFinite && contribution >= 0 && contribution <= 1);
    final bodyMass = input.bodyMass;
    if (contribution == 0 || bodyMass == null) {
      return EffectiveLoad.externalOnly;
    }
    return EffectiveLoad(bwContribution: contribution, bodyMass: bodyMass);
  }

  Kg _baseLoad(Kg load) {
    assert(load.isFinite);
    // A user may edit a set to 3.7 kg. Equipment snapping is intentional
    // normalization into the configured gym ladder, not error recovery.
    return loads.snapDown(load);
  }
}
