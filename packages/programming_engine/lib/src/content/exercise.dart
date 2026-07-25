/// Typed content attributes — the schema in `EXERCISES.md` › "Exercise metadata
/// schema", expressed as interfaces the engine reads.
///
/// `ENGINE.md` › "Content model": typed attributes in data, predicate in code.
/// There is deliberately **no rule representation to grow** — adding a dimension
/// costs a schema migration plus an engine release, and that friction is the guard.
///
/// Nothing here persists anything. The app's Drift rows and the web funnel's const
/// catalog both implement [Exercise].
library;

import '../core/events.dart' show SwapReason;
import '../core/prescription.dart';
import '../core/units.dart';

/// Broad movement family. Drives block filling and which equipment step applies.
enum MovementClass {
  compoundLower,
  compoundUpperPush,
  compoundUpperPull,
  isolationLower,
  isolationUpper,
  core,
  cardio;

  bool get isCompound =>
      this == compoundLower ||
      this == compoundUpperPush ||
      this == compoundUpperPull;

  bool get isIsolation => this == isolationLower || this == isolationUpper;

  /// Barbell steps are +5 kg total on lower body, +2.5 kg on upper (§3).
  bool get isLowerBody => this == compoundLower || this == isolationLower;
}

/// The authored slot an exercise can fill (§8).
enum BlockRole {
  warmUp,
  lowerHinge,
  lowerSquat,
  upperPush,
  upperPull,
  gluteIsolation,
  legIsolation,
  armShoulderIsolation,
  core,
  finisherCardio;

  /// Primaries are never dropped by "shorten today" (§8).
  bool get isPrimary =>
      this == lowerHinge ||
      this == lowerSquat ||
      this == upperPush ||
      this == upperPull;

  bool get isIsolation =>
      this == gluteIsolation ||
      this == legIsolation ||
      this == armShoulderIsolation;

  /// The broad training purpose a §9 swap must preserve. The revised swap rule
  /// deliberately permits changing the narrower movement pattern or block role.
  SwapRegionPurpose get swapRegionPurpose => switch (this) {
    lowerHinge ||
    lowerSquat ||
    gluteIsolation ||
    legIsolation => SwapRegionPurpose.lowerBody,
    upperPush ||
    upperPull ||
    armShoulderIsolation => SwapRegionPurpose.upperBody,
    core => SwapRegionPurpose.core,
    warmUp => SwapRegionPurpose.warmUp,
    finisherCardio => SwapRegionPurpose.cardio,
  };
}

/// The broad region/session purpose preserved by every §9 swap.
enum SwapRegionPurpose { lowerBody, upperBody, core, warmUp, cardio }

/// What a set of this exercise is measured in.
enum MetricType {
  /// Load × reps — the only type with a load to resolve.
  loadReps,

  /// Reps only (push-ups, crunches): progression is reps, then a harder variation.
  repsOnly,

  /// A hold (plank): progression is duration.
  timed;

  bool get hasLoad => this == loadReps;
}

/// Where the resistance comes from. Determines the available-load set together
/// with the unit system.
enum ResistanceEquipment {
  barbell,
  dumbbell,

  /// Selectorized machine — pin steps.
  machine,

  /// Gravitron-style stack. The selected assistance is stored as a negative
  /// external load, from the negative stack maximum up to zero.
  assistedStack,

  cable,

  /// Bodyweight, optionally with added load.
  bodyweight;

  bool get isPinLoaded =>
      this == machine || this == assistedStack || this == cable;
}

/// What she needs besides the resistance itself — used for swap filtering.
enum SupportEquipment {
  none,
  bench,
  inclineBench,
  rack,
  mat,
  box,
  platform,
  hipThrustPad,
}

enum MuscleGroup {
  glutes,
  quads,
  hamstrings,
  adductors,
  abductors,
  calves,
  lats,
  upperBack,
  rearDelts,
  chest,
  shoulders,
  biceps,
  triceps,
  forearms,
  core,
  obliques,
  lowerBack,
}

enum MuscleRole { primary, secondary }

/// One muscle and how hard it works. `quads P, glutes P, core S`.
final class MuscleTarget {
  const MuscleTarget(this.muscle, this.role);

  const MuscleTarget.primary(this.muscle) : role = MuscleRole.primary;
  const MuscleTarget.secondary(this.muscle) : role = MuscleRole.secondary;

  final MuscleGroup muscle;
  final MuscleRole role;

  @override
  bool operator ==(Object other) =>
      other is MuscleTarget && other.muscle == muscle && other.role == role;

  @override
  int get hashCode => Object.hash(muscle, role);

  @override
  String toString() =>
      '${muscle.name}:${role == MuscleRole.primary ? 'P' : 'S'}';
}

