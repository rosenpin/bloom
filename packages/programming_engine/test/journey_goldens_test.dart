import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

void main() {
  final config = ProgrammingConfig();
  final start = DateTime.utc(2026, 1, 5);
  final standardDates = _standardDates(start);

  test('novice squat journey golden and +20% by week 4 standing rule', () {
    final plan = _journeyPlan(
      const ['dumbbell-goblet-squat', 'machine-leg-press'],
      config,
      profileStamp: 'novice-squat',
    );
    final journey = _runJourney(
      plan: plan,
      config: config,
      dates: standardDates,
      effortFor: (session, exerciseId) => session <= 6
          ? session.isOdd
                ? EffortLevel.wayTooEasy
                : EffortLevel.aBitEasy
          : EffortLevel.justRight,
    );

    expect(journey.projection, _noviceSquatGolden);
    for (final exerciseId in const [
      'dumbbell-goblet-squat',
      'machine-leg-press',
    ]) {
      final points = journey.points
          .where((point) => point.exerciseId == exerciseId)
          .toList(growable: false);
      final week4 = points.firstWhere((point) => point.week == 4);
      expect(
        week4.load.value,
        greaterThanOrEqualTo(points.first.load.value * 1.20),
        reason: exerciseId,
      );
    }
    _assertJourneyInvariants(journey, plan, config);
  });

  test('16-day layoff journey golden applies one tier and recovers', () {
    final plan = _journeyPlan(
      const ['machine-leg-press', 'machine-pulldown'],
      config,
      profileStamp: 'layoff',
    );
    final dates = <DateTime>[
      for (final offset in const [
        0,
        3,
        7,
        10,
        26,
        29,
        33,
        36,
        40,
        43,
        47,
        50,
        54,
        57,
        61,
        64,
        68,
        71,
        75,
        78,
      ])
        start.add(Duration(days: offset)),
    ];
    final journey = _runJourney(
      plan: plan,
      config: config,
      dates: dates,
      effortFor: (session, exerciseId) =>
          session <= 8 ? EffortLevel.wayTooEasy : EffortLevel.justRight,
    );

    expect(journey.projection, _layoffGolden);
    final returnResolution = journey.resolutions[4];
    expect(returnResolution.daysSinceLastSession, 16);
    for (final prescription in returnResolution.prescriptions) {
      expect(prescription.why, contains(ReasonCode.layoffTier2));
    }
    for (final resolution in journey.resolutions.skip(5).take(2)) {
      for (final prescription in resolution.prescriptions) {
        expect(prescription.why, isNot(contains(ReasonCode.layoffTier2)));
      }
    }
    for (final exerciseId in const ['machine-leg-press', 'machine-pulldown']) {
      final points = journey.points
          .where((point) => point.exerciseId == exerciseId)
          .toList(growable: false);
      final preLayoff = points[3].load;
      final twoSessionsAfterReturn = points[6].load;
      expect(
        twoSessionsAfterReturn.value,
        greaterThanOrEqualTo(preLayoff.value),
        reason: exerciseId,
      );
    }

    final prefix = TrainingHistory(
      records: journey.history.records.take(4),
      bodyMass: const Kg(65),
    );
    final lastDate = dates[3];
    final suggestions = <Kg>[];
    for (final away in const [6, 10, 16, 30]) {
      final resolution = resolveSession(
        plan,
        prefix,
        lastDate.add(Duration(days: away)),
        config: config,
      );
      suggestions.add(
        _loadOf(
          resolution.prescriptions
              .firstWhere((item) => item.exerciseId == 'machine-leg-press')
              .suggestion,
        ),
      );
    }
    for (var index = 1; index < suggestions.length; index++) {
      expect(
        suggestions[index].value,
        lessThanOrEqualTo(suggestions[index - 1].value),
      );
    }
    _assertJourneyInvariants(journey, plan, config);
  });

  test('stall journey golden deloads the third exposure then rebuilds', () {
    final plan = _journeyPlan(
      const ['machine-leg-press', 'machine-pulldown'],
      config,
      profileStamp: 'stall',
    );
    final journey = _runJourney(
      plan: plan,
      config: config,
      dates: standardDates,
      effortFor: (session, exerciseId) => EffortLevel.justRight,
      actualLoadFor: (session, prescription) {
        if (session <= 2) return const Kg(30);
        return _loadOf(prescription.suggestion);
      },
      actualRepsFor: (session, prescription) =>
          session <= 2 ? 10 : _targetReps(prescription),
    );

    expect(journey.projection, _stallGolden);
    final third = journey.resolutions[2];
    for (final prescription in third.prescriptions) {
      expect(prescription.why, contains(ReasonCode.stallDeload));
      expect(_loadOf(prescription.suggestion).value, lessThan(30));
    }
    final laterLoads = journey.points
        .where(
          (point) =>
              point.exerciseId == 'machine-leg-press' && point.session >= 3,
        )
        .map((point) => point.load)
        .toList(growable: false);
    expect(laterLoads.last.value, greaterThan(laterLoads.first.value));
    _assertJourneyInvariants(journey, plan, config);
  });

  test('deload-week journey golden is strictly lighter then steps up', () {
    final plan = _journeyPlan(
      const ['dumbbell-goblet-squat', 'machine-leg-press'],
      config,
      profileStamp: 'programmed-deload',
    );
    final journey = _runJourney(
      plan: plan,
      config: config,
      dates: standardDates,
      effortFor: (session, exerciseId) =>
          session <= 6 ? EffortLevel.aBitEasy : EffortLevel.justRight,
    );

    expect(journey.projection, _deloadWeekGolden);
    final profiles = _profiles(plan);
    for (final resolution in journey.resolutions.where(
      (item) => item.weekKind == MesocycleWeekKind.easier,
    )) {
      for (final prescription in resolution.prescriptions) {
        final dose = prescription.dose as RepsDose;
        expect(dose.sets, 2);
        expect(dose.effort, const EffortTarget(6));
        expect(prescription.why, contains(ReasonCode.easierWeek));
      }
    }
    for (final resolution in journey.resolutions.where(
      (item) => item.weekKind == MesocycleWeekKind.deload,
    )) {
      for (final prescription in resolution.prescriptions) {
        final dose = prescription.dose as RepsDose;
        expect(dose.effort, const EffortTarget(5));
        expect(prescription.why, contains(ReasonCode.deloadWeek));
      }
    }
    for (final exerciseId in const [
      'dumbbell-goblet-squat',
      'machine-leg-press',
    ]) {
      final points = journey.points
          .where((point) => point.exerciseId == exerciseId)
          .toList(growable: false);
      final week5 = points.where((point) => point.week == 5).last.load;
      final week6 = points.where((point) => point.week == 6);
      for (final point in week6) {
        expect(point.load.value, lessThan(week5.value), reason: exerciseId);
      }
      final week7 = points.where((point) => point.week == 7).first.load;
      final loads = config.availableLoads(
        profiles[exerciseId]!,
        UnitSystem.metric,
      );
      expect(
        loads.stepsBetween(week5, week7),
        config.newMesocycleStepUp,
        reason: exerciseId,
      );
    }
    _assertJourneyInvariants(journey, plan, config);
  });

  test('assisted-stack journey golden moves toward zero and never crosses', () {
    final assistedConfig = ProgrammingConfig(
      metricLoads: EquipmentLoadTable(
        barbellBar: Kg(20),
        barbellUpperStep: Kg(2.5),
        barbellLowerStep: Kg(5),
        dumbbellFloor: Kg(2),
        dumbbellStep: Kg(2),
        machineFloor: Kg(5),
        machineStep: Kg(5),
        assistedStackMaxAssistance: Kg(30),
        assistedStackStep: Kg(5),
        cableFloor: Kg(2.5),
        cableStep: Kg(2.5),
        addedLoadStep: Kg(2),
      ),
    );
    final plan = _journeyPlan(
      const ['bodyweight-assisted-chin-up', 'machine-pulldown'],
      assistedConfig,
      profileStamp: 'assisted-stack',
    );
    final journey = _runJourney(
      plan: plan,
      config: assistedConfig,
      dates: standardDates,
      effortFor: (session, exerciseId) =>
          session <= 8 ? EffortLevel.wayTooEasy : EffortLevel.justRight,
    );

    expect(journey.projection, _assistedStackGolden);
    final assisted = journey.points
        .where((point) => point.exerciseId == 'bodyweight-assisted-chin-up')
        .toList(growable: false);
    expect(assisted.first.load, const Kg(-30));
    expect(assisted.last.load.value, greaterThan(assisted.first.load.value));
    for (final point in assisted) {
      expect(point.load.value, lessThanOrEqualTo(0));
    }
    _assertJourneyInvariants(journey, plan, assistedConfig);
  });
}

