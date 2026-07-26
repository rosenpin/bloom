/// Deterministic plan-time assembly (`ENGINE.md` build-order step 4).
library;

import '../config/equipment_loads.dart';
import '../config/programming_config.dart';
import '../content/exercise.dart';
import '../core/dose.dart';
import '../core/effort.dart';
import '../core/warnings.dart';
import '../profile/profile.dart';
import 'eligibility.dart';
import 'plan.dart';
import 'result.dart';

const String currentEngineVersion = '1.0.0-session-step-5';

/// §8's DRAFT machine-affinity score, clamped to [0, 1].
///
/// The 50+ "new to it" edge is forced to 1.0 rather than merely reaching it by
/// addition, so tuning any draft contribution cannot accidentally relax it.
double machineAffinityFor(Profile profile, ProgrammingConfig config) {
  if (profile.ageBand.minimumAge >= config.machineAffinityForcedAge &&
      profile.experienceTier == ProfileExperienceTier.newToIt) {
    return 1;
  }

  final experience = switch (profile.experienceTier) {
    ProfileExperienceTier.newToIt => config.machineAffinityNewToIt,
    ProfileExperienceTier.beenAWhile => config.machineAffinityBeenAWhile,
    ProfileExperienceTier.trainsRegularly =>
      config.machineAffinityTrainsRegularly,
  };
  final age = switch (profile.ageBand) {
    AgeBand.age18To29 || AgeBand.age30To39 || AgeBand.age40To49 => 0,
    AgeBand.age50To59 => config.machineAffinityAge50To59,
    AgeBand.age60Plus => config.machineAffinityAge60Plus,
  };
  final comfort = switch (profile.gymComfort) {
    GymComfort.low => config.machineAffinityLowComfort,
    GymComfort.mostlyFine => config.machineAffinityMostlyFineComfort,
    GymComfort.totallyAtHome => config.machineAffinityTotallyAtHomeComfort,
  };
  return (experience + age + comfort).clamp(0.0, 1.0);
}

Result<Plan> assemblePlan(
  Profile profile,
  ProgrammingConfig config,
  ContentCatalog catalog,
) {
  // Decided 2026-07-25: otherActivities is stored and stamped, but deliberately
  // does not affect selection. The quiz lacks activity-day placement, so changing
  // volume or plan days from this answer would be guesswork.

  if (config.mesocycleWeeks <= 0 ||
      config.easierWeekIndex < 1 ||
      config.easierWeekIndex > config.mesocycleWeeks ||
      config.deloadWeekIndex < 1 ||
      config.deloadWeekIndex > config.mesocycleWeeks) {
    return Failure<Plan>(
      PlanAssemblyError(
        code: PlanAssemblyErrorCode.invalidMesocycleConfiguration,
        message: 'Mesocycle week indexes must fit inside a positive mesocycle.',
      ),
    );
  }

  if (config.repSchemes[profile.goal] == null &&
      config.repSchemes[Goal.tonedAndDefined] == null) {
    return Failure<Plan>(
      PlanAssemblyError(
        code: PlanAssemblyErrorCode.missingRepSchemeConfiguration,
        message:
            'No ${profile.goal.name} or fallback rep scheme is configured.',
      ),
    );
  }

  final minutes = profile.sessionMinutes.value;
  final configuredCount = config.exerciseCountByMinutes[minutes];
  if (configuredCount == null) {
    return Failure<Plan>(
      PlanAssemblyError(
        code: PlanAssemblyErrorCode.missingExerciseCountConfiguration,
        message:
            'No exercise count is configured for $minutes-minute sessions.',
      ),
    );
  }

  final hasCardioFinisher = profile.sessionMinutes == SessionMinutes.sixty;
  final primaryCount = profile.sessionMinutes == SessionMinutes.thirty ? 2 : 3;
  final catalogExerciseCount = configuredCount - (hasCardioFinisher ? 1 : 0);
  final isolationCount = catalogExerciseCount - primaryCount;
  if (isolationCount < 1) {
    return Failure<Plan>(
      PlanAssemblyError(
        code: PlanAssemblyErrorCode.invalidExerciseCountConfiguration,
        message:
            '$minutes-minute sessions cannot preserve $primaryCount primaries '
            'and an isolation block with a configured count of $configuredCount.',
      ),
    );
  }

  final context = _AssemblyContext(
    profile: profile,
    config: config,
    catalog: catalog,
  );
  final dayKinds = _dayKindsFor(profile);
  final days = <PlanDay>[];
  for (var dayOffset = 0; dayOffset < dayKinds.length; dayOffset++) {
    days.add(
      context.buildDay(
        dayIndex: dayOffset + 1,
        kind: dayKinds[dayOffset],
        primaryCount: primaryCount,
        isolationCount: isolationCount,
        hasCardioFinisher: hasCardioFinisher,
      ),
    );
  }

  final assembledExerciseCount = days.fold<int>(
    0,
    (sum, day) => sum + day.exercises.length,
  );
  if (assembledExerciseCount == 0) {
    final affectedRoles = context.warnings
        .where((warning) => warning.code == WarningCode.blockDropped)
        .map(
          (warning) => BlockRole.values.firstWhere(
            (role) => warning.detail.contains('role=${role.name}'),
            orElse: () => BlockRole.warmUp,
          ),
        )
        .where((role) => role != BlockRole.warmUp)
        .toSet();
    return Failure<Plan>(
      PlanAssemblyError(
        code: PlanAssemblyErrorCode.noUsableExercises,
        message: 'No exercise survived the fixed eligibility fallback ladder.',
        affectedRoles: affectedRoles,
      ),
    );
  }

  return Success<Plan>(
    Plan(
      mesocycleIndex: profile.mesocycleIndex,
      stamps: PlanStamps(
        engineVersion: currentEngineVersion,
        configHash: _stableHash(_configCanonical(config)),
        contentHash: _stableHash(_contentCanonical(catalog)),
        profileHash: _stableHash(_profileCanonical(profile)),
      ),
      mesocycleCalendar: <PlanWeek>[
        for (var week = 1; week <= config.mesocycleWeeks; week++)
          PlanWeek(weekIndex: week, kind: config.weekKind(week)),
      ],
      days: days,
      warnings: context.warnings,
    ),
  );
}