/// Authored now, used later — joint-load balancing is a future feature (⏸ in
/// `EXERCISES.md`), but backfilling this across 40 exercises would be expensive.
enum JointAction {
  hipExtension,
  hipFlexion,
  hipAbduction,
  hipAdduction,
  kneeExtension,
  kneeFlexion,
  anklePlantarflexion,
  spinalExtension,
  trunkFlexion,
  trunkBrace,
  shoulderFlexion,
  shoulderExtension,
  shoulderAbduction,
  horizontalPush,
  horizontalPull,
  verticalPush,
  verticalPull,
  scapularRetraction,
  elbowFlexion,
  elbowExtension,
  grip,
}

/// Eligibility tier.
enum DifficultyTier { beginner, intermediate, advanced }

/// How much lifting she has done before. Quiz-derived; ordered, so
/// `index >= exercise.minExperience.index` is the eligibility test.
enum ExperienceTier {
  neverTrained,
  returningAfterBreak,
  trainsSometimes,
  trainsRegularly,
}

/// How intimidating the setup is in a commercial gym. Gym comfort is the first
/// dimension the assembler may relax when a block would otherwise be empty.
enum IntimidationTier { low, moderate, high }

/// A hard age boundary, separate from the 60+ seated *preference*. The fallback
/// ladder never relaxes this value.
enum AgeEligibility { allAges, under60, under50 }

/// Whether the movement is safe to prescribe in a self-guided product. The
/// assembler never relaxes this value.
enum SafetyEligibility { selfGuided, instructorRequired }

/// The slice of an exercise the load math needs. Kept narrow so `LoadSuggester`
/// depends on five attributes rather than the whole content row.
abstract interface class LoadProfile {
  ResistanceEquipment get resistanceEquipment;
  MovementClass get movementClass;
  MetricType get metricType;
  Laterality get laterality;

  /// Fraction of body mass in the lift: goblet squat ≈0.65, push-up ≈0.65,
  /// plank ≈1.0, leg extension 0. `effectiveLoad = external + bw × bodyMass`.
  double get bwContribution;

  /// Per-exercise increment, when the machine's pin steps are known (§3 "store
  /// per-exercise if known"). `null` falls back to the family default for her
  /// unit system.
  Kg? get loadStepOverride;
}

/// The authored content row.
abstract interface class Exercise implements LoadProfile {
  String get id;

  /// Folder in `scraped_gym/data/videos/` where a reference video exists.
  String get slug;
  String get name;

  BlockRole get blockRole;
  List<MuscleTarget> get targetMuscles;
  List<JointAction> get primaryJointActions;
  List<JointAction> get secondaryJointActions;

  /// 1–5. Authored now, used later.
  int get romRank;

  /// 1–5. Authored now, used later (difficulty-tier input).
  int get stabilityRank;

  DifficultyTier get difficultyTier;

  /// Eligibility: she needs at least this much experience.
  ExperienceTier get minExperience;

  /// Eligibility: low-comfort profiles accept only [IntimidationTier.low], while
  /// progressively more comfortable profiles accept more involved setups.
  IntimidationTier get intimidationTier;

  /// Hard age and safety gates. Like low-comfort intimidation, these are never
  /// relaxed by plan assembly; experience alone has a warned fallback.
  AgeEligibility get ageEligibility;
  SafetyEligibility get safetyEligibility;

  /// Authored as a machine-lean variant for §8's affinity quota. This includes
  /// literal machines plus supported calibration-floor variants.
  bool get machineLeanOk;

  /// A seated variant, preferred for 60+ where equivalent (§8).
  bool get seatedVariant;

  SupportEquipment get supportEquipment;

  /// Tombstone. Retired exercises are never hard-deleted; plans hold resolved
  /// copies. `ENGINE.md` › CI invariants.
  DateTime? get retiredAt;

  // ── Copy (exercise screen) ────────────────────────────────────────────────
  List<String> get setupSteps;
  String get shouldFeel;
  String get stopIf;

  /// "Where to find it in the gym" — anti-intimidation content.
  String get findIt;
  List<String> get dos;
  List<String> get donts;

  bool get isRetired => retiredAt != null;
}