final class _JourneyPoint {
  const _JourneyPoint({
    required this.session,
    required this.week,
    required this.exerciseId,
    required this.load,
    required this.targetReps,
  });

  final int session;
  final int week;
  final String exerciseId;
  final Kg load;
  final int targetReps;
}

final class _JourneyResult {
  const _JourneyResult({
    required this.points,
    required this.resolutions,
    required this.history,
  });

  final List<_JourneyPoint> points;
  final List<SessionResolution> resolutions;
  final TrainingHistory history;

  String get projection => [
    for (final point in points)
      '${point.session.toString().padLeft(2, '0')} '
          '${point.exerciseId} '
          '${_kgText(point.load)} '
          '${point.targetReps}',
  ].join('\n');
}

typedef _EffortFor = EffortLevel Function(int session, String exerciseId);
typedef _ActualLoadFor =
    Kg Function(int session, ExercisePrescription prescription);
typedef _ActualRepsFor =
    int Function(int session, ExercisePrescription prescription);

_JourneyResult _runJourney({
  required Plan plan,
  required ProgrammingConfig config,
  required List<DateTime> dates,
  required _EffortFor effortFor,
  _ActualLoadFor? actualLoadFor,
  _ActualRepsFor? actualRepsFor,
}) {
  var history = TrainingHistory(bodyMass: const Kg(65));
  final points = <_JourneyPoint>[];
  final resolutions = <SessionResolution>[];
  for (var index = 0; index < dates.length; index++) {
    final session = index + 1;
    final resolution = resolveSession(
      plan,
      history,
      dates[index],
      config: config,
    );
    final rerun = resolveSession(plan, history, dates[index], config: config);
    expect(rerun.toCanonicalString(), resolution.toCanonicalString());
    resolutions.add(resolution);

    final events = <SessionEvent>[];
    for (final prescription in resolution.prescriptions) {
      points.add(
        _JourneyPoint(
          session: session,
          week: resolution.absoluteWeekIndex,
          exerciseId: prescription.exerciseId,
          load: _loadOf(prescription.suggestion),
          targetReps: _targetReps(prescription),
        ),
      );
      events
        ..add(
          SetCompleted(
            exerciseId: prescription.exerciseId,
            setIndex: 0,
            load:
                actualLoadFor?.call(session, prescription) ??
                _loadOf(prescription.suggestion),
            reps:
                actualRepsFor?.call(session, prescription) ??
                _targetReps(prescription),
            unitSystem: UnitSystem.metric,
          ),
        )
        ..add(
          EffortReported(
            exerciseId: prescription.exerciseId,
            level: effortFor(session, prescription.exerciseId),
          ),
        );
    }
    history = history.add(
      resolution.toRecord(sessionId: 's$session', events: events),
    );
  }
  return _JourneyResult(
    points: List<_JourneyPoint>.unmodifiable(points),
    resolutions: List<SessionResolution>.unmodifiable(resolutions),
    history: history,
  );
}

