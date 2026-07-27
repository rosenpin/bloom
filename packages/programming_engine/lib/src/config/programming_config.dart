/// Every tuning number in `PROGRAMMING.md`, in one const object.
///
/// Nothing in the engine hardcodes a training number: a tuning change edits this
/// file and the decision table that tests it, in one reviewed commit. Decisions are
/// stamped with `configHash` so a replay can tell which numbers produced them.
library;

import 'dart:math' as math;

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
  }) : assert(minSets >= 1 && maxSets >= minSets);

  final int minSets;
  final int maxSets;
  final RepRange range;
  final EffortTarget effort;
  final Duration rest;

  /// Optional scheme-level emphasis bonus. Shipped goal schemes leave this
  /// false; emphasis-driven volume comes from plan assembly.
  final bool extraSetOnEmphasis;

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
  String toString() =>
      'RepScheme($minSets-${maxSets}x$range @$effort, '
      'rest ${rest.inSeconds}s)';
}

/// The tuning surface. Construct [ProgrammingConfig] for the shipped defaults;
/// override named fields in tests to probe a rule.
final class ProgrammingConfig {
  const ProgrammingConfig({
    this.repSchemes = _defaultRepSchemes,
    this.isolationRange = const RepRange(10, 15),
    this.isolationRestartRange = const RepRange(8, 10),
    this.dropBridgeBackOffReps = const RepRange(4, 5),
    this.rpeRampBase = 7,
    this.rpeRampPerWeek = 0.25,
    this.setsRampBase = 3,
    this.setsRampPerWeek = 0.25,
    this.metricLoads = _metricLoads,
    this.imperialLoads = _imperialLoads,
    this.mesocycleWeeks = 6,
    this.weekSetsDelta = _defaultWeekSetsDelta,
    this.weekRpeDelta = _defaultWeekRpeDelta,
    this.weekLoadScale = _defaultWeekLoadScale,
    this.newMesocycleStepUp = 1,
    this.layoffGraceDays = 7,
    this.layoffSlopePerDay = 0.0075,
    this.layoffFloor = 0.80,
    this.calibrationProbeReps = 8,
    this.calibrationMaxTestSets = 2,
    this.calibrationJumpFraction = 0.15,
    this.probeLoadFractionByMovementClass =
        _defaultProbeLoadFractionByMovementClass,
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
    this.warmUpMinutesByAgeBand = _defaultWarmUpMinutesByAgeBand,
    this.machineAffinityNewToIt = 0.6,
    this.machineAffinityBeenAWhile = 0.3,
    this.machineAffinityTrainsRegularly = 0.1,
    this.machineAffinityAge50To59 = 0.4,
    this.machineAffinityAge60Plus = 0.5,
    this.machineAffinityLowComfort = 0.2,
    this.machineAffinityMostlyFineComfort = 0.1,
    this.machineAffinityTotallyAtHomeComfort = 0,
    this.seatedPreferenceWeight = 1,
    this.seatedPreferenceStartAge = 50,
    this.seatedPreferenceFullAge = 60,
    this.reportedRpeByLevel = _defaultReportedRpe,
    this.rpeBandByLevel = _defaultRpeBands,
  }) : assert(mesocycleWeeks >= 1),
       assert(rpeRampBase >= 1 && rpeRampBase <= 10),
       assert(rpeRampPerWeek >= 0),
       assert(setsRampBase >= 1),
       assert(setsRampPerWeek >= 0),
       assert(newMesocycleStepUp > 0),
       assert(layoffGraceDays >= 0),
       assert(layoffSlopePerDay > 0 && layoffSlopePerDay < 1),
       assert(layoffFloor > 0 && layoffFloor < 1),
       assert(calibrationProbeReps > 0),
       assert(calibrationMaxTestSets > 0),
       assert(calibrationJumpFraction > 0 && calibrationJumpFraction < 1),
       assert(calibrationMinCleanReps > 0),
       assert(
         calibrationMaxIncreaseFraction > 0 &&
             calibrationMaxIncreaseFraction < 1,
       ),
       assert(calibrationMaxSteps > 0),
       assert(maxChangeFraction > 0 && maxChangeFraction < 1),
       assert(maxStepsPerAdjustment > 0),
       assert(deadbandFraction > 0 && deadbandFraction < 1),
       assert(loadFractionPerRep > 0 && loadFractionPerRep < 1),
       assert(minIncrementStepFraction > 0 && minIncrementStepFraction <= 1),
       assert(epleyConstant > 0),
       assert(stallSessions > 0),
       assert(stallDeloadFraction > 0 && stallDeloadFraction < 1),
       assert(missedBottomDropFraction > 0 && missedBottomDropFraction < 1),
       assert(lowEnergyLoadFraction > 0 && lowEnergyLoadFraction < 1),
       assert(bodyweightRepStep > 0),
       assert(machineAffinityNewToIt >= 0 && machineAffinityNewToIt <= 1),
       assert(machineAffinityBeenAWhile >= 0 && machineAffinityBeenAWhile <= 1),
       assert(
         machineAffinityTrainsRegularly >= 0 &&
             machineAffinityTrainsRegularly <= 1,
       ),
       assert(machineAffinityAge50To59 >= 0 && machineAffinityAge50To59 <= 1),
       assert(machineAffinityAge60Plus >= 0 && machineAffinityAge60Plus <= 1),
       assert(machineAffinityLowComfort >= 0 && machineAffinityLowComfort <= 1),
       assert(
         machineAffinityMostlyFineComfort >= 0 &&
             machineAffinityMostlyFineComfort <= 1,
       ),
       assert(
         machineAffinityTotallyAtHomeComfort >= 0 &&
             machineAffinityTotallyAtHomeComfort <= 1,
       ),
       assert(seatedPreferenceWeight >= 0),
       assert(seatedPreferenceFullAge > seatedPreferenceStartAge);