/// A const, immutable [Exercise]. Useful for the web quiz funnel's baked-in
/// catalog and for tests; the app's content tables implement [Exercise] directly.
final class ExerciseData implements Exercise {
  const ExerciseData({
    required this.id,
    required this.name,
    required this.blockRole,
    required this.movementClass,
    required this.metricType,
    required this.resistanceEquipment,
    required this.bwContribution,
    this.slug = '',
    this.laterality = Laterality.bilateral,
    this.loadStepOverride,
    this.targetMuscles = const <MuscleTarget>[],
    this.primaryJointActions = const <JointAction>[],
    this.secondaryJointActions = const <JointAction>[],
    this.romRank = 3,
    this.stabilityRank = 3,
    this.difficultyTier = DifficultyTier.beginner,
    this.minExperience = ExperienceTier.neverTrained,
    this.intimidationTier = IntimidationTier.low,
    this.ageEligibility = AgeEligibility.allAges,
    this.safetyEligibility = SafetyEligibility.selfGuided,
    this.machineLeanOk = false,
    this.seatedVariant = false,
    this.supportEquipment = SupportEquipment.none,
    this.retiredAt,
    this.setupSteps = const <String>[],
    this.shouldFeel = '',
    this.stopIf = '',
    this.findIt = '',
    this.dos = const <String>[],
    this.donts = const <String>[],
  });

  @override
  final String id;
  @override
  final String slug;
  @override
  final String name;
  @override
  final BlockRole blockRole;
  @override
  final MovementClass movementClass;
  @override
  final MetricType metricType;
  @override
  final ResistanceEquipment resistanceEquipment;
  @override
  final Laterality laterality;
  @override
  final double bwContribution;
  @override
  final Kg? loadStepOverride;
  @override
  final List<MuscleTarget> targetMuscles;
  @override
  final List<JointAction> primaryJointActions;
  @override
  final List<JointAction> secondaryJointActions;
  @override
  final int romRank;
  @override
  final int stabilityRank;
  @override
  final DifficultyTier difficultyTier;
  @override
  final ExperienceTier minExperience;
  @override
  final IntimidationTier intimidationTier;
  @override
  final AgeEligibility ageEligibility;
  @override
  final SafetyEligibility safetyEligibility;
  @override
  final bool machineLeanOk;
  @override
  final bool seatedVariant;
  @override
  final SupportEquipment supportEquipment;
  @override
  final DateTime? retiredAt;
  @override
  final List<String> setupSteps;
  @override
  final String shouldFeel;
  @override
  final String stopIf;
  @override
  final String findIt;
  @override
  final List<String> dos;
  @override
  final List<String> donts;

  @override
  bool get isRetired => retiredAt != null;

  List<MuscleGroup> get primaryMuscles => targetMuscles
      .where((t) => t.role == MuscleRole.primary)
      .map((t) => t.muscle)
      .toList(growable: false);

  @override
  String toString() => 'ExerciseData($id)';
}

/// Whether an authored swap keeps the narrower movement pattern or deliberately
/// crosses it while preserving [SwapRegionPurpose].
enum SwapPatternRelation { patternPreserving, crossPattern }

/// An edge in the swap graph:
/// `(from_id, to_id, reason enum, rank int, pattern relation)`.
/// Ranks are unique per `(from, reason)` — ties would break determinism.
final class SwapEdge {
  const SwapEdge({
    required this.fromId,
    required this.toId,
    required this.reason,
    required this.rank,
    this.patternRelation = SwapPatternRelation.patternPreserving,
  }) : assert(rank >= 0);

  final String fromId;
  final String toId;
  final SwapReason reason;
  final int rank;
  final SwapPatternRelation patternRelation;

  @override
  bool operator ==(Object other) =>
      other is SwapEdge &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.reason == reason &&
      other.rank == rank &&
      other.patternRelation == patternRelation;

  @override
  int get hashCode => Object.hash(fromId, toId, reason, rank, patternRelation);

  @override
  String toString() =>
      'SwapEdge($fromId -> $toId, ${reason.name}, #$rank, '
      '${patternRelation.name})';
}

/// A versioned, deterministic content snapshot. Exercise order is authorial:
/// within each block role it is the candidate order the assembler rotates over.
abstract interface class ContentCatalog {
  String get contentVersion;
  List<Exercise> get exercises;
  List<SwapEdge> get swapEdges;

  /// Only these authored block roles advance with `Profile.mesocycleIndex`.
  Set<BlockRole> get rotatingBlockRoles;
}

/// Immutable in-memory implementation used by the seed/test fixture and web
/// funnel. The app's persisted content adapter can implement [ContentCatalog]
/// directly.
final class ContentCatalogData implements ContentCatalog {
  ContentCatalogData({
    required this.contentVersion,
    required Iterable<Exercise> exercises,
    required Iterable<SwapEdge> swapEdges,
    required Iterable<BlockRole> rotatingBlockRoles,
  }) : exercises = List<Exercise>.unmodifiable(exercises),
       swapEdges = List<SwapEdge>.unmodifiable(swapEdges),
       rotatingBlockRoles = Set<BlockRole>.unmodifiable(rotatingBlockRoles);

  @override
  final String contentVersion;
  @override
  final List<Exercise> exercises;
  @override
  final List<SwapEdge> swapEdges;
  @override
  final Set<BlockRole> rotatingBlockRoles;
}
