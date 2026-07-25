/// Every tuning number in `PROGRAMMING.md`, in one const object.
///
/// Nothing in the engine hardcodes a training number: a tuning change edits this
/// file and the decision table that tests it, in one reviewed commit. Decisions are
/// stamped with `configHash` so a replay can tell which numbers produced them.
library;

import '../content/exercise.dart';
import '../core/dose.dart';
import '../core/effort.dart';
import '../core/units.dart';
import 'equipment_loads.dart';

/// The quiz's goal labels (§2).
enum Goal {
  /// "Toned & defined"
  tonedAndDefined,

  /// "Stronger"
  stronger,

  /// "Build curves"
  buildCurves,

  /// "Feel healthier"
  feelHealthier,
}

/// Where a week sits in the 6-week mesocycle (§5b). Build 1–3, easier 4, push 5,
/// deload 6 — pinned, not floating.
enum MesocycleWeekKind { build, easier, push, deload }

/// Sets × rep range × effort target × rest, per goal (§2).
final class RepScheme {
  const RepScheme({
    required this.minSets,
    required this.maxSets,
    required this.range,
    required this.effort,
    required this.rest,
    this.extraSetOnEmphasis = false,
  })  : assert(minSets >= 1 && maxSets >= minSets);

  final int minSets;
  final int maxSets;
  final RepRange range;
  final EffortTarget effort;
  final Duration rest;

  /// "Build curves" gets +1 set on the emphasis area.
  final bool extraSetOnEmphasis;

  /// §2 RESOLVED: novices in their first 4 weeks are capped at 3 sets and 3+ RIR
  /// regardless of goal. Goal schemes unlock from week 5.
  RepScheme cappedForNovice(ProgrammingConfig config) => RepScheme(
        minSets: minSets > config.noviceMaxSets ? config.noviceMaxSets : minSets,
        maxSets: maxSets > config.noviceMaxSets ? config.noviceMaxSets : maxSets,
        range: range,
        effort: effort.rpe > config.noviceMaxRpe ? EffortTarget(config.noviceMaxRpe) : effort,
        rest: rest,
        // The +1 emphasis set is part of the unlocked goal scheme. Retaining it
        // here would let a novice Build Curves dose reach 4 sets despite the
        // explicit first-four-weeks cap of 3.
        extraSetOnEmphasis: false,
      );

  /// The opening dose for this scheme: top of the set count, bottom of the rep
  /// range (double progression climbs from there).
  RepsDose openingDose({bool isEmphasis = false}) => RepsDose(
        sets: maxSets + (isEmphasis && extraSetOnEmphasis ? 1 : 0),
        range: range,
        effort: effort,
        targetReps: range.min,
      );

  @override
  bool operator ==(Object other) =>
      other is RepScheme &&
      other.minSets == minSets &&
      other.maxSets == maxSets &&
      other.range == range &&
      other.effort == effort &&
      other.rest == rest &&
      other.extraSetOnEmphasis == extraSetOnEmphasis;

  @override
  int get hashCode =>
      Object.hash(minSets, maxSets, range, effort, rest, extraSetOnEmphasis);

  @override
  String toString() => 'RepScheme($minSets-${maxSets}x$range @$effort, '
      'rest ${rest.inSeconds}s)';
}