List<PlanDayKind> _dayKindsFor(Profile profile) =>
    switch (profile.daysPerWeek) {
      TrainingDaysPerWeek.two => const [
        PlanDayKind.fullBodyA,
        PlanDayKind.fullBodyB,
      ],
      TrainingDaysPerWeek.three when profile.emphasis == Emphasis.glutes =>
        const [PlanDayKind.lower, PlanDayKind.upper, PlanDayKind.lower],
      TrainingDaysPerWeek.three => const [
        PlanDayKind.lower,
        PlanDayKind.upper,
        PlanDayKind.fullBodyA,
      ],
      TrainingDaysPerWeek.four => const [
        PlanDayKind.lower,
        PlanDayKind.upper,
        PlanDayKind.lowerGluteLed,
        PlanDayKind.upper,
      ],
    };

final class _AssemblyContext {
  _AssemblyContext({
    required this.profile,
    required this.config,
    required this.catalog,
  }) : exercisesById = <String, Exercise>{
         for (final exercise in catalog.exercises) exercise.id: exercise,
       };

  final Profile profile;
  final ProgrammingConfig config;
  final ContentCatalog catalog;
  final Map<String, Exercise> exercisesById;
  final Set<String> _weekExerciseIds = <String>{};
  final List<EngineWarning> warnings = <EngineWarning>[];

  PlanDay buildDay({
    required int dayIndex,
    required PlanDayKind kind,
    required int primaryCount,
    required int isolationCount,
    required bool hasCardioFinisher,
  }) {
    final dayExerciseIds = <String>{};
    final selected = <PlanExercise>[];
    final emphasisRole = _emphasisRole(kind);
    final primarySlots = _primarySlots(kind, emphasisRole, primaryCount);
    final isolationSlots = _isolationSlots(kind, emphasisRole, isolationCount);
    final isolationFirst =
        isolationSlots.isNotEmpty &&
        isolationSlots.first.isEmphasis &&
        isolationSlots.first.role == BlockRole.gluteIsolation;

    if (isolationFirst) {
      final slot = isolationSlots.first;
      _addSlot(
        selected: selected,
        dayExerciseIds: dayExerciseIds,
        dayIndex: dayIndex,
        role: slot.role,
        isEmphasis: true,
        dropPriority: 1,
      );
    }

    final affinity = machineAffinityFor(profile, config);
    final machinePrimaryTarget = (primarySlots.length * affinity).round();
    final machineRequirements = _machineRequirements(
      primarySlots,
      machinePrimaryTarget,
      dayExerciseIds,
    );
    for (var index = 0; index < primarySlots.length; index++) {
      final slot = primarySlots[index];
      _addSlot(
        selected: selected,
        dayExerciseIds: dayExerciseIds,
        dayIndex: dayIndex,
        role: slot.role,
        isEmphasis: slot.isEmphasis,
        dropPriority: 0,
        machineVariantRequired: machineRequirements[index],
      );
    }

    for (
      var index = isolationFirst ? 1 : 0;
      index < isolationSlots.length;
      index++
    ) {
      final slot = isolationSlots[index];
      _addSlot(
        selected: selected,
        dayExerciseIds: dayExerciseIds,
        dayIndex: dayIndex,
        role: slot.role,
        isEmphasis: slot.isEmphasis,
        dropPriority: 10 + index,
      );
    }

    return PlanDay(
      dayIndex: dayIndex,
      kind: kind,
      warmUpMinutes: profile.ageBand.isAtLeast60
          ? config.olderWarmUpMinutes
          : config.warmUpMinutes,
      hasCardioFinisher: hasCardioFinisher,
      exercises: selected,
    );
  }

