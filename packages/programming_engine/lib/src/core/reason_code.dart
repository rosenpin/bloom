/// Why the engine decided what it decided.
///
/// Every prescription carries `why: List<ReasonCode>` — built in from day one, not
/// retrofitted. Powers the "we'll add a little next time" copy, support replay, and
/// self-explaining goldens. Codes are stable identifiers; copy lives in the app.
library;

enum ReasonCode {
  // ── First exposure and calibration (§7, §4.1) ──────────────────────────────
  /// Never performed before: the §7 probe runs instead of the formula.
  firstExposure,

  /// Reported at or below RPE 4 — she is under her working weight, so the jump is
  /// "finding the weight", not progression.
  calibrationRegimeJump,

  /// A calibration-regime jump was floored at one equipment step because the
  /// formula asked for less than the smallest thing that exists.
  calibrationMinimumStep,

  /// Reports have come back to the target band; normal progression resumes.
  calibrationSettled,

  // ── Progression (§4.5, §4.7) ───────────────────────────────────────────────
  /// Target reps went up inside the range; load held.
  repsProgress,

  /// Load went up one or more equipment steps.
  weightStep,

  /// Reps reset to the bottom of the range because the load moved.
  repsReset,

  /// Top of the rep window at target effort → one step up (§4.5, §4.7 "just right
  /// still always moves").
  topOfRangeStepUp,

  /// The ideal load fell between steps: rounded down, reps added for the shortfall.
  roundedDownAddedReps,

  /// The computed increment was smaller than half an equipment step, so the
  /// progress was spent on reps instead.
  incrementTooSmallForStep,

  // ── Holds and decreases (§4.2, §4.3, §4.4, §4.6, §5) ───────────────────────
  /// No feel tap: repeat identical. Silence is never permission.
  noFeedbackHold,

  /// Harder than target but reps were met and RPE < 9 — probably over-reporting,
  /// so hold rather than decrease (§4.3).
  asymmetricDownRuleHold,

  /// She reported harder than the effort target, so the load holds even though she
  /// beat the rep target and the formula asked for more (§1.3 "when feedback is
  /// ambiguous, hold — never increase").
  effortAboveTargetHold,

  /// Computed change under the deadband (~2% of effective load) — below the
  /// reporting noise floor.
  deadbandHold,

  /// Change clamped to the ±10%/one-step cap.
  cappedAtMaxChange,

  /// Load came down: reps missed, or RPE ≥9 reported.
  loadDecrease,

  /// The decrease rounded down past the ±10% cap because no representable load
  /// sits inside it (coarse dumbbells cannot express 10%).
  decreaseRoundedDown,

  /// Same load for three sessions without rep progress → −10%, rebuild (§5).
  /// Detected over history at session-resolve time.
  stallDeload,

  /// Two consecutive "too hard" reports selected a −10% rebuild at resolve
  /// time.
  reactiveDeload,

  /// Set 1 missed the bottom of the range, so remaining sets were immediately
  /// re-prescribed at −10%, snapped to real equipment (§5).
  missedBottomSameSessionDrop,

  // ── Layoff (§6) ────────────────────────────────────────────────────────────
  /// 7–13 days away: repeat last weights, no increase.
  layoffTier1,

  /// 14–27 days away: −10% on working weights.
  layoffTier2,

  /// 28+ days away: −20%, and the compound lifts re-calibrate.
  layoffTier3,

  // ── Mesocycle (§5b) ────────────────────────────────────────────────────────
  /// Week 4 of 6: reduced volume, weights held.
  easierWeek,

  /// Week 6 of 6: meaningfully lighter on purpose.
  deloadWeek,

  /// First week of a new mesocycle: a small step up from where she left off.
  newMesocycleStep,

  // ── Bodyweight and timed ───────────────────────────────────────────────────
  /// Rep target on a bodyweight movement went up.
  bodyweightRepProgress,

  /// Hold duration on a timed movement went up.
  timedHoldProgress,

  /// Top of the rep/hold window on a bodyweight movement — time for a harder
  /// variation (§3 "add a variation").
  variationDue,

  /// A drop-set bridge is offered on the final set (§3.4).
  dropBridgeOffered,

  // ── Session modifiers and safety (§8, §9, §11) ─────────────────────────────
  /// "Low energy today": same exercises, −10%, bottom of the range.
  lowEnergy,

  /// Mid-session low-energy modifier applied to still-unstarted work.
  lowEnergyApplied,

  /// Session shortened: isolation dropped from the end, primaries kept.
  shortened,

  /// A swap was applied; region/session purpose was preserved, while the target
  /// exercise retained its own dose and progression history.
  swapApplied,

  /// Pain was reported on this exercise: excluded until she says otherwise.
  painExclusion,

  /// Already at the lightest load this equipment can express.
  atEquipmentFloor,
}
