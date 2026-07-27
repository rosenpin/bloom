import 'dart:convert';

import 'package:programming_engine/programming_engine.dart' as engine;

/// JSON persistence for the engine's self-contained plan document.
///
/// The engine deliberately has no serialization dependency. Keeping this codec
/// in the app layer preserves that purity while storing every resolved exercise,
/// swap, dose, warning, and replay stamp needed to train offline.
abstract final class PlanCodec {
  static String encode(engine.Plan plan) => jsonEncode(<String, Object?>{
    'schemaVersion': 2,
    'mesocycleIndex': plan.mesocycleIndex,
    'stamps': <String, Object?>{
      'engineVersion': plan.stamps.engineVersion,
      'configHash': plan.stamps.configHash,
      'contentHash': plan.stamps.contentHash,
      'profileHash': plan.stamps.profileHash,
    },
    'mesocycleCalendar': [
      for (final week in plan.mesocycleCalendar)
        <String, Object?>{'weekIndex': week.weekIndex, 'kind': week.kind.name},
    ],
    'days': [for (final day in plan.days) _encodeDay(day)],
    'warnings': [
      for (final warning in plan.warnings)
        <String, Object?>{'code': warning.code.name, 'detail': warning.detail},
    ],
    'editStamps': [
      for (final stamp in plan.editStamps)
        <String, Object?>{
          'engineVersion': stamp.engineVersion,
          'configHash': stamp.configHash,
          'contentHash': stamp.contentHash,
          'editId': stamp.editId,
        },
    ],
  });