  void _addSlot({
    required List<PlanExercise> selected,
    required Set<String> dayExerciseIds,
    required int dayIndex,
    required BlockRole role,
    required bool isEmphasis,
    required int dropPriority,
    bool? machineVariantRequired,
  }) {
    final pick = _pickExercise(
      dayIndex: dayIndex,
      role: role,
      dayExerciseIds: dayExerciseIds,
      machineVariantRequired: machineVariantRequired,
    );
    if (pick == null) return;
    dayExerciseIds.add(pick.exercise.id);
    _weekExerciseIds.add(pick.exercise.id);
    selected.add(
      _snapshot(
        pick.exercise,
        eligibleProfile: pick.eligibleProfile,
        isEmphasis: isEmphasis,
        dropPriority: dropPriority,
        rotationCandidateIds: pick.rotationCandidateIds,
      ),
    );
  }

  /// Chooses which primary positions carry the machine quota. Prefer the exact
  /// rounded target; if the eligible catalog cannot express it without a
  /// same-day duplicate, use the nearest feasible mix. Within that constraint,
  /// retain as many authored baseline picks as possible.
  List<bool> _machineRequirements(
    List<_Slot> slots,
    int machineTarget,
    Set<String> existingDayIds,
  ) {
    final baseline = _previewPrimaryIds(
      slots,
      List<bool?>.filled(slots.length, null),
      existingDayIds,
    );
    List<bool>? best;
    var bestDistance = slots.length + 1;
    var bestChanges = slots.length + 1;
    final patternCount = 1 << slots.length;
    for (var mask = 0; mask < patternCount; mask++) {
      final pattern = <bool>[
        for (var index = 0; index < slots.length; index++)
          mask & (1 << index) != 0,
      ];
      final preview = _previewPrimaryIds(
        slots,
        pattern.cast<bool?>(),
        existingDayIds,
      );
      if (preview == null) continue;
      final machineCount = pattern.where((value) => value).length;
      final distance = (machineCount - machineTarget).abs();
      var changes = 0;
      if (baseline != null) {
        for (var index = 0; index < preview.length; index++) {
          if (preview[index] != baseline[index]) changes++;
        }
      }
      if (best == null ||
          distance < bestDistance ||
          (distance == bestDistance && changes < bestChanges)) {
        best = pattern;
        bestDistance = distance;
        bestChanges = changes;
      }
    }
    return best ??
        <bool>[
          for (var index = 0; index < slots.length; index++)
            index < machineTarget,
        ];
  }

  List<String>? _previewPrimaryIds(
    List<_Slot> slots,
    List<bool?> requirements,
    Set<String> existingDayIds,
  ) {
    final used = <String>{...existingDayIds};
    final ids = <String>[];
    for (var index = 0; index < slots.length; index++) {
      final candidates = _orderedCandidates(slots[index].role, profile)
          .where((exercise) => !used.contains(exercise.id))
          .where(
            (exercise) =>
                requirements[index] == null ||
                exercise.machineLeanOk == requirements[index],
          )
          .toList(growable: false);
      if (candidates.isEmpty) return null;
      final rotated = _rotated(candidates, slots[index].role);
      final selected =
          rotated
              .where((exercise) => !_weekExerciseIds.contains(exercise.id))
              .firstOrNull ??
          rotated.first;
      used.add(selected.id);
      ids.add(selected.id);
    }
    return ids;
  }

