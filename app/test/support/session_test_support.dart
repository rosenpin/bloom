import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/features/onboarding/domain/onboarding_answers.dart';
import 'package:womens_gym/features/plan/domain/stored_plan_document.dart';

OnboardingAnswers sessionTestAnswers({
  engine.UnitSystem unitSystem = engine.UnitSystem.metric,
}) => OnboardingAnswers(
  unitSystem: unitSystem,
  ageBand: engine.AgeBand.age30To39,
  goal: engine.Goal.tonedAndDefined,
  daysPerWeek: engine.TrainingDaysPerWeek.two,
  sessionMinutes: engine.SessionMinutes.thirty,
  experienceTier: engine.ProfileExperienceTier.newToIt,
  gymComfort: engine.GymComfort.low,
  emphasis: engine.Emphasis.glutes,
  completed: true,
);

Future<StoredPlanDocument> storeSessionTestPlan(
  ProviderContainer container, {
  engine.UnitSystem unitSystem = engine.UnitSystem.metric,
}) async {
  final answers = sessionTestAnswers(unitSystem: unitSystem);
  await container.read(onboardingRepositoryProvider).save(answers);
  return container
      .read(planRepositoryProvider)
      .store(
        sessionTestPlan(),
        onboardingRepository: container.read(onboardingRepositoryProvider),
        unitSystem: unitSystem,
      );
}

engine.Plan sessionTestPlan() {
  final doses = <engine.MesocycleWeekKind, engine.Dose>{
    for (final kind in engine.MesocycleWeekKind.values)
      kind: const engine.RepsDose(
        sets: 2,
        range: engine.RepRange(10, 12),
        effort: engine.EffortTarget.rpe7,
        targetReps: 10,
      ),
  };
  final isolationDoses = <engine.MesocycleWeekKind, engine.Dose>{
    for (final kind in engine.MesocycleWeekKind.values)
      kind: const engine.RepsDose(
        sets: 2,
        range: engine.RepRange(10, 15),
        effort: engine.EffortTarget.rpe7,
        targetReps: 10,
      ),
  };
  return engine.Plan(
    mesocycleIndex: 1,
    stamps: const engine.PlanStamps(
      engineVersion: 'session-test-engine',
      configHash: 'session-test-config',
      contentHash: 'session-test-content',
      profileHash: 'session-test-profile',
    ),
    mesocycleCalendar: const [
      engine.PlanWeek(weekIndex: 1, kind: engine.MesocycleWeekKind.build),
      engine.PlanWeek(weekIndex: 2, kind: engine.MesocycleWeekKind.build),
      engine.PlanWeek(weekIndex: 3, kind: engine.MesocycleWeekKind.build),
      engine.PlanWeek(weekIndex: 4, kind: engine.MesocycleWeekKind.easier),
      engine.PlanWeek(weekIndex: 5, kind: engine.MesocycleWeekKind.push),
      engine.PlanWeek(weekIndex: 6, kind: engine.MesocycleWeekKind.deload),
    ],
    days: [
      engine.PlanDay(
        dayIndex: 1,
        kind: engine.PlanDayKind.lowerGluteLed,
        warmUpMinutes: 5,
        hasCardioFinisher: false,
        exercises: [
          engine.PlanExercise(
            exerciseId: 'dumbbell-goblet-squat',
            name: 'Goblet Squat',
            blockRole: engine.BlockRole.lowerSquat,
            movementClass: engine.MovementClass.compoundLower,
            metricType: engine.MetricType.loadReps,
            laterality: engine.Laterality.bilateral,
            difficultyTier: engine.DifficultyTier.beginner,
            resistanceEquipment: engine.ResistanceEquipment.dumbbell,
            supportEquipment: engine.SupportEquipment.none,
            bwContribution: 0.65,
            loadStepOverride: null,
            dropPriority: 0,
            isEmphasis: false,
            rotatesAcrossMesocycles: false,
            rotationCandidateIds: const [],
            orderedSwapCandidates: [
              engine.PlanSwapCandidate(
                exerciseId: 'bodyweight-squat',
                name: 'Bodyweight Squat',
                blockRole: engine.BlockRole.lowerSquat,
                movementClass: engine.MovementClass.compoundLower,
                metricType: engine.MetricType.repsOnly,
                laterality: engine.Laterality.bilateral,
                difficultyTier: engine.DifficultyTier.beginner,
                resistanceEquipment: engine.ResistanceEquipment.bodyweight,
                supportEquipment: engine.SupportEquipment.none,
                bwContribution: 0.65,
                loadStepOverride: null,
                tier: 1,
                rank: 0,
                doseByWeekKind: doses,
                repRange: const engine.RepRange(10, 12),
              ),
            ],
            doseByWeekKind: doses,
            repRange: const engine.RepRange(10, 12),
          ),
          engine.PlanExercise(
            exerciseId: 'dumbbell-lateral-raise',
            name: 'Dumbbell Lateral Raise',
            blockRole: engine.BlockRole.armShoulderIsolation,
            movementClass: engine.MovementClass.isolationUpper,
            metricType: engine.MetricType.loadReps,
            laterality: engine.Laterality.bilateral,
            difficultyTier: engine.DifficultyTier.beginner,
            resistanceEquipment: engine.ResistanceEquipment.dumbbell,
            supportEquipment: engine.SupportEquipment.none,
            bwContribution: 0,
            loadStepOverride: null,
            dropPriority: 10,
            isEmphasis: false,
            rotatesAcrossMesocycles: false,
            rotationCandidateIds: const [],
            orderedSwapCandidates: [
              engine.PlanSwapCandidate(
                exerciseId: 'dumbbell-curl',
                name: 'Dumbbell Curl',
                blockRole: engine.BlockRole.armShoulderIsolation,
                movementClass: engine.MovementClass.isolationUpper,
                metricType: engine.MetricType.loadReps,
                laterality: engine.Laterality.bilateral,
                difficultyTier: engine.DifficultyTier.beginner,
                resistanceEquipment: engine.ResistanceEquipment.dumbbell,
                supportEquipment: engine.SupportEquipment.none,
                bwContribution: 0,
                loadStepOverride: null,
                tier: 1,
                rank: 0,
                doseByWeekKind: isolationDoses,
                repRange: const engine.RepRange(10, 15),
              ),
              engine.PlanSwapCandidate(
                exerciseId: 'cable-rope-pushdown',
                name: 'Cable Rope Pushdown',
                blockRole: engine.BlockRole.armShoulderIsolation,
                movementClass: engine.MovementClass.isolationUpper,
                metricType: engine.MetricType.loadReps,
                laterality: engine.Laterality.bilateral,
                difficultyTier: engine.DifficultyTier.beginner,
                resistanceEquipment: engine.ResistanceEquipment.cable,
                supportEquipment: engine.SupportEquipment.none,
                bwContribution: 0,
                loadStepOverride: null,
                tier: 3,
                rank: 0,
                doseByWeekKind: isolationDoses,
                repRange: const engine.RepRange(10, 15),
              ),
            ],
            doseByWeekKind: isolationDoses,
            repRange: const engine.RepRange(10, 15),
          ),
        ],
      ),
    ],
    warnings: const [],
  );
}
