/// Deterministic plan-time assembly (`ENGINE.md` build-order step 4).
library;

import '../config/equipment_loads.dart';
import '../config/programming_config.dart';
import '../content/exercise.dart';
import '../core/dose.dart';
import '../core/effort.dart';
import '../core/events.dart';
import '../core/warnings.dart';
import '../profile/profile.dart';
import 'eligibility.dart';
import 'plan.dart';
import 'result.dart';

const String currentEngineVersion = '1.0.0-plan-step-4';

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

    if (emphasisRole != null) {
      _addSlot(
        selected: selected,
        dayExerciseIds: dayExerciseIds,
        dayIndex: dayIndex,
        role: emphasisRole,
        isEmphasis: true,
        dropPriority: emphasisRole.isPrimary ? 0 : 1,
      );
    }

    final primaryRoles = _primaryRoles(kind);
    final earlyPrimaryCount = emphasisRole?.isPrimary ?? false ? 1 : 0;
    final remainingPrimaries = primaryCount - earlyPrimaryCount;
    for (
      var index = 0;
      index < remainingPrimaries && index < primaryRoles.length;
      index++
    ) {
      _addSlot(
        selected: selected,
        dayExerciseIds: dayExerciseIds,
        dayIndex: dayIndex,
        role: primaryRoles[index],
        isEmphasis: false,
        dropPriority: 0,
      );
    }

    final earlyIsolationCount = emphasisRole != null && !emphasisRole.isPrimary
        ? 1
        : 0;
    final remainingIsolations = isolationCount - earlyIsolationCount;
    final isolationRoles = _isolationRoles(kind, emphasisRole);
    for (
      var index = 0;
      index < remainingIsolations && index < isolationRoles.length;
      index++
    ) {
      _addSlot(
        selected: selected,
        dayExerciseIds: dayExerciseIds,
        dayIndex: dayIndex,
        role: isolationRoles[index],
        isEmphasis: false,
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
  }) {
    final pick = _pickExercise(
      dayIndex: dayIndex,
      role: role,
      dayExerciseIds: dayExerciseIds,
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

  _ExercisePick? _pickExercise({
    required int dayIndex,
    required BlockRole role,
    required Set<String> dayExerciseIds,
  }) {
    final profiles = <({Profile profile, List<WarningCode> warningCodes})>[
      (profile: profile, warningCodes: const <WarningCode>[]),
      (
        profile: profile.copyWith(gymComfort: GymComfort.totallyAtHome),
        warningCodes: const <WarningCode>[WarningCode.gymComfortRelaxed],
      ),
      (
        profile: profile.copyWith(
          gymComfort: GymComfort.totallyAtHome,
          experienceTier: ProfileExperienceTier.trainsRegularly,
        ),
        warningCodes: const <WarningCode>[
          WarningCode.gymComfortRelaxed,
          WarningCode.experienceTierRelaxed,
        ],
      ),
    ];

    for (final attempt in profiles) {
      final allCandidates = _orderedCandidates(role, attempt.profile);
      final candidates = allCandidates
          .where((exercise) => !dayExerciseIds.contains(exercise.id))
          .toList(growable: false);
      if (candidates.isEmpty) continue;

      final rotationCandidateIds = allCandidates
          .map((exercise) => exercise.id)
          .toList(growable: false);
      final rotated = _rotated(candidates, role);
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
    final olderNovice =
        profile.ageBand.minimumAge >= config.machineLeanAge &&
        profile.experienceTier == ProfileExperienceTier.newToIt;
    if (olderNovice && !exercise.machineLeanOk) score += 2;
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
      rotatesAcrossMesocycles: catalog.rotatingBlockRoles.contains(
        exercise.blockRole,
      ),
      rotationCandidateIds: rotationCandidateIds,
      orderedSwapCandidates: _swapCandidates(exercise, scheme, eligibleProfile),
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
    Profile eligibleProfile,
  ) {
    final result = <PlanSwapCandidate>[];
    for (final reason in SwapReason.values) {
      final edges =
          catalog.swapEdges
              .where((edge) => edge.fromId == from.id && edge.reason == reason)
              .toList(growable: false)
            ..sort((left, right) => left.rank.compareTo(right.rank));
      final included = <String>{};
      var fallbackRank = edges.isEmpty ? 0 : edges.last.rank + 1;
      for (final edge in edges) {
        final target = exercisesById[edge.toId];
        if (target == null || target.isRetired) {
          _addWarning(
            EngineWarning(
              WarningCode.danglingSwapSkipped,
              '${edge.fromId}->${edge.toId}/${reason.name}',
            ),
          );
          continue;
        }
        if (!_swapCompatible(from, target, scheme)) {
          _addWarning(
            EngineWarning(
              WarningCode.invalidSwapSkipped,
              '${edge.fromId}->${edge.toId}/${reason.name}',
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
              reason: reason,
              rank: edge.rank,
            ),
          );
        }
      }

      for (final target in _orderedCandidates(
        from.blockRole,
        eligibleProfile,
      )) {
        if (target.id == from.id ||
            included.contains(target.id) ||
            !_swapCompatible(from, target, scheme)) {
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
            reason: reason,
            rank: fallbackRank++,
          ),
        );
      }
    }
    return result;
  }

  bool _swapCompatible(Exercise from, Exercise to, RepScheme scheme) {
    if (from.blockRole != to.blockRole ||
        from.difficultyTier != to.difficultyTier) {
      return false;
    }
    if (from.metricType == MetricType.timed ||
        to.metricType == MetricType.timed) {
      return from.metricType == to.metricType;
    }
    return config.rangeFor(from, scheme) == config.rangeFor(to, scheme);
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
      Emphasis.none || Emphasis.balanced => null,
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

  List<BlockRole> _isolationRoles(PlanDayKind kind, BlockRole? emphasisRole) {
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
    if (emphasisRole == null || emphasisRole.isPrimary) return base;
    return <BlockRole>[
      emphasisRole,
      ...base.where((role) => role != emphasisRole),
      ...base.where((role) => role == emphasisRole),
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
    '${config.machineLeanAge}',
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
    parts.add('${edge.fromId}:${edge.toId}:${edge.reason.name}:${edge.rank}');
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