  // ── §2 Rep/set schemes by goal ─────────────────────────────────────────────
  final Map<Goal, RepScheme> repSchemes;

  /// §3 RESOLVED: isolation and single-side work use a wide range, and the weight
  /// only moves at the top of it — the smallest dumbbell jump is proportionally huge.
  final RepRange isolationRange;

  /// Where reps restart after an isolation weight jump ("restart at 8–10 reps").
  final RepRange isolationRestartRange;

  /// §3.4 drop-set bridge: back off to the old weight for another 4–5 reps.
  final RepRange dropBridgeBackOffReps;

  /// §2 RESOLVED 2026-07-27: experience feeds one dose ramp.
  final double rpeRampBase;
  final double rpeRampPerWeek;
  final double setsRampBase;
  final double setsRampPerWeek;

  // ── §3 Weight increments ───────────────────────────────────────────────────
  final EquipmentLoadTable metricLoads;
  final EquipmentLoadTable imperialLoads;

  // ── §5b Mesocycle ──────────────────────────────────────────────────────────
  final int mesocycleWeeks;

  /// Per-week data applied to the one base dose held by a plan exercise.
  final List<int> weekSetsDelta;
  final List<int> weekRpeDelta;
  final List<double> weekLoadScale;

  /// Equipment steps up from where she left off when a new mesocycle starts.
  final int newMesocycleStepUp;

  // ── §6 Layoff curve ────────────────────────────────────────────────────────
  final int layoffGraceDays;
  final double layoffSlopePerDay;
  final double layoffFloor;

  // ── §7 Starting-weight calibration ─────────────────────────────────────────
  /// "Ask for 8 easy reps at that load, then one feel tap." RESOLVED: stays.
  final int calibrationProbeReps;
  final int calibrationMaxTestSets;

  /// DRAFT §7: fraction of expected working load used for each probe jump.
  final double calibrationJumpFraction;

  /// DRAFT §7 body-mass coefficients by movement class. Together with
  /// `(1 - bwContribution)` they estimate external working load.
  final Map<MovementClass, double> probeLoadFractionByMovementClass;

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

  /// DRAFT §8, ordered like `AgeBand.values`: 5, 5, 5, 6, 7 minutes.
  final List<int> warmUpMinutesByAgeBand;

  /// DRAFT §8 scoring contribution for "new to it".
  final double machineAffinityNewToIt;

  /// DRAFT §8 scoring contribution for "been a while".
  final double machineAffinityBeenAWhile;