  _ExercisePick? _pickExercise({
    required int dayIndex,
    required BlockRole role,
    required Set<String> dayExerciseIds,
    bool? machineVariantRequired,
  }) {
    final profiles = <({Profile profile, List<WarningCode> warningCodes})>[
      (profile: profile, warningCodes: const <WarningCode>[]),
      (
        profile: profile.copyWith(
          experienceTier: ProfileExperienceTier.trainsRegularly,
        ),
        warningCodes: const <WarningCode>[WarningCode.experienceTierRelaxed],
      ),
    ];

    for (final attempt in profiles) {
      final allCandidates = _orderedCandidates(role, attempt.profile);
      final candidates = allCandidates
          .where((exercise) => !dayExerciseIds.contains(exercise.id))
          .toList(growable: false);
      if (candidates.isEmpty) continue;

      final preferred = machineVariantRequired == null
          ? candidates
          : candidates
                .where(
                  (exercise) =>
                      exercise.machineLeanOk == machineVariantRequired,
                )
                .toList(growable: false);
      final selectionPool = preferred.isEmpty ? candidates : preferred;
      final allPreferred = machineVariantRequired == null
          ? allCandidates
          : allCandidates
                .where(
                  (exercise) =>
                      exercise.machineLeanOk == machineVariantRequired,
                )
                .toList(growable: false);
      final rotationPool = allPreferred.isEmpty ? allCandidates : allPreferred;
      final rotationCandidateIds = rotationPool
          .map((exercise) => exercise.id)
          .toList(growable: false);
      final rotated = _rotated(selectionPool, role);
      var selected = rotated
          .where((exercise) => !_weekExerciseIds.contains(exercise.id))
          .firstOrNull;
      if (selected == null) {
        selected = rotated.first;
        _addWarning(
          EngineWarning(
            WarningCode.weeklyDedupRelaxed,
            'day=$dayIndex role=${role.name}',
          ),
        );
      }
      for (final warningCode in attempt.warningCodes) {
        _addWarning(
          EngineWarning(warningCode, 'day=$dayIndex role=${role.name}'),
        );
      }
      return _ExercisePick(
        exercise: selected,
        eligibleProfile: attempt.profile,
        rotationCandidateIds: rotationCandidateIds,
      );
    }

    _addWarning(
      EngineWarning(
        WarningCode.blockDropped,
        'day=$dayIndex role=${role.name}',
      ),
    );
    return null;
  }

  List<Exercise> _orderedCandidates(BlockRole role, Profile eligibleProfile) {
    final indexed = <({Exercise exercise, int index})>[
      for (var index = 0; index < catalog.exercises.length; index++)
        if (catalog.exercises[index].blockRole == role &&
            eligible(catalog.exercises[index], eligibleProfile))
          (exercise: catalog.exercises[index], index: index),
    ];
    indexed.sort((left, right) {
      final preference = _preferenceScore(
        left.exercise,
      ).compareTo(_preferenceScore(right.exercise));
      return preference != 0 ? preference : left.index.compareTo(right.index);
    });
    return indexed.map((entry) => entry.exercise).toList(growable: false);
  }

  int _preferenceScore(Exercise exercise) {
    var score = 0;
    if (profile.ageBand.minimumAge >= config.seatedPreferenceAge &&
        !exercise.seatedVariant) {
      score += 1;
    }
    return score;
  }

  List<Exercise> _rotated(List<Exercise> candidates, BlockRole role) {
    if (!catalog.rotatingBlockRoles.contains(role) || candidates.length < 2) {
      return candidates;
    }
    final start = (profile.mesocycleIndex - 1) % candidates.length;
    return <Exercise>[
      for (var offset = 0; offset < candidates.length; offset++)
        candidates[(start + offset) % candidates.length],
    ];
  }