  static engine.Plan decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final stamps = json['stamps']! as Map<String, Object?>;
    return engine.Plan(
      mesocycleIndex: _integer(json['mesocycleIndex']),
      stamps: engine.PlanStamps(
        engineVersion: stamps['engineVersion']! as String,
        configHash: stamps['configHash']! as String,
        contentHash: stamps['contentHash']! as String,
        profileHash: stamps['profileHash']! as String,
      ),
      mesocycleCalendar: [
        for (final raw in json['mesocycleCalendar']! as List<Object?>)
          if (raw case final Map<String, Object?> week)
            engine.PlanWeek(
              weekIndex: _integer(week['weekIndex']),
              kind: _enum(engine.MesocycleWeekKind.values, week['kind']),
            ),
      ],
      days: [
        for (final raw in json['days']! as List<Object?>)
          if (raw case final Map<String, Object?> day) _decodeDay(day),
      ],
      warnings: [
        for (final raw in json['warnings']! as List<Object?>)
          if (raw case final Map<String, Object?> warning)
            engine.EngineWarning(
              _enum(engine.WarningCode.values, warning['code']),
              warning['detail']! as String,
            ),
      ],
      editStamps: [
        for (final raw in json['editStamps']! as List<Object?>)
          if (raw case final Map<String, Object?> stamp)
            engine.PlanEditStamp(
              engineVersion: stamp['engineVersion']! as String,
              configHash: stamp['configHash']! as String,
              contentHash: stamp['contentHash']! as String,
              editId: stamp['editId']! as String,
            ),
      ],
    );
  }

  static Map<String, Object?> _encodeDay(engine.PlanDay day) =>
      <String, Object?>{
        'dayIndex': day.dayIndex,
        'kind': day.kind.name,
        'warmUpMinutes': day.warmUpMinutes,
        'hasCardioFinisher': day.hasCardioFinisher,
        'exercises': [
          for (final exercise in day.exercises) _encodeExercise(exercise),
        ],
      };

  static engine.PlanDay _decodeDay(Map<String, Object?> json) => engine.PlanDay(
    dayIndex: _integer(json['dayIndex']),
    kind: _enum(engine.PlanDayKind.values, json['kind']),
    warmUpMinutes: _integer(json['warmUpMinutes']),
    hasCardioFinisher: json['hasCardioFinisher']! as bool,
    exercises: [
      for (final raw in json['exercises']! as List<Object?>)
        if (raw case final Map<String, Object?> exercise)
          _decodeExercise(exercise),
    ],
  );

  static Map<String, Object?> _encodeExercise(engine.PlanExercise exercise) =>
      <String, Object?>{
        ..._encodeLoadProfile(
          exerciseId: exercise.exerciseId,
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
          repRange: exercise.repRange,
        ),
        'dropPriority': exercise.dropPriority,
        'isEmphasis': exercise.isEmphasis,
        'rotatesAcrossMesocycles': exercise.rotatesAcrossMesocycles,
        'rotationCandidateIds': exercise.rotationCandidateIds,
        'orderedSwapCandidates': [
          for (final swap in exercise.orderedSwapCandidates) _encodeSwap(swap),
        ],
        'baseDose': _encodeDose(exercise.baseDose),
      };

  static engine.PlanExercise _decodeExercise(Map<String, Object?> json) {
    return engine.PlanExercise(
      exerciseId: json['exerciseId']! as String,
      name: json['name']! as String,
      blockRole: _enum(engine.BlockRole.values, json['blockRole']),
      movementClass: _enum(engine.MovementClass.values, json['movementClass']),
      metricType: _enum(engine.MetricType.values, json['metricType']),
      laterality: _enum(engine.Laterality.values, json['laterality']),
      difficultyTier: _enum(
        engine.DifficultyTier.values,
        json['difficultyTier'],
      ),
      resistanceEquipment: _enum(
        engine.ResistanceEquipment.values,
        json['resistanceEquipment'],
      ),
      supportEquipment: _enum(
        engine.SupportEquipment.values,
        json['supportEquipment'],
      ),
      bwContribution: _number(json['bwContribution']),
      loadStepOverride: _kilogramsOrNull(json['loadStepOverrideKg']),
      dropPriority: _integer(json['dropPriority']),
      isEmphasis: json['isEmphasis']! as bool,
      rotatesAcrossMesocycles: json['rotatesAcrossMesocycles']! as bool,
      rotationCandidateIds: [
        for (final id in json['rotationCandidateIds']! as List<Object?>)
          id! as String,
      ],
      orderedSwapCandidates: [
        for (final raw in json['orderedSwapCandidates']! as List<Object?>)
          if (raw case final Map<String, Object?> swap) _decodeSwap(swap),
      ],
      baseDose: _decodeBaseDose(json),
      repRange: _decodeRepRange(json['repRange']),
    );
  }

  static Map<String, Object?> _encodeSwap(engine.PlanSwapCandidate swap) =>
      <String, Object?>{
        ..._encodeLoadProfile(
          exerciseId: swap.exerciseId,
          name: swap.name,
          blockRole: swap.blockRole,
          movementClass: swap.movementClass,
          metricType: swap.metricType,
          laterality: swap.laterality,
          difficultyTier: swap.difficultyTier,
          resistanceEquipment: swap.resistanceEquipment,
          supportEquipment: swap.supportEquipment,
          bwContribution: swap.bwContribution,
          loadStepOverride: swap.loadStepOverride,
          repRange: swap.repRange,
        ),
        'tier': swap.tier,
        'rank': swap.rank,
        'baseDose': _encodeDose(swap.baseDose),
      };

  static engine.PlanSwapCandidate _decodeSwap(Map<String, Object?> json) {
    return engine.PlanSwapCandidate(
      exerciseId: json['exerciseId']! as String,
      name: json['name']! as String,
      blockRole: _enum(engine.BlockRole.values, json['blockRole']),
      movementClass: _enum(engine.MovementClass.values, json['movementClass']),
      metricType: _enum(engine.MetricType.values, json['metricType']),
      laterality: _enum(engine.Laterality.values, json['laterality']),
      difficultyTier: _enum(
        engine.DifficultyTier.values,
        json['difficultyTier'],
      ),
      resistanceEquipment: _enum(
        engine.ResistanceEquipment.values,
        json['resistanceEquipment'],
      ),
      supportEquipment: _enum(
        engine.SupportEquipment.values,
        json['supportEquipment'],
      ),
      bwContribution: _number(json['bwContribution']),
      loadStepOverride: _kilogramsOrNull(json['loadStepOverrideKg']),
      tier: _integer(json['tier']),
      rank: _integer(json['rank']),
      baseDose: _decodeBaseDose(json),
      repRange: _decodeRepRange(json['repRange']),
    );
  }

  static Map<String, Object?> _encodeLoadProfile({
    required String exerciseId,
    required String name,
    required engine.BlockRole blockRole,
    required engine.MovementClass movementClass,
    required engine.MetricType metricType,
    required engine.Laterality laterality,
    required engine.DifficultyTier difficultyTier,
    required engine.ResistanceEquipment resistanceEquipment,
    required engine.SupportEquipment supportEquipment,
    required double bwContribution,
    required engine.Kg? loadStepOverride,
    required engine.RepRange? repRange,
  }) => <String, Object?>{
    'exerciseId': exerciseId,
    'name': name,
    'blockRole': blockRole.name,
    'movementClass': movementClass.name,
    'metricType': metricType.name,
    'laterality': laterality.name,
    'difficultyTier': difficultyTier.name,
    'resistanceEquipment': resistanceEquipment.name,
    'supportEquipment': supportEquipment.name,
    'bwContribution': bwContribution,
    'loadStepOverrideKg': loadStepOverride?.value,
    'repRange': repRange == null
        ? null
        : <String, Object?>{'min': repRange.min, 'max': repRange.max},
  };

  static engine.Dose _decodeBaseDose(Map<String, Object?> json) {
    if (json['baseDose'] case final Map<String, Object?> dose) {
      return _decodeDose(dose);
    }
    // Schema v1 stored four materialized week doses. The build dose is the
    // lossless base from which the v2 vectors derive every week.
    final legacy = json['doseByWeekKind']! as Map<String, Object?>;
    return _decodeDose(legacy['build']! as Map<String, Object?>);
  }

  static Map<String, Object?> _encodeDose(engine.Dose dose) => switch (dose) {
    engine.RepsDose(
      :final sets,
      :final range,
      :final effort,
      :final targetReps,
    ) =>
      <String, Object?>{
        'type': 'reps',
        'sets': sets,
        'minReps': range.min,
        'maxReps': range.max,
        'targetRpe': effort.rpe,
        'targetReps': targetReps,
      },
    engine.TimedDose(:final sets, :final hold) => <String, Object?>{
      'type': 'timed',
      'sets': sets,
      'holdSeconds': hold.inSeconds,
    },
  };

  static engine.Dose _decodeDose(Map<String, Object?> json) =>
      switch (json['type']) {
        'reps' => engine.RepsDose(
          sets: _integer(json['sets']),
          range: engine.RepRange(
            _integer(json['minReps']),
            _integer(json['maxReps']),
          ),
          effort: engine.EffortTarget(_integer(json['targetRpe'])),
          targetReps: _integer(json['targetReps']),
        ),
        'timed' => engine.TimedDose(
          sets: _integer(json['sets']),
          hold: Duration(seconds: _integer(json['holdSeconds'])),
        ),
        final Object? type => throw FormatException('Unknown dose type: $type'),
      };

  static engine.RepRange? _decodeRepRange(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    return engine.RepRange(_integer(raw['min']), _integer(raw['max']));
  }

  static engine.Kg? _kilogramsOrNull(Object? value) =>
      value == null ? null : engine.Kg(_number(value));

  static int _integer(Object? value) => (value! as num).toInt();

  static double _number(Object? value) => (value! as num).toDouble();

  static T _enum<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown ${T.toString()} value: $name');
  }
}