/// The tuning surface. Construct `const ProgrammingConfig()` for the shipped
/// defaults; override named fields in tests to probe a rule.
final class ProgrammingConfig {
  const ProgrammingConfig({
    this.repSchemes = _defaultRepSchemes,
    this.isolationRange = const RepRange(10, 15),
    this.isolationRestartRange = const RepRange(8, 10),
    this.dropBridgeBackOffReps = const RepRange(4, 5),
    this.noviceWeeks = 4,
    this.noviceMaxSets = 3,
    this.noviceMaxRpe = 7,
    this.metricLoads = _metricLoads,
    this.imperialLoads = _imperialLoads,
    this.mesocycleWeeks = 6,
    this.easierWeekIndex = 4,
    this.deloadWeekIndex = 6,
    this.easierWeekSetsDelta = -1,
    this.easierWeekRpeDelta = -1,
    this.deloadWeekRpeDelta = -2,
    this.deloadWeekLoadFraction = 0.80,
    this.newMesocycleStepUp = 1,
    this.layoffTier1Days = 7,
    this.layoffTier2Days = 14,
    this.layoffTier3Days = 28,
    this.layoffTier2LoadFraction = 0.90,
    this.layoffTier3LoadFraction = 0.80,
    this.calibrationProbeReps = 8,
    this.calibrationMaxTestSets = 2,
    this.calibrationProbeStepJump = 2,
    this.lowerBodyMachineProbeJumpMin = 0.50,
    this.lowerBodyMachineProbeJumpMax = 1.00,
    this.calibrationMinCleanReps = 5,
    this.calibrationRegimeMaxRpe = 4,
    this.calibrationMaxIncreaseFraction = 0.15,
    this.calibrationMaxSteps = 2,
    this.maxChangeFraction = 0.10,
    this.maxStepsPerAdjustment = 2,
    this.deadbandFraction = 0.02,
    this.maxInterpretedRir = 5,
    this.loadFractionPerRep = 0.03,
    this.minIncrementStepFraction = 0.50,
    this.epleyConstant = 30,
    this.stallSessions = 3,
    this.stallDeloadFraction = 0.10,
    this.missedBottomDropFraction = 0.10,
    this.lowEnergyLoadFraction = 0.90,
    this.timedHoldFloor = const Duration(seconds: 20),
    this.timedHoldStep = const Duration(seconds: 5),
    this.timedHoldCeiling = const Duration(seconds: 60),
    this.bodyweightRepStep = 1,
    this.exerciseCountByMinutes = const {30: 4, 45: 6, 60: 8},
    this.warmUpMinutes = 5,
    this.olderWarmUpMinutes = 7,
    this.machineLeanAge = 50,
    this.seatedPreferenceAge = 60,
    this.reportedRpeByLevel = _defaultReportedRpe,
    this.rpeBandByLevel = _defaultRpeBands,
  });

  // ── §2 Rep/set schemes by goal ─────────────────────────────────────────────
  final Map<Goal, RepScheme> repSchemes;

  /// §3 RESOLVED: isolation and single-side work use a wide range, and the weight
  /// only moves at the top of it — the smallest dumbbell jump is proportionally huge.
  final RepRange isolationRange;

  /// Where reps restart after an isolation weight jump ("restart at 8–10 reps").
  final RepRange isolationRestartRange;

  /// §3.4 drop-set bridge: back off to the old weight for another 4–5 reps.
  final RepRange dropBridgeBackOffReps;

  /// §2 RESOLVED: the novice cap applies for this many weeks.
  final int noviceWeeks;
  final int noviceMaxSets;

  /// RPE 7 = 3+ RIR. §4 "Beginner intensity policy".
  final int noviceMaxRpe;

  // ── §3 Weight increments ───────────────────────────────────────────────────
  final EquipmentLoadTable metricLoads;
  final EquipmentLoadTable imperialLoads;

  // ── §5b Mesocycle ──────────────────────────────────────────────────────────
  final int mesocycleWeeks;

  /// Week 4 of 6 is the easier week: reduced volume, weights held.
  final int easierWeekIndex;

  /// Week 6 of 6 is meaningfully lighter, then the next mesocycle starts fresh.
  final int deloadWeekIndex;

  final int easierWeekSetsDelta;
  final int easierWeekRpeDelta;
  final int deloadWeekRpeDelta;
  final double deloadWeekLoadFraction;

  /// Equipment steps up from where she left off when a new mesocycle starts.
  final int newMesocycleStepUp;

  // ── §6 Layoff tiers ────────────────────────────────────────────────────────
  /// 7–13 days away: repeat last weights, no increase.
  final int layoffTier1Days;

  /// 14–27 days away: −10%.
  final int layoffTier2Days;

  /// 28+ days away: −20% and re-calibrate the compound lifts.
  final int layoffTier3Days;
  final double layoffTier2LoadFraction;
  final double layoffTier3LoadFraction;

  // ── §7 Starting-weight calibration ─────────────────────────────────────────
  /// "Ask for 8 easy reps at that load, then one feel tap." RESOLVED: stays.
  final int calibrationProbeReps;
  final int calibrationMaxTestSets;

  /// Probe jump on "too easy": +2 steps.
  final int calibrationProbeStepJump;

