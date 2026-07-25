/// Shared fixtures: a handful of real exercises from `EXERCISES.md`, chosen to
/// span the cases the load math has to get right — coarse dumbbells, fine machine
/// pins, a high `bw_contribution` compound, a per-side movement, a timed hold and a
/// reps-only bodyweight movement.
library;

import 'package:programming_engine/programming_engine.dart';

/// #1 Goblet Squat — the `bw_contribution` case: 0.65 of body mass rides along, so
/// +2 kg is ~4% of the load moved for a 70 kg user, not 20%.
const gobletSquat = ExerciseData(
  id: 'dumbbell-goblet-squat',
  slug: 'dumbbell-goblet-squat',
  name: 'Goblet Squat',
  blockRole: BlockRole.lowerSquat,
  movementClass: MovementClass.compoundLower,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.dumbbell,
  bwContribution: 0.65,
  targetMuscles: [
    MuscleTarget.primary(MuscleGroup.quads),
    MuscleTarget.primary(MuscleGroup.glutes),
    MuscleTarget.secondary(MuscleGroup.core),
  ],
  primaryJointActions: [JointAction.kneeExtension, JointAction.hipExtension],
  romRank: 4,
  stabilityRank: 3,
);

/// #31 Dumbbell Lateral Raise — the §3 coarse-step case: 4 → 6 kg is +50%.
const lateralRaise = ExerciseData(
  id: 'dumbbell-lateral-raise',
  slug: 'dumbbell-lateral-raise',
  name: 'Dumbbell Lateral Raise',
  blockRole: BlockRole.armShoulderIsolation,
  movementClass: MovementClass.isolationUpper,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.dumbbell,
  bwContribution: 0,
  targetMuscles: [MuscleTarget.primary(MuscleGroup.shoulders)],
);

/// #2 Barbell Back Squat — 5 kg steps (lower body), 20 kg bar floor.
const barbellSquat = ExerciseData(
  id: 'barbell-squat',
  slug: 'barbell-squat',
  name: 'Barbell Back Squat',
  blockRole: BlockRole.lowerSquat,
  movementClass: MovementClass.compoundLower,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.barbell,
  bwContribution: 0.85,
  supportEquipment: SupportEquipment.rack,
  targetMuscles: [
    MuscleTarget.primary(MuscleGroup.quads),
    MuscleTarget.primary(MuscleGroup.glutes),
  ],
);

/// #21 Barbell Bench Press — 2.5 kg steps (upper body).
const barbellBench = ExerciseData(
  id: 'barbell-bench-press',
  slug: 'barbell-bench-press',
  name: 'Barbell Bench Press',
  blockRole: BlockRole.upperPush,
  movementClass: MovementClass.compoundUpperPush,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.barbell,
  bwContribution: 0,
  supportEquipment: SupportEquipment.bench,
);

/// #3 Leg Press — fine pins relative to the load, so the ±10% cap binds before the
/// step ceiling does.
const legPress = ExerciseData(
  id: 'machine-leg-press',
  slug: 'machine-leg-press',
  name: 'Leg Press',
  blockRole: BlockRole.lowerSquat,
  movementClass: MovementClass.compoundLower,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.machine,
  bwContribution: 0,
  machineLeanOk: true,
  seatedVariant: true,
);

/// #17 Leg Extension — machine isolation.
const legExtension = ExerciseData(
  id: 'machine-leg-extension',
  slug: 'machine-leg-extension',
  name: 'Leg Extension',
  blockRole: BlockRole.legIsolation,
  movementClass: MovementClass.isolationLower,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.machine,
  bwContribution: 0,
  machineLeanOk: true,
  seatedVariant: true,
);

/// #20 Dumbbell Bench Press — the lb-market case.
const dumbbellBench = ExerciseData(
  id: 'dumbbell-bench-press',
  slug: 'dumbbell-bench-press',
  name: 'Dumbbell Bench Press',
  blockRole: BlockRole.upperPush,
  movementClass: MovementClass.compoundUpperPush,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.dumbbell,
  bwContribution: 0,
  supportEquipment: SupportEquipment.bench,
);

/// #29 Assisted Pull-Up — assistance is a negative external load on a signed
/// stack. Progression moves toward zero.
const assistedPullUp = ExerciseData(
  id: 'bodyweight-assisted-chin-up',
  slug: 'bodyweight-assisted-chin-up',
  name: 'Assisted Pull-Up',
  blockRole: BlockRole.upperPull,
  movementClass: MovementClass.compoundUpperPull,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.assistedStack,
  bwContribution: 0.85,
  machineLeanOk: true,
);