  /// DRAFT §8 scoring contribution for "trains regularly".
  final double machineAffinityTrainsRegularly;

  /// DRAFT §8 scoring contribution for ages 50–59.
  final double machineAffinityAge50To59;

  /// DRAFT §8 scoring contribution for ages 60+.
  final double machineAffinityAge60Plus;

  /// DRAFT §8 scoring contribution for low gym comfort.
  final double machineAffinityLowComfort;

  /// DRAFT §8 scoring contribution for "mostly fine" gym comfort.
  final double machineAffinityMostlyFineComfort;

  /// DRAFT §8 scoring contribution for "totally at home" gym comfort.
  final double machineAffinityTotallyAtHomeComfort;

  /// DRAFT §8 additive candidate-score contribution for seated variants.
  final double seatedPreferenceWeight;
  final int seatedPreferenceStartAge;
  final int seatedPreferenceFullAge;

  // ── §4 Feedback capture ────────────────────────────────────────────────────
  /// The RPE each of the five taps is read as: the end of the band that implies
  /// the *smaller* load change, because novices report imprecisely in both
  /// directions and §1.3 says hold rather than guess.
  final Map<EffortLevel, int> reportedRpeByLevel;

  /// The band each tap covers, for provenance and question copy.
  final Map<EffortLevel, RpeBand> rpeBandByLevel;

  // ── Derived helpers (pure, no state) ───────────────────────────────────────

  /// The scheme for [goal], computed through the same experience ramp for every
  /// non-negative [weeksTrained] value.
  RepScheme schemeFor(Goal goal, {int weeksTrained = 999}) {
    final scheme = repSchemes[goal];
    assert(scheme != null, 'missing rep scheme for ${goal.name}');
    assert(weeksTrained >= 0);
    final targetSets = math.min(
      scheme!.maxSets,
      (setsRampBase + setsRampPerWeek * weeksTrained).floor(),
    );
    final targetRpe = math.min(
      scheme.effort.rpe,
      (rpeRampBase + rpeRampPerWeek * weeksTrained).floor(),
    );
    return RepScheme(
      minSets: math.min(scheme.minSets, targetSets),
      maxSets: targetSets,
      range: scheme.range,
      effort: EffortTarget(targetRpe),
      rest: scheme.rest,
      extraSetOnEmphasis: scheme.extraSetOnEmphasis,
    );
  }