void _assertJourneyInvariants(
  _JourneyResult journey,
  Plan plan,
  ProgrammingConfig config,
) {
  final profiles = _profiles(plan);
  for (final resolution in journey.resolutions) {
    for (final prescription in resolution.prescriptions) {
      expect(
        prescription.why,
        isNotEmpty,
        reason: '${resolution.absoluteWeekIndex}/${prescription.exerciseId}',
      );
      final loads = config.availableLoads(
        profiles[prescription.exerciseId]!,
        UnitSystem.metric,
      );
      switch (prescription.suggestion) {
        case SuggestedLoad(:final kg):
          expect(loads.isRepresentable(kg), isTrue);
        case BodyweightOnly(:final added):
          expect(loads.isRepresentable(added), isTrue);
        case NeedsCalibration(:final floor):
          expect(loads.isRepresentable(floor), isTrue);
        case RepOrDurationTarget():
          break;
      }
    }
  }
}

List<DateTime> _standardDates(DateTime start) => [
  for (var week = 0; week < 12; week++) ...[
    start.add(Duration(days: week * 7)),
    start.add(Duration(days: week * 7 + 3)),
  ],
];

Plan _journeyPlan(
  List<String> exerciseIds,
  ProgrammingConfig config, {
  required String profileStamp,
}) {
  final exercisesById = <String, Exercise>{
    for (final exercise in catalogV1.exercises) exercise.id: exercise,
  };
  final scheme = config.schemeFor(Goal.tonedAndDefined, weeksTrained: 0);
  final exercises = <PlanExercise>[
    for (final id in exerciseIds)
      _planExercise(exercisesById[id]!, scheme, config),
  ];
  return Plan(
    mesocycleIndex: 1,
    stamps: PlanStamps(
      engineVersion: currentEngineVersion,
      configHash: 'journey-config',
      contentHash: catalogV1.contentVersion,
      profileHash: profileStamp,
    ),
    mesocycleCalendar: [
      for (var week = 1; week <= config.mesocycleWeeks; week++)
        PlanWeek(weekIndex: week, kind: config.weekKind(week)),
    ],
    days: [
      PlanDay(
        dayIndex: 1,
        kind: PlanDayKind.fullBodyA,
        warmUpMinutes: config.warmUpMinutes,
        hasCardioFinisher: false,
        exercises: exercises,
      ),
      PlanDay(
        dayIndex: 2,
        kind: PlanDayKind.fullBodyB,
        warmUpMinutes: config.warmUpMinutes,
        hasCardioFinisher: false,
        exercises: exercises,
      ),
    ],
    warnings: const <EngineWarning>[],
  );
}

