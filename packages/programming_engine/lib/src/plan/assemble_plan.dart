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

/// §8's DRAFT additive machine-affinity score, clamped to [0, 1].
double machineAffinityFor(Profile profile, ProgrammingConfig config) {
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
  config.assertParametricConfiguration();
  assert(
    config.warmUpMinutesByAgeBand.length == AgeBand.values.length,
    'warm-up table must contain one value per age band',
  );
  // Decided 2026-07-25: otherActivities is stored and stamped, but deliberately
  // does not affect selection. The quiz lacks activity-day placement, so changing
  // volume or plan days from this answer would be guesswork.

  final minutes = profile.sessionMinutes.value;
  final configuredCount = config.exerciseCountByMinutes[minutes];
  assert(
    configuredCount != null,
    'missing exercise count for $minutes-minute sessions',
  );

  final hasCardioFinisher = profile.sessionMinutes == SessionMinutes.sixty;
  final primaryCount = profile.sessionMinutes == SessionMinutes.thirty ? 2 : 3;
  final catalogExerciseCount = configuredCount! - (hasCardioFinisher ? 1 : 0);
  final isolationCount = catalogExerciseCount - primaryCount;
  assert(
    isolationCount >= 1,
    '$minutes-minute sessions need $primaryCount primaries and an isolation',
  );

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

  if (days.any((day) => day.exercises.isEmpty)) {
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
        machinePreference: machineRequirements[index],
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
      warmUpMinutes: config.warmUpMinutesByAgeBand[profile.ageBand.index],
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
    bool? machinePreference,
  }) {
    final pick = _pickExercise(
      dayIndex: dayIndex,
      role: role,
      dayExerciseIds: dayExerciseIds,
      machinePreference: machinePreference,
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

  /// Converts the scalar affinity into a deterministic daily target. This is
  /// planning data for the common candidate scorer, not a population-specific
  /// exercise-selection path.
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
    bool? machinePreference,
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
      final allCandidates = _orderedCandidates(
        role,
        attempt.profile,
        machinePreference: machinePreference,
      );
      final candidates = allCandidates
          .where((exercise) => !dayExerciseIds.contains(exercise.id))
          .toList(growable: false);
      if (candidates.isEmpty) continue;

      final preferredRotation = machinePreference == null
          ? allCandidates
          : allCandidates
                .where(
                  (exercise) => exercise.machineLeanOk == machinePreference,
                )
                .toList(growable: false);
      final rotationPool = preferredRotation.isEmpty
          ? allCandidates
          : preferredRotation;
      final rotationCandidateIds = rotationPool
          .map((exercise) => exercise.id)
          .toList(growable: false);
      final selectionPool = machinePreference == null
          ? candidates
          : candidates
                .where(
                  (exercise) => exercise.machineLeanOk == machinePreference,
                )
                .toList(growable: false);
      final rotated = _rotated(
        selectionPool.isEmpty ? candidates : selectionPool,
        role,
      );
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

  List<Exercise> _orderedCandidates(
    BlockRole role,
    Profile eligibleProfile, {
    bool? machinePreference,
  }) {
    final indexed = <({Exercise exercise, int rank})>[];
    for (final exercise in catalog.exercises) {
      if (exercise.blockRole == role && eligible(exercise, eligibleProfile)) {
        indexed.add((exercise: exercise, rank: indexed.length));
      }
    }
    final candidateCount = indexed.length;
    indexed.sort((left, right) {
      final preference =
          _preferenceScore(
            left.exercise,
            authoredRank: left.rank,
            candidateCount: candidateCount,
            machinePreference: machinePreference,
          ).compareTo(
            _preferenceScore(
              right.exercise,
              authoredRank: right.rank,
              candidateCount: candidateCount,
              machinePreference: machinePreference,
            ),
          );
      return preference != 0 ? preference : left.rank.compareTo(right.rank);
    });
    return indexed.map((entry) => entry.exercise).toList(growable: false);
  }

  double _preferenceScore(
    Exercise exercise, {
    required int authoredRank,
    required int candidateCount,
    required bool? machinePreference,
  }) {
    final machineFeature =
        exercise.blockRole.isPrimary && exercise.machineLeanOk ? 1.0 : 0.0;
    final seatedFeature = exercise.seatedVariant ? 1.0 : 0.0;
    final seatedAgeScale =
        ((profile.ageBand.minimumAge - config.seatedPreferenceStartAge) /
                (config.seatedPreferenceFullAge -
                    config.seatedPreferenceStartAge))
            .clamp(0.0, 1.0);
    final desiredMachine = machinePreference == null
        ? machineFeature
        : machinePreference
        ? 1.0
        : 0.0;
    final machineMismatch = (machineFeature - desiredMachine).abs();
    final machinePenalty =
        machineMismatch *
        candidateCount *
        (1 + machineAffinityFor(profile, config));
    final seatedBonus =
        seatedFeature *
        config.seatedPreferenceWeight *
        seatedAgeScale *
        candidateCount;
    return authoredRank + machinePenalty - seatedBonus;
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
    final baseDose = _baseDoseFor(exercise, scheme, isEmphasis: isEmphasis);
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
      baseDose: baseDose,
      repRange: range,
    );
  }

  Dose _baseDoseFor(
    Exercise exercise,
    RepScheme scheme, {
    required bool isEmphasis,
  }) {
    final baseSets =
        scheme.maxSets + (isEmphasis && scheme.extraSetOnEmphasis ? 1 : 0);
    if (exercise.metricType == MetricType.timed) {
      config.assertTimedDoseConfiguration();
      return TimedDose(sets: baseSets, hold: config.timedHoldFloor);
    }

    final range = config.rangeFor(exercise, scheme);
    return RepsDose(
      sets: baseSets,
      range: range,
      effort: scheme.effort,
      targetReps: range.min,
    );
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
      assert(
        target != null && !target.isRetired,
        'swap ${edge.fromId}->${edge.toId} must target an active exercise',
      );
      assert(
        _swapCompatible(from, target!),
        'swap ${edge.fromId}->${edge.toId} crosses session purpose',
      );
      final resolvedTarget = target!;
      if (eligible(resolvedTarget, eligibleProfile) &&
          included.add(resolvedTarget.id)) {
        result.add(
          PlanSwapCandidate(
            exerciseId: resolvedTarget.id,
            name: resolvedTarget.name,
            blockRole: resolvedTarget.blockRole,
            movementClass: resolvedTarget.movementClass,
            metricType: resolvedTarget.metricType,
            laterality: resolvedTarget.laterality,
            difficultyTier: resolvedTarget.difficultyTier,
            resistanceEquipment: resolvedTarget.resistanceEquipment,
            supportEquipment: resolvedTarget.supportEquipment,
            bwContribution: resolvedTarget.bwContribution,
            loadStepOverride: resolvedTarget.loadStepOverride,
            tier: edge.tier,
            rank: edge.rank,
            baseDose: _baseDoseFor(
              resolvedTarget,
              scheme,
              isEmphasis: isEmphasis,
            ),
            repRange: resolvedTarget.metricType == MetricType.timed
                ? null
                : config.rangeFor(resolvedTarget, scheme),
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
          baseDose: _baseDoseFor(target, scheme, isEmphasis: isEmphasis),
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
    '${config.rpeRampBase}',
    '${config.rpeRampPerWeek}',
    '${config.setsRampBase}',
    '${config.setsRampPerWeek}',
    _loadTableCanonical(config.metricLoads),
    _loadTableCanonical(config.imperialLoads),
    '${config.mesocycleWeeks}',
    config.weekSetsDelta.join(','),
    config.weekRpeDelta.join(','),
    config.weekLoadScale.join(','),
    '${config.newMesocycleStepUp}',
    '${config.layoffGraceDays}',
    '${config.layoffSlopePerDay}',
    '${config.layoffFloor}',
    '${config.calibrationProbeReps}',
    '${config.calibrationMaxTestSets}',
    '${config.calibrationJumpFraction}',
    for (final movementClass in MovementClass.values)
      '${movementClass.name}:'
          '${config.probeLoadFractionByMovementClass[movementClass]}',
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
    config.warmUpMinutesByAgeBand.join(','),
    '${config.machineAffinityNewToIt}',
    '${config.machineAffinityBeenAWhile}',
    '${config.machineAffinityTrainsRegularly}',
    '${config.machineAffinityAge50To59}',
    '${config.machineAffinityAge60Plus}',
    '${config.machineAffinityLowComfort}',
    '${config.machineAffinityMostlyFineComfort}',
    '${config.machineAffinityTotallyAtHomeComfort}',
    '${config.seatedPreferenceWeight}',
    '${config.seatedPreferenceStartAge}',
    '${config.seatedPreferenceFullAge}',
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