  PlanExercise _snapshot(
    Exercise exercise, {
    required Profile eligibleProfile,
    required bool isEmphasis,
    required int dropPriority,
    required List<String> rotationCandidateIds,
  }) {
    final scheme = config.schemeFor(
      profile.goal,
      weeksTrained: profile.weeksTrained,
    );
    final doses = _dosesFor(exercise, scheme, isEmphasis: isEmphasis);
    final range = exercise.metricType == MetricType.timed
        ? null
        : config.rangeFor(exercise, scheme);
    final rotatesAcrossMesocycles =
        catalog.rotatingBlockRoles.contains(exercise.blockRole) &&
        rotationCandidateIds.length >= 2;
    return PlanExercise(
      exerciseId: exercise.id,
      name: exercise.name,
      blockRole: exercise.blockRole,
      movementClass: exercise.movementClass,
      metricType: exercise.metricType,
      laterality: exercise.laterality,
      difficultyTier: exercise.difficultyTier,
      resistanceEquipment: exercise.resistanceEquipment,
      supportEquipment: exercise.supportEquipment,
      bwContribution: exercise.bwContribution,
      loadStepOverride: exercise.loadStepOverride,
      dropPriority: dropPriority,
      isEmphasis: isEmphasis,
      rotatesAcrossMesocycles: rotatesAcrossMesocycles,
      rotationCandidateIds: rotationCandidateIds,
      orderedSwapCandidates: _swapCandidates(
        exercise,
        scheme,
        eligibleProfile,
        isEmphasis: isEmphasis,
      ),
      doseByWeekKind: doses,
      repRange: range,
    );
  }

  Map<MesocycleWeekKind, Dose> _dosesFor(
    Exercise exercise,
    RepScheme scheme, {
    required bool isEmphasis,
  }) {
    final baseSets =
        scheme.maxSets + (isEmphasis && scheme.extraSetOnEmphasis ? 1 : 0);
    final easierSets = (baseSets + config.easierWeekSetsDelta).clamp(
      1,
      baseSets,
    );
    if (exercise.metricType == MetricType.timed) {
      return <MesocycleWeekKind, Dose>{
        MesocycleWeekKind.build: TimedDose(
          sets: baseSets,
          hold: config.timedHoldFloor,
        ),
        MesocycleWeekKind.easier: TimedDose(
          sets: easierSets,
          hold: config.timedHoldFloor,
        ),
        MesocycleWeekKind.push: TimedDose(
          sets: baseSets,
          hold: config.timedHoldFloor,
        ),
        MesocycleWeekKind.deload: TimedDose(
          sets: easierSets,
          hold: config.timedHoldFloor,
        ),
      };
    }

    final range = config.rangeFor(exercise, scheme);
    RepsDose dose(int sets, EffortTarget effort) => RepsDose(
      sets: sets,
      range: range,
      effort: effort,
      targetReps: range.min,
    );
    return <MesocycleWeekKind, Dose>{
      MesocycleWeekKind.build: dose(baseSets, scheme.effort),
      MesocycleWeekKind.easier: dose(
        easierSets,
        scheme.effort.easierBy(config.easierWeekRpeDelta.abs()),
      ),
      MesocycleWeekKind.push: dose(baseSets, scheme.effort),
      MesocycleWeekKind.deload: dose(
        baseSets,
        scheme.effort.easierBy(config.deloadWeekRpeDelta.abs()),
      ),
    };
  }