  /// RESOLVED: on lower-body machines only, probe jumps are +50–100% per test set —
  /// the floor on a leg press is so far below any working weight that overshoot
  /// risk is minimal.
  final double lowerBodyMachineProbeJumpMin;
  final double lowerBodyMachineProbeJumpMax;

  /// §7.5 / §11: can't do this many clean reps at the floor → swap the pattern.
  final int calibrationMinCleanReps;

  // ── §4 Regimes and guardrails ──────────────────────────────────────────────
  /// §4.1: reported at or below this RPE means she is under her working weight.
  final int calibrationRegimeMaxRpe;

  /// §4.1: calibration jumps go up to +10–15%.
  final double calibrationMaxIncreaseFraction;

  /// §4.1: +2 steps on light dumbbells, and never more than that.
  final int calibrationMaxSteps;

  /// §4.2: ±10% or one equipment step, whichever is larger at light loads.
  final double maxChangeFraction;

  /// §4.2: never more than two steps in one adjustment.
  final int maxStepsPerAdjustment;

  /// §4.4: ignore computed changes under ~2% — below the reporting noise floor.
  final double deadbandFraction;

  /// §4: "Clamp interpreted RIR at 5" — the scale is meaningless beyond that.
  final int maxInterpretedRir;

  /// §4.5: 1 rep ≈ 2.5–3% of load. Used both for spending an unrealizable
  /// increment on reps and for compensating a round-down shortfall.
  final double loadFractionPerRep;

  /// §4.5: an increment smaller than half a step cannot be realized as weight.
  final double minIncrementStepFraction;

  /// The 30 in `(30 + reps + rir)`.
  final int epleyConstant;

  // ── §5 Stall and reactive deload ───────────────────────────────────────────
  final int stallSessions;
  final double stallDeloadFraction;

  /// Can't complete the bottom of the range on set 1 → drop 10%, same session.
  final double missedBottomDropFraction;

  /// §8 "Low energy today": −10% and the bottom of the rep range.
  final double lowEnergyLoadFraction;

  // ── Bodyweight and timed movements ─────────────────────────────────────────
  final Duration timedHoldFloor;
  final Duration timedHoldStep;

  /// Past this, add a harder variation rather than more seconds.
  final Duration timedHoldCeiling;
  final int bodyweightRepStep;

  // ── §8 Assembly ────────────────────────────────────────────────────────────
  final Map<int, int> exerciseCountByMinutes;

  /// One generic 5 minutes, bike or incline walk. RESOLVED: no per-exercise ramp
  /// sets in v1.
  final int warmUpMinutes;

  /// The spec says 60+ gets a longer warm-up but does not pin a duration. Seven
  /// minutes is the v1 authored default and remains configurable.
  final int olderWarmUpMinutes;

  /// Older novices (roughly 50+ *and* never trained) lean toward machine variants.
  final int machineLeanAge;

  /// 60+: longer warm-up, seated variants preferred where equivalent.
  final int seatedPreferenceAge;

  // ── §4 Feedback capture ────────────────────────────────────────────────────
  /// The RPE each of the five taps is read as: the end of the band that implies
  /// the *smaller* load change, because novices report imprecisely in both
  /// directions and §1.3 says hold rather than guess.
  final Map<EffortLevel, int> reportedRpeByLevel;

  /// The band each tap covers, for provenance and question copy.
  final Map<EffortLevel, RpeBand> rpeBandByLevel;

  // ── Derived helpers (pure, no state) ───────────────────────────────────────

  /// The scheme for [goal], with the novice cap applied when she is inside her
  /// first [noviceWeeks] weeks of training.
  RepScheme schemeFor(Goal goal, {int weeksTrained = 999}) {
    final scheme = repSchemes[goal] ?? repSchemes[Goal.tonedAndDefined]!;
    return weeksTrained < noviceWeeks ? scheme.cappedForNovice(this) : scheme;
  }

  /// Isolation and single-side work override the goal's rep range (§3).
  RepRange rangeFor(LoadProfile profile, RepScheme scheme) =>
      profile.movementClass.isIsolation || profile.laterality.isPerSide
          ? isolationRange
          : scheme.range;

  EquipmentLoadTable loadTable(UnitSystem unitSystem) =>
      unitSystem.isMetric ? metricLoads : imperialLoads;