PlanExercise _planExercise(
  Exercise exercise,
  RepScheme scheme,
  ProgrammingConfig config,
) {
  final range = config.rangeFor(exercise, scheme);
  RepsDose dose(int sets, EffortTarget effort) =>
      RepsDose(sets: sets, range: range, effort: effort, targetReps: range.min);
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
    dropPriority: 0,
    isEmphasis: false,
    rotatesAcrossMesocycles: false,
    rotationCandidateIds: const <String>[],
    orderedSwapCandidates: const <PlanSwapCandidate>[],
    doseByWeekKind: WeekDoses(
      build: dose(scheme.maxSets, scheme.effort),
      easier: dose(
        (scheme.maxSets + config.easierWeekSetsDelta).clamp(1, scheme.maxSets),
        scheme.effort.easierBy(config.easierWeekRpeDelta.abs()),
      ),
      push: dose(scheme.maxSets, scheme.effort),
      deload: dose(
        scheme.maxSets,
        scheme.effort.easierBy(config.deloadWeekRpeDelta.abs()),
      ),
    ),
    repRange: range,
  );
}

Map<String, LoadProfile> _profiles(Plan plan) => {
  for (final exercise in plan.days.expand((day) => day.exercises))
    exercise.exerciseId: exercise,
};

Kg _loadOf(LoadSuggestion suggestion) => switch (suggestion) {
  SuggestedLoad(:final kg) => kg,
  BodyweightOnly(:final added) => added,
  NeedsCalibration(:final floor) => floor,
  RepOrDurationTarget() => Kg.zero,
};

int _targetReps(ExercisePrescription prescription) =>
    switch (prescription.dose) {
      RepsDose(:final targetReps) => targetReps,
      TimedDose() => 1,
    };

String _kgText(Kg kg) {
  final rounded = kg.value.roundToDouble();
  return kg.value == rounded
      ? rounded.toInt().toString()
      : kg.value.toStringAsFixed(3);
}