  List<PlanSwapCandidate> _swapCandidates(
    Exercise from,
    RepScheme scheme,
    Profile eligibleProfile, {
    required bool isEmphasis,
  }) {
    final result = <PlanSwapCandidate>[];
    final edges =
        catalog.swapEdges
            .where((edge) => edge.fromId == from.id)
            .toList(growable: false)
          ..sort((left, right) {
            final tier = left.tier.compareTo(right.tier);
            if (tier != 0) return tier;
            final rank = left.rank.compareTo(right.rank);
            if (rank != 0) return rank;
            return left.toId.compareTo(right.toId);
          });
    final included = <String>{};
    for (final edge in edges) {
      final target = exercisesById[edge.toId];
      if (target == null || target.isRetired) {
        _addWarning(
          EngineWarning(
            WarningCode.danglingSwapSkipped,
            '${edge.fromId}->${edge.toId}/tier${edge.tier}',
          ),
        );
        continue;
      }
      if (!_swapCompatible(from, target)) {
        _addWarning(
          EngineWarning(
            WarningCode.invalidSwapSkipped,
            '${edge.fromId}->${edge.toId}/tier${edge.tier}',
          ),
        );
        continue;
      }
      if (eligible(target, eligibleProfile) && included.add(target.id)) {
        result.add(
          PlanSwapCandidate(
            exerciseId: target.id,
            name: target.name,
            blockRole: target.blockRole,
            movementClass: target.movementClass,
            metricType: target.metricType,
            laterality: target.laterality,
            difficultyTier: target.difficultyTier,
            resistanceEquipment: target.resistanceEquipment,
            supportEquipment: target.supportEquipment,
            bwContribution: target.bwContribution,
            loadStepOverride: target.loadStepOverride,
            tier: edge.tier,
            rank: edge.rank,
            doseByWeekKind: _dosesFor(target, scheme, isEmphasis: isEmphasis),
            repRange: target.metricType == MetricType.timed
                ? null
                : config.rangeFor(target, scheme),
          ),
        );
      }
    }

    // Total fallback: same authored block role preserves the movement
    // complexion, so it is a shown-by-default tier-2 alternative. It is
    // resolved into the plan so mid-session swaps stay offline even if the
    // content tables later change.
    var fallbackRank = result
        .where((candidate) => candidate.tier == 2)
        .fold<int>(
          -1,
          (rank, candidate) => candidate.rank > rank ? candidate.rank : rank,
        );
    fallbackRank++;
    for (final target in _orderedCandidates(from.blockRole, eligibleProfile)) {
      if (target.id == from.id ||
          included.contains(target.id) ||
          !_swapCompatible(from, target)) {
        continue;
      }
      included.add(target.id);
      result.add(
        PlanSwapCandidate(
          exerciseId: target.id,
          name: target.name,
          blockRole: target.blockRole,
          movementClass: target.movementClass,
          metricType: target.metricType,
          laterality: target.laterality,
          difficultyTier: target.difficultyTier,
          resistanceEquipment: target.resistanceEquipment,
          supportEquipment: target.supportEquipment,
          bwContribution: target.bwContribution,
          loadStepOverride: target.loadStepOverride,
          tier: 2,
          rank: fallbackRank++,
          doseByWeekKind: _dosesFor(target, scheme, isEmphasis: isEmphasis),
          repRange: target.metricType == MetricType.timed
              ? null
              : config.rangeFor(target, scheme),
        ),
      );
    }
    result.sort((left, right) {
      final tier = left.tier.compareTo(right.tier);
      if (tier != 0) return tier;
      final rank = left.rank.compareTo(right.rank);
      if (rank != 0) return rank;
      return left.exerciseId.compareTo(right.exerciseId);
    });
    return result;
  }

  bool _swapCompatible(Exercise from, Exercise to) {
    return from.blockRole.swapRegionPurpose == to.blockRole.swapRegionPurpose;
  }

  BlockRole? _emphasisRole(PlanDayKind kind) {
    if (kind == PlanDayKind.lowerGluteLed) return BlockRole.gluteIsolation;
    final isLower =
        kind == PlanDayKind.lower || kind == PlanDayKind.lowerGluteLed;
    final isUpper = kind == PlanDayKind.upper;
    final isFullBody =
        kind == PlanDayKind.fullBodyA || kind == PlanDayKind.fullBodyB;
    return switch (profile.emphasis) {
      Emphasis.glutes when isLower || isFullBody => BlockRole.gluteIsolation,
      Emphasis.legs when isLower || isFullBody => BlockRole.legIsolation,
      Emphasis.back when isUpper || isFullBody => BlockRole.upperPull,
      Emphasis.arms when isUpper || isFullBody =>
        BlockRole.armShoulderIsolation,
      Emphasis.core => BlockRole.core,
      Emphasis.balanced => null,
      _ => null,
    };
  }

  List<BlockRole> _primaryRoles(PlanDayKind kind) => switch (kind) {
    PlanDayKind.lower || PlanDayKind.lowerGluteLed => const [
      BlockRole.lowerSquat,
      BlockRole.lowerHinge,
      BlockRole.lowerSquat,
    ],
    PlanDayKind.upper => const [
      BlockRole.upperPush,
      BlockRole.upperPull,
      BlockRole.upperPush,
    ],
    PlanDayKind.fullBodyA => const [
      BlockRole.lowerSquat,
      BlockRole.upperPull,
      BlockRole.upperPush,
    ],
    PlanDayKind.fullBodyB => const [
      BlockRole.lowerHinge,
      BlockRole.upperPush,
      BlockRole.upperPull,
    ],
  };

  List<_Slot> _primarySlots(
    PlanDayKind kind,
    BlockRole? emphasisRole,
    int count,
  ) => _slotsWithEmphasis(
    _primaryRoles(kind),
    emphasisRole?.isPrimary ?? false ? emphasisRole : null,
    count,
  );