  AvailableLoads availableLoads(LoadProfile profile, UnitSystem unitSystem) =>
      loadTable(unitSystem).loadsFor(profile);

  /// 1-based week inside the mesocycle → what kind of week it is (§5b).
  /// Weeks past the mesocycle wrap, so week 7 is week 1 of the next one.
  MesocycleWeekKind weekKind(int weekIndex) {
    final week = ((weekIndex - 1) % mesocycleWeeks) + 1;
    if (week == deloadWeekIndex) return MesocycleWeekKind.deload;
    if (week == easierWeekIndex) return MesocycleWeekKind.easier;
    if (week == easierWeekIndex + 1) return MesocycleWeekKind.push;
    return MesocycleWeekKind.build;
  }

  static const Map<Goal, RepScheme> _defaultRepSchemes = {
    // "leave 2–3 reps in the tank", 60–90s rest
    Goal.tonedAndDefined: RepScheme(
      minSets: 3,
      maxSets: 3,
      range: RepRange(10, 12),
      effort: EffortTarget(7),
      rest: Duration(seconds: 75),
    ),
    // "leave 2 reps", 90–150s rest
    Goal.stronger: RepScheme(
      minSets: 3,
      maxSets: 4,
      range: RepRange(6, 8),
      effort: EffortTarget(8),
      rest: Duration(seconds: 120),
    ),
    // "leave 1–2 reps", +1 set on emphasis, 90s rest
    Goal.buildCurves: RepScheme(
      minSets: 3,
      maxSets: 4,
      range: RepRange(8, 12),
      effort: EffortTarget(8),
      rest: Duration(seconds: 90),
      extraSetOnEmphasis: true,
    ),
    // "comfortable, never near failure", 60s rest
    Goal.feelHealthier: RepScheme(
      minSets: 2,
      maxSets: 3,
      range: RepRange(10, 12),
      effort: EffortTarget(6),
      rest: Duration(seconds: 60),
    ),
  };

  static const Map<EffortLevel, int> _defaultReportedRpe = {
    EffortLevel.wayTooEasy: 4,
    EffortLevel.aBitEasy: 6,
    EffortLevel.justRight: 7,
    EffortLevel.harderThanIdLike: 8,
    EffortLevel.tooHard: 9,
  };

  static const Map<EffortLevel, RpeBand> _defaultRpeBands = {
    EffortLevel.wayTooEasy: RpeBand(1, 4),
    EffortLevel.aBitEasy: RpeBand(5, 6),
    EffortLevel.justRight: RpeBand(7, 7),
    EffortLevel.harderThanIdLike: RpeBand(8, 8),
    EffortLevel.tooHard: RpeBand(9, 10),
  };

  /// §3 metric market: 20 kg bar, 2.5/5 kg bar steps, 2 kg dumbbell steps,
  /// 5 kg machine pins, 2.5 kg cable pins.
  static const EquipmentLoadTable _metricLoads = EquipmentLoadTable(
    barbellBar: Kg(20),
    barbellUpperStep: Kg(2.5),
    barbellLowerStep: Kg(5),
    dumbbellFloor: Kg(2),
    dumbbellStep: Kg(2),
    machineFloor: Kg(5),
    machineStep: Kg(5),
    cableFloor: Kg(2.5),
    cableStep: Kg(2.5),
    addedLoadStep: Kg(2),
  );

  /// §3 imperial market: 45 lb bar, 5/10 lb bar steps, **5 lb dumbbell steps**,
  /// 10 lb machine pins, 5 lb cable pins. Stored in kg like everything else.
  static const EquipmentLoadTable _imperialLoads = EquipmentLoadTable(
    barbellBar: Kg(45 * kgPerLb),
    barbellUpperStep: Kg(5 * kgPerLb),
    barbellLowerStep: Kg(10 * kgPerLb),
    dumbbellFloor: Kg(5 * kgPerLb),
    dumbbellStep: Kg(5 * kgPerLb),
    machineFloor: Kg(10 * kgPerLb),
    machineStep: Kg(10 * kgPerLb),
    cableFloor: Kg(5 * kgPerLb),
    cableStep: Kg(5 * kgPerLb),
    addedLoadStep: Kg(5 * kgPerLb),
  );
}