const _noviceSquatGolden = '''
01 dumbbell-goblet-squat 2 8
01 machine-leg-press 5 8
02 dumbbell-goblet-squat 4 10
02 machine-leg-press 10 10
03 dumbbell-goblet-squat 4 11
03 machine-leg-press 10 11
04 dumbbell-goblet-squat 6 10
04 machine-leg-press 15 10
05 dumbbell-goblet-squat 6 11
05 machine-leg-press 15 11
06 dumbbell-goblet-squat 8 10
06 machine-leg-press 20 10
07 dumbbell-goblet-squat 8 10
07 machine-leg-press 20 10
08 dumbbell-goblet-squat 8 10
08 machine-leg-press 20 10
09 dumbbell-goblet-squat 8 11
09 machine-leg-press 20 11
10 dumbbell-goblet-squat 8 12
10 machine-leg-press 20 12
11 dumbbell-goblet-squat 2 10
11 machine-leg-press 15 10
12 dumbbell-goblet-squat 2 10
12 machine-leg-press 15 10
13 dumbbell-goblet-squat 10 10
13 machine-leg-press 25 10
14 dumbbell-goblet-squat 10 11
14 machine-leg-press 25 11
15 dumbbell-goblet-squat 10 12
15 machine-leg-press 25 12
16 dumbbell-goblet-squat 12 10
16 machine-leg-press 30 10
17 dumbbell-goblet-squat 12 11
17 machine-leg-press 30 11
18 dumbbell-goblet-squat 12 12
18 machine-leg-press 30 12
19 dumbbell-goblet-squat 12 12
19 machine-leg-press 30 12
20 dumbbell-goblet-squat 12 12
20 machine-leg-press 30 12
21 dumbbell-goblet-squat 14 10
21 machine-leg-press 35 10
22 dumbbell-goblet-squat 14 11
22 machine-leg-press 35 11
23 dumbbell-goblet-squat 2 10
23 machine-leg-press 25 10
24 dumbbell-goblet-squat 2 10
24 machine-leg-press 25 10''';
const _layoffGolden = '''
01 machine-leg-press 5 8
01 machine-pulldown 5 8
02 machine-leg-press 10 10
02 machine-pulldown 10 10
03 machine-leg-press 15 10
03 machine-pulldown 15 10
04 machine-leg-press 20 10
04 machine-pulldown 20 10
05 machine-leg-press 15 10
05 machine-pulldown 15 10
06 machine-leg-press 20 10
06 machine-pulldown 20 10
07 machine-leg-press 25 10
07 machine-pulldown 25 10
08 machine-leg-press 20 10
08 machine-pulldown 20 10
09 machine-leg-press 20 10
09 machine-pulldown 20 10
10 machine-leg-press 30 10
10 machine-pulldown 30 10
11 machine-leg-press 30 11
11 machine-pulldown 30 11
12 machine-leg-press 30 12
12 machine-pulldown 30 12
13 machine-leg-press 35 10
13 machine-pulldown 35 10
14 machine-leg-press 35 11
14 machine-pulldown 35 11
15 machine-leg-press 35 12
15 machine-pulldown 35 12
16 machine-leg-press 35 12
16 machine-pulldown 35 12
17 machine-leg-press 35 12
17 machine-pulldown 35 12
18 machine-leg-press 40 10
18 machine-pulldown 40 10
19 machine-leg-press 40 11
19 machine-pulldown 40 11
20 machine-leg-press 30 10
20 machine-pulldown 30 10''';
const _stallGolden = '''
01 machine-leg-press 5 8
01 machine-pulldown 5 8
02 machine-leg-press 30 11
02 machine-pulldown 30 11
03 machine-leg-press 25 10
03 machine-pulldown 25 10
04 machine-leg-press 25 11
04 machine-pulldown 25 11
05 machine-leg-press 25 12
05 machine-pulldown 25 12
06 machine-leg-press 30 10
06 machine-pulldown 30 10
07 machine-leg-press 30 10
07 machine-pulldown 30 10
08 machine-leg-press 30 10
08 machine-pulldown 30 10
09 machine-leg-press 30 11
09 machine-pulldown 30 11
10 machine-leg-press 30 12
10 machine-pulldown 30 12
11 machine-leg-press 20 10
11 machine-pulldown 20 10
12 machine-leg-press 20 10
12 machine-pulldown 20 10
13 machine-leg-press 35 10
13 machine-pulldown 35 10
14 machine-leg-press 35 11
14 machine-pulldown 35 11
15 machine-leg-press 35 12
15 machine-pulldown 35 12
16 machine-leg-press 40 10
16 machine-pulldown 40 10
17 machine-leg-press 40 11
17 machine-pulldown 40 11
18 machine-leg-press 40 12
18 machine-pulldown 40 12
19 machine-leg-press 40 12
19 machine-pulldown 40 12
20 machine-leg-press 40 12
20 machine-pulldown 40 12
21 machine-leg-press 45 10
21 machine-pulldown 45 10
22 machine-leg-press 45 11
22 machine-pulldown 45 11
23 machine-leg-press 35 10
23 machine-pulldown 35 10
24 machine-leg-press 35 10
24 machine-pulldown 35 10''';
const _deloadWeekGolden = '''
01 dumbbell-goblet-squat 2 8
01 machine-leg-press 5 8
02 dumbbell-goblet-squat 2 10
02 machine-leg-press 5 10
03 dumbbell-goblet-squat 2 11
03 machine-leg-press 5 11
04 dumbbell-goblet-squat 2 12
04 machine-leg-press 5 12
05 dumbbell-goblet-squat 4 10
05 machine-leg-press 10 10
06 dumbbell-goblet-squat 4 11
06 machine-leg-press 10 11
07 dumbbell-goblet-squat 4 11
07 machine-leg-press 10 11
08 dumbbell-goblet-squat 4 11
08 machine-leg-press 10 11
09 dumbbell-goblet-squat 4 12
09 machine-leg-press 10 12
10 dumbbell-goblet-squat 6 10
10 machine-leg-press 15 10
11 dumbbell-goblet-squat 2 10
11 machine-leg-press 10 10
12 dumbbell-goblet-squat 2 10
12 machine-leg-press 10 10
13 dumbbell-goblet-squat 8 10
13 machine-leg-press 20 10
14 dumbbell-goblet-squat 8 11
14 machine-leg-press 20 11
15 dumbbell-goblet-squat 8 12
15 machine-leg-press 20 12
16 dumbbell-goblet-squat 10 10
16 machine-leg-press 25 10
17 dumbbell-goblet-squat 10 11
17 machine-leg-press 25 11
18 dumbbell-goblet-squat 10 12
18 machine-leg-press 25 12
19 dumbbell-goblet-squat 10 12
19 machine-leg-press 25 12
20 dumbbell-goblet-squat 10 12
20 machine-leg-press 25 12
21 dumbbell-goblet-squat 12 10
21 machine-leg-press 30 10
22 dumbbell-goblet-squat 12 11
22 machine-leg-press 30 11
23 dumbbell-goblet-squat 2 10
23 machine-leg-press 20 10
24 dumbbell-goblet-squat 2 10
24 machine-leg-press 20 10''';
const _assistedStackGolden = '''
01 bodyweight-assisted-chin-up -30 8
01 machine-pulldown 5 8
02 bodyweight-assisted-chin-up -25 10
02 machine-pulldown 10 10
03 bodyweight-assisted-chin-up -20 10
03 machine-pulldown 15 10
04 bodyweight-assisted-chin-up -15 10
04 machine-pulldown 20 10
05 bodyweight-assisted-chin-up -10 10
05 machine-pulldown 25 10
06 bodyweight-assisted-chin-up -5 10
06 machine-pulldown 30 10
07 bodyweight-assisted-chin-up -5 10
07 machine-pulldown 30 10
08 bodyweight-assisted-chin-up -5 10
08 machine-pulldown 30 10
09 bodyweight-assisted-chin-up 0 10
09 machine-pulldown 35 10
10 bodyweight-assisted-chin-up 0 11
10 machine-pulldown 35 11
11 bodyweight-assisted-chin-up -15 10
11 machine-pulldown 25 10
12 bodyweight-assisted-chin-up -15 10
12 machine-pulldown 25 10
13 bodyweight-assisted-chin-up 0 10
13 machine-pulldown 40 10
14 bodyweight-assisted-chin-up 0 11
14 machine-pulldown 40 11
15 bodyweight-assisted-chin-up 0 12
15 machine-pulldown 40 12
16 bodyweight-assisted-chin-up 0 12
16 machine-pulldown 45 10
17 bodyweight-assisted-chin-up 0 12
17 machine-pulldown 45 11
18 bodyweight-assisted-chin-up 0 12
18 machine-pulldown 45 12
19 bodyweight-assisted-chin-up 0 12
19 machine-pulldown 45 12
20 bodyweight-assisted-chin-up 0 12
20 machine-pulldown 45 12
21 bodyweight-assisted-chin-up 0 12
21 machine-pulldown 50 10
22 bodyweight-assisted-chin-up 0 12
22 machine-pulldown 50 11
23 bodyweight-assisted-chin-up -15 10
23 machine-pulldown 40 10
24 bodyweight-assisted-chin-up -15 10
24 machine-pulldown 40 10''';