  List<_Slot> _isolationSlots(
    PlanDayKind kind,
    BlockRole? emphasisRole,
    int count,
  ) {
    final base = switch (kind) {
      PlanDayKind.lower || PlanDayKind.lowerGluteLed => const [
        BlockRole.legIsolation,
        BlockRole.gluteIsolation,
        BlockRole.core,
        BlockRole.legIsolation,
        BlockRole.gluteIsolation,
      ],
      PlanDayKind.upper => const [
        BlockRole.armShoulderIsolation,
        BlockRole.core,
        BlockRole.armShoulderIsolation,
        BlockRole.core,
        BlockRole.gluteIsolation,
      ],
      PlanDayKind.fullBodyA || PlanDayKind.fullBodyB => const [
        BlockRole.gluteIsolation,
        BlockRole.armShoulderIsolation,
        BlockRole.legIsolation,
        BlockRole.core,
        BlockRole.gluteIsolation,
      ],
    };
    final slots = _slotsWithEmphasis(
      base,
      emphasisRole != null && !emphasisRole.isPrimary ? emphasisRole : null,
      count,
    );
    final gluteIndex = slots.indexWhere(
      (slot) => slot.isEmphasis && slot.role == BlockRole.gluteIsolation,
    );
    if (gluteIndex <= 0) return slots;
    return <_Slot>[
      slots[gluteIndex],
      ...slots.take(gluteIndex),
      ...slots.skip(gluteIndex + 1),
    ];
  }

  void _addWarning(EngineWarning warning) {
    if (!warnings.contains(warning)) warnings.add(warning);
  }
}

final class _ExercisePick {
  const _ExercisePick({
    required this.exercise,
    required this.eligibleProfile,
    required this.rotationCandidateIds,
  });

  final Exercise exercise;
  final Profile eligibleProfile;
  final List<String> rotationCandidateIds;
}

typedef _Slot = ({BlockRole role, bool isEmphasis});

List<_Slot> _slotsWithEmphasis(
  List<BlockRole> base,
  BlockRole? emphasisRole,
  int count,
) {
  final roles = base.take(count).toList(growable: false);
  final slots = <_Slot>[
    for (final role in roles) (role: role, isEmphasis: false),
  ];
  if (emphasisRole == null || slots.isEmpty) return slots;

  var replacement = -1;
  for (var index = slots.length - 1; index >= 0; index--) {
    if (slots[index].role != emphasisRole) {
      replacement = index;
      break;
    }
  }
  if (replacement < 0) replacement = slots.length - 1;
  slots[replacement] = (role: emphasisRole, isEmphasis: true);
  return slots;
}