  void assertTimedDoseConfiguration() {
    assert(timedHoldFloor > Duration.zero);
    assert(timedHoldStep > Duration.zero);
    assert(timedHoldCeiling >= timedHoldFloor);
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

  int _weekOffset(int weekIndex) {
    assert(weekIndex >= 1);
    return (weekIndex - 1) % mesocycleWeeks;
  }

  int weekSetsDeltaFor(int weekIndex) => weekSetsDelta[_weekOffset(weekIndex)];

  int weekRpeDeltaFor(int weekIndex) => weekRpeDelta[_weekOffset(weekIndex)];

  double weekLoadScaleFor(int weekIndex) =>
      weekLoadScale[_weekOffset(weekIndex)];

  /// Derives telemetry/UI labels from the vectors. The label never selects a
  /// training computation.
  MesocycleWeekKind weekKind(int weekIndex) {
    final offset = _weekOffset(weekIndex);
    if (weekLoadScale[offset] < 1) return MesocycleWeekKind.deload;
    if (weekSetsDelta[offset] < 0 || weekRpeDelta[offset] < 0) {
      return MesocycleWeekKind.easier;
    }
    final previous = (offset - 1) % mesocycleWeeks;
    if (weekLoadScale[previous] == 1 &&
        (weekSetsDelta[previous] < 0 || weekRpeDelta[previous] < 0)) {
      return MesocycleWeekKind.push;
    }
    return MesocycleWeekKind.build;
  }

  /// Applies the configured week vector to the plan's one base dose.
  Dose doseForWeek(Dose baseDose, int weekIndex) {
    final sets = baseDose.sets + weekSetsDeltaFor(weekIndex);
    assert(sets >= 1, 'week set delta must preserve a positive dose');
    return switch (baseDose) {
      RepsDose(:final range, :final effort, :final targetReps) => RepsDose(
        sets: sets,
        range: range,
        effort: EffortTarget(
          (effort.rpe + weekRpeDeltaFor(weekIndex)).clamp(1, 10),
        ),
        targetReps: targetReps,
      ),
      TimedDose(:final hold) => TimedDose(sets: sets, hold: hold),
    };
  }

  void assertParametricConfiguration() {
    assert(weekSetsDelta.length == mesocycleWeeks);
    assert(weekRpeDelta.length == mesocycleWeeks);
    assert(weekLoadScale.length == mesocycleWeeks);
    assert(weekLoadScale.every((scale) => scale > 0 && scale <= 1));
    assert(warmUpMinutesByAgeBand.every((minutes) => minutes > 0));
    assert(
      MovementClass.values.every(
        (movementClass) =>
            probeLoadFractionByMovementClass[movementClass] != null &&
            probeLoadFractionByMovementClass[movementClass]!.isFinite &&
            probeLoadFractionByMovementClass[movementClass]! >= 0,
      ),
      'every movement class needs a non-negative probe-load coefficient',
    );
  }

  static const List<int> _defaultWeekSetsDelta = <int>[0, 0, 0, -1, 0, 0];
  static const List<int> _defaultWeekRpeDelta = <int>[0, 0, 0, -1, 0, -2];
  static const List<double> _defaultWeekLoadScale = <double>[
    1,
    1,
    1,
    1,
    1,
    0.8,
  ];

  static const List<int> _defaultWarmUpMinutesByAgeBand = <int>[5, 5, 5, 6, 7];

  static const Map<MovementClass, double>
  _defaultProbeLoadFractionByMovementClass = <MovementClass, double>{
    MovementClass.compoundLower: 0.6,
    MovementClass.compoundUpperPush: 0.3,
    MovementClass.compoundUpperPull: 0.3,
    MovementClass.isolationLower: 0.15,
    MovementClass.isolationUpper: 0.15,
    MovementClass.core: 0.15,
    MovementClass.cardio: 0.15,
  };

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
    // RESOLVED (Tomer, 2026-07-26): "Build curves" is the same hypertrophy
    // scheme as "Toned & defined". The distinct quiz label stays for marketing
    // honesty; emphasis-driven volume comes from the emphasis answer.
    Goal.buildCurves: RepScheme(
      minSets: 3,
      maxSets: 3,
      range: RepRange(10, 12),
      effort: EffortTarget(7),
      rest: Duration(seconds: 75),
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
  static const EquipmentLoadTable _metricLoads = EquipmentLoadTable.trusted(
    barbellBar: Kg(20),
    barbellUpperStep: Kg(2.5),
    barbellLowerStep: Kg(5),
    dumbbellFloor: Kg(2),
    dumbbellStep: Kg(2),
    machineFloor: Kg(5),
    machineStep: Kg(5),
    // DRAFT assisted-stack defaults: 50 kg maximum, 5 kg pins.
    assistedStackMaxAssistance: Kg(50),
    assistedStackStep: Kg(5),
    cableFloor: Kg(2.5),
    cableStep: Kg(2.5),
    addedLoadStep: Kg(2),
  );

  /// §3 imperial market: 45 lb bar, 5/10 lb bar steps, **5 lb dumbbell steps**,
  /// 10 lb machine pins, 5 lb cable pins. Stored in kg like everything else.
  static const EquipmentLoadTable _imperialLoads = EquipmentLoadTable.trusted(
    barbellBar: Kg(45 * kgPerLb),
    barbellUpperStep: Kg(5 * kgPerLb),
    barbellLowerStep: Kg(10 * kgPerLb),
    dumbbellFloor: Kg(5 * kgPerLb),
    dumbbellStep: Kg(5 * kgPerLb),
    machineFloor: Kg(10 * kgPerLb),
    machineStep: Kg(10 * kgPerLb),
    // DRAFT assisted-stack defaults: 110 lb maximum, 10 lb pins.
    assistedStackMaxAssistance: Kg(110 * kgPerLb),
    assistedStackStep: Kg(10 * kgPerLb),
    cableFloor: Kg(5 * kgPerLb),
    cableStep: Kg(5 * kgPerLb),
    addedLoadStep: Kg(5 * kgPerLb),
  );
}