/// #28 Single-Arm Dumbbell Row — per side, so it takes the isolation rep window.
const singleArmRow = ExerciseData(
  id: 'dumbbell-row-unilateral',
  slug: 'dumbbell-row-unilateral',
  name: 'Single-Arm Dumbbell Row',
  blockRole: BlockRole.upperPull,
  movementClass: MovementClass.compoundUpperPull,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.dumbbell,
  laterality: Laterality.perSide,
  bwContribution: 0,
  supportEquipment: SupportEquipment.bench,
);

/// #33 Cable Rope Pushdown — 2.5 kg cable pins.
const cablePushdown = ExerciseData(
  id: 'cable-rope-pushdown',
  slug: 'cable-rope-pushdown',
  name: 'Cable Rope Pushdown',
  blockRole: BlockRole.armShoulderIsolation,
  movementClass: MovementClass.isolationUpper,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.cable,
  bwContribution: 0,
);

/// #14 Hip Abduction Machine with an authored 2.5 kg pin — the per-exercise step
/// override.
const hipAbduction = ExerciseData(
  id: 'machine-hip-abduction',
  slug: 'machine-hip-abduction',
  name: 'Hip Abduction Machine',
  blockRole: BlockRole.gluteIsolation,
  movementClass: MovementClass.isolationLower,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.machine,
  bwContribution: 0,
  loadStepOverride: Kg(2.5),
  machineLeanOk: true,
  seatedVariant: true,
);

/// #25 Push-Up — reps-only.
const pushUp = ExerciseData(
  id: 'bodyweight-push-up',
  name: 'Push-Up',
  blockRole: BlockRole.upperPush,
  movementClass: MovementClass.compoundUpperPush,
  metricType: MetricType.repsOnly,
  resistanceEquipment: ResistanceEquipment.bodyweight,
  bwContribution: 0.65,
);

/// #34 Plank — timed.
const plank = ExerciseData(
  id: 'plank',
  slug: 'plank',
  name: 'Plank',
  blockRole: BlockRole.core,
  movementClass: MovementClass.core,
  metricType: MetricType.timed,
  resistanceEquipment: ResistanceEquipment.bodyweight,
  bwContribution: 1,
  supportEquipment: SupportEquipment.mat,
);

/// #13 Dumbbell Glute Bridge, treated as a bodyweight movement carrying added load —
/// exercises the `BodyweightOnly(added:)` branch.
const gluteBridgeAdded = ExerciseData(
  id: 'dumbbell-glute-bridge',
  slug: 'dumbbell-glute-bridge',
  name: 'Dumbbell Glute Bridge',
  blockRole: BlockRole.gluteIsolation,
  movementClass: MovementClass.isolationLower,
  metricType: MetricType.loadReps,
  resistanceEquipment: ResistanceEquipment.bodyweight,
  bwContribution: 0.4,
  supportEquipment: SupportEquipment.mat,
);

const config = ProgrammingConfig();
const suggester = LoadSuggester(config);

/// A 70 kg user — the reference body mass in `EXERCISES.md`'s worked example.
const referenceBodyMass = Kg(70);

/// Every load-metric fixture, for sweeps.
const loadMetricFixtures = <ExerciseData>[
  gobletSquat,
  lateralRaise,
  barbellSquat,
  barbellBench,
  legPress,
  legExtension,
  dumbbellBench,
  singleArmRow,
  cablePushdown,
  hipAbduction,
  gluteBridgeAdded,
];

/// Builds an input with the plumbing filled in, so a test row says only what it is
/// about.
ProgressionInput inputFor(
  ExerciseData exercise, {
  required RepRange range,
  EffortTarget effort = EffortTarget.rpe7,
  UnitSystem unitSystem = UnitSystem.metric,
  Kg? lastLoad,
  int lastReps = 10,
  int? targetReps,
  EffortLevel? reported,
  Duration? lastHold,
  bool noHistory = false,
  Kg bodyMass = referenceBodyMass,
  int daysSinceLastSession = 3,
}) => ProgressionInput(
  profile: exercise,
  range: range,
  effort: effort,
  unitSystem: unitSystem,
  bodyMass: bodyMass,
  daysSinceLastSession: daysSinceLastSession,
  history: noHistory
      ? null
      : ExerciseSnapshot(
          lastLoad: lastLoad ?? const Kg(12),
          lastReps: lastReps,
          targetReps: targetReps ?? range.min,
          reportedEffort: reported,
          lastHold: lastHold,
        ),
);

/// The compound rep window used by "toned & defined" (§2).
const compoundRange = RepRange(10, 12);

/// The §3 isolation window.
const isolationRange = RepRange(10, 15);