String _stableHash(String input) {
  // A small 31-bit polynomial hash: deterministic on Dart VM and JavaScript,
  // dependency-free, and explicitly not intended for cryptographic integrity.
  var hash = 0;
  for (final codeUnit in input.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x7fffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _profileCanonical(Profile profile) => <String>[
  profile.ageBand.name,
  profile.daysPerWeek.name,
  profile.sessionMinutes.name,
  profile.goal.name,
  profile.emphasis.name,
  profile.experienceTier.name,
  profile.gymComfort.name,
  '${profile.weeksTrained}',
  '${profile.mesocycleIndex}',
  // Collected activity answers are deliberately absent: they do not change any
  // v1 plan bytes, including the profile stamp (persona 9's twin invariant).
].join('|');

String _configCanonical(ProgrammingConfig config) {
  final parts = <String>[
    for (final goal in Goal.values)
      _schemeCanonical(goal, config.repSchemes[goal]),
    '${config.isolationRange}',
    '${config.isolationRestartRange}',
    '${config.dropBridgeBackOffReps}',
    '${config.noviceWeeks}',
    '${config.noviceMaxSets}',
    '${config.noviceMaxRpe}',
    _loadTableCanonical(config.metricLoads),
    _loadTableCanonical(config.imperialLoads),
    '${config.mesocycleWeeks}',
    '${config.easierWeekIndex}',
    '${config.deloadWeekIndex}',
    '${config.easierWeekSetsDelta}',
    '${config.easierWeekRpeDelta}',
    '${config.deloadWeekRpeDelta}',
    '${config.deloadWeekLoadFraction}',
    '${config.newMesocycleStepUp}',
    '${config.layoffTier1Days}',
    '${config.layoffTier2Days}',
    '${config.layoffTier3Days}',
    '${config.layoffTier2LoadFraction}',
    '${config.layoffTier3LoadFraction}',
    '${config.calibrationProbeReps}',
    '${config.calibrationMaxTestSets}',
    '${config.calibrationProbeStepJump}',
    '${config.lowerBodyMachineProbeJumpMin}',
    '${config.lowerBodyMachineProbeJumpMax}',
    '${config.calibrationMinCleanReps}',
    '${config.calibrationRegimeMaxRpe}',
    '${config.calibrationMaxIncreaseFraction}',
    '${config.calibrationMaxSteps}',
    '${config.maxChangeFraction}',
    '${config.maxStepsPerAdjustment}',
    '${config.deadbandFraction}',
    '${config.maxInterpretedRir}',
    '${config.loadFractionPerRep}',
    '${config.minIncrementStepFraction}',
    '${config.epleyConstant}',
    '${config.stallSessions}',
    '${config.stallDeloadFraction}',
    '${config.missedBottomDropFraction}',
    '${config.lowEnergyLoadFraction}',
    '${config.timedHoldFloor.inMicroseconds}',
    '${config.timedHoldStep.inMicroseconds}',
    '${config.timedHoldCeiling.inMicroseconds}',
    '${config.bodyweightRepStep}',
    for (final minutes in (config.exerciseCountByMinutes.keys.toList()..sort()))
      '$minutes:${config.exerciseCountByMinutes[minutes]}',
    '${config.warmUpMinutes}',
    '${config.olderWarmUpMinutes}',
    '${config.machineAffinityNewToIt}',
    '${config.machineAffinityBeenAWhile}',
    '${config.machineAffinityTrainsRegularly}',
    '${config.machineAffinityAge50To59}',
    '${config.machineAffinityAge60Plus}',
    '${config.machineAffinityLowComfort}',
    '${config.machineAffinityMostlyFineComfort}',
    '${config.machineAffinityTotallyAtHomeComfort}',
    '${config.machineAffinityForcedAge}',
    '${config.seatedPreferenceAge}',
    for (final level in EffortLevel.values)
      '${level.name}:${config.reportedRpeByLevel[level]}:'
          '${config.rpeBandByLevel[level]}',
  ];
  return parts.join('|');
}

String _schemeCanonical(Goal goal, RepScheme? scheme) => scheme == null
    ? '${goal.name}:missing'
    : '${goal.name}:${scheme.minSets}:${scheme.maxSets}:${scheme.range}:'
          '${scheme.effort.rpe}:${scheme.rest.inMicroseconds}:'
          '${scheme.extraSetOnEmphasis}';

String _loadTableCanonical(EquipmentLoadTable table) => <double>[
  table.barbellBar.value,
  table.barbellUpperStep.value,
  table.barbellLowerStep.value,
  table.dumbbellFloor.value,
  table.dumbbellStep.value,
  table.machineFloor.value,
  table.machineStep.value,
  table.assistedStackMaxAssistance.value,
  table.assistedStackStep.value,
  table.cableFloor.value,
  table.cableStep.value,
  table.addedLoadStep.value,
].join(',');

String _contentCanonical(ContentCatalog catalog) {
  final parts = <String>[catalog.contentVersion];
  for (final exercise in catalog.exercises) {
    parts.addAll(<String>[
      exercise.id,
      exercise.slug,
      exercise.name,
      exercise.blockRole.name,
      exercise.movementClass.name,
      exercise.metricType.name,
      exercise.laterality.name,
      '${exercise.bwContribution}',
      exercise.resistanceEquipment.name,
      exercise.supportEquipment.name,
      exercise.targetMuscles.join(','),
      exercise.primaryJointActions.map((action) => action.name).join(','),
      exercise.secondaryJointActions.map((action) => action.name).join(','),
      '${exercise.romRank}',
      '${exercise.stabilityRank}',
      exercise.difficultyTier.name,
      exercise.minExperience.name,
      exercise.intimidationTier.name,
      exercise.ageEligibility.name,
      exercise.safetyEligibility.name,
      '${exercise.machineLeanOk}',
      '${exercise.seatedVariant}',
      exercise.loadStepOverride?.value.toString() ?? 'null',
      exercise.retiredAt?.toUtc().toIso8601String() ?? 'active',
      exercise.setupSteps.join('\u001f'),
      exercise.shouldFeel,
      exercise.stopIf,
      exercise.findIt,
      exercise.dos.join('\u001f'),
      exercise.donts.join('\u001f'),
    ]);
  }
  for (final edge in catalog.swapEdges) {
    parts.add('${edge.fromId}:${edge.toId}:tier${edge.tier}:${edge.rank}');
  }
  for (final role in BlockRole.values) {
    if (catalog.rotatingBlockRoles.contains(role)) {
      parts.add('rotate:${role.name}');
    }
  }
  return parts.join('|');
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
