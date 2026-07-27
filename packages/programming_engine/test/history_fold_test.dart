import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

void main() {
  group('event-log fold', () {
    test('derives progression memory and exclusions in one session pass', () {
      final history = TrainingHistory(
        userExcludedExerciseIds: const {'user-excluded'},
        records: [
          _record(
            id: 's1',
            date: DateTime.utc(2026, 1, 5),
            events: [
              SetCompleted(
                exerciseId: 'squat',
                setIndex: 0,
                load: Kg(20),
                reps: 10,
                unitSystem: UnitSystem.metric,
              ),
              SetCompleted(
                exerciseId: 'squat',
                setIndex: 1,
                load: Kg(20),
                reps: 10,
                unitSystem: UnitSystem.metric,
              ),
              EffortReported(exerciseId: 'squat', level: EffortLevel.tooHard),
              PainReported(exerciseId: 'row', site: PainSite.shoulder),
            ],
          ),
          _record(
            id: 's2',
            date: DateTime.utc(2026, 1, 8),
            events: [
              SetCompleted(
                exerciseId: 'squat',
                setIndex: 0,
                load: Kg(20),
                reps: 10,
                unitSystem: UnitSystem.metric,
              ),
              EffortReported(exerciseId: 'squat', level: EffortLevel.tooHard),
            ],
          ),
        ],
      );

      final folded = foldTrainingHistory(history);
      final squat = folded.exercise('squat');
      expect(squat.lastLoad, const Kg(20));
      expect(squat.lastReps, 10);
      expect(
        squat.targetReps,
        10,
        reason: 'legacy events fall back to actual reps',
      );
      expect(squat.lastEffort, EffortLevel.tooHard);
      expect(squat.everSeen, isTrue);
      expect(squat.sessionsSinceProgress, 2);
      expect(squat.consecutiveTooHardCount, 2);
      expect(squat.lastWorkingLoad, const Kg(20));
      expect(folded.excludedExerciseIds, {'user-excluded', 'row'});
      expect(folded.lastCompletedSessionDate, DateTime.utc(2026, 1, 8));
      expect(folded.completedSessionCount, 2);
    });

    test('rep or load progress resets the stall memory', () {
      final records = [
        _setRecord('s1', DateTime.utc(2026, 1, 5), const Kg(20), 10),
        _setRecord('s2', DateTime.utc(2026, 1, 8), const Kg(20), 11),
        _setRecord('s3', DateTime.utc(2026, 1, 12), const Kg(25), 10),
      ];

      final afterRepProgress = foldTrainingHistory(
        TrainingHistory(records: records.take(2)),
      ).exercise('squat');
      final afterLoadProgress = foldTrainingHistory(
        TrainingHistory(records: records),
      ).exercise('squat');
      expect(afterRepProgress.sessionsSinceProgress, 0);
      expect(afterLoadProgress.sessionsSinceProgress, 0);
    });

    test(
      'new events preserve prescribed context separately from performance',
      () {
        final folded = foldTrainingHistory(
          TrainingHistory(
            records: [
              _record(
                id: 'prescribed',
                date: DateTime.utc(2026, 1, 5),
                events: [
                  SetCompleted(
                    exerciseId: 'squat',
                    setIndex: 0,
                    load: Kg(20),
                    reps: 8,
                    unitSystem: UnitSystem.metric,
                    targetReps: 10,
                    targetRpe: 7,
                    prescribedLoad: Kg(22.5),
                  ),
                ],
              ),
            ],
          ),
        ).exercise('squat');

        expect(folded.lastLoad, const Kg(20));
        expect(folded.lastReps, 8);
        expect(folded.targetReps, 10);
        expect(folded.targetRpe, 7);
        expect(folded.prescribedLoad, const Kg(22.5));
        expect(folded.asProgressionSnapshot()!.targetReps, 10);
      },
    );

    test('legacy events explicitly retain actual-reps target fallback', () {
      final folded = foldTrainingHistory(
        TrainingHistory(
          records: [
            _setRecord('legacy', DateTime.utc(2026, 1, 5), const Kg(20), 7),
          ],
        ),
      ).exercise('squat');

      expect(folded.targetReps, 7);
      expect(folded.targetRpe, isNull);
      expect(folded.prescribedLoad, isNull);
      expect(folded.asProgressionSnapshot()!.targetReps, 7);
    });

    test('programmed deload does not replace the working anchor', () {
      final folded = foldTrainingHistory(
        TrainingHistory(
          records: [
            _setRecord(
              'push',
              DateTime.utc(2026, 2, 2),
              const Kg(30),
              12,
              weekKind: MesocycleWeekKind.push,
              week: 5,
            ),
            _setRecord(
              'deload',
              DateTime.utc(2026, 2, 9),
              const Kg(20),
              10,
              weekKind: MesocycleWeekKind.deload,
              week: 6,
            ),
          ],
        ),
      ).exercise('squat');

      expect(folded.lastLoad, const Kg(20));
      expect(folded.lastWorkingLoad, const Kg(30));
      expect(folded.lastWorkingReps, 12);
    });

    test(
      'abandoned sessions affect exercise memory but not completion date',
      () {
        final completed = _setRecord(
          's1',
          DateTime.utc(2026, 1, 5),
          const Kg(20),
          10,
        );
        final abandoned = _record(
          id: 's2',
          date: DateTime.utc(2026, 1, 8),
          events: [
            SetCompleted(
              exerciseId: 'squat',
              setIndex: 0,
              load: Kg(22),
              reps: 8,
              unitSystem: UnitSystem.metric,
            ),
            SessionAbandoned(),
          ],
        );
        final folded = foldTrainingHistory(
          TrainingHistory(records: [completed, abandoned]),
        );

        expect(folded.exercise('squat').lastLoad, const Kg(22));
        expect(folded.lastCompletedSessionDate, DateTime.utc(2026, 1, 5));
        expect(folded.completedSessionCount, 1);
      },
    );

    test('fold(all) equals fold(prefix) plus incremental suffix', () {
      final records = [
        _setRecord('s1', DateTime.utc(2026, 1, 5), const Kg(20), 10),
        _setRecord('s2', DateTime.utc(2026, 1, 8), const Kg(20), 11),
        _record(
          id: 's3',
          date: DateTime.utc(2026, 1, 12),
          events: [PainReported(exerciseId: 'squat', site: PainSite.knee)],
        ),
      ];
      final all = foldTrainingHistory(
        TrainingHistory(
          records: records,
          userExcludedExerciseIds: const {'user-excluded'},
        ),
      );
      var incremental = foldTrainingHistory(
        TrainingHistory(
          records: records.take(1),
          userExcludedExerciseIds: const {'user-excluded'},
        ),
      );
      for (final record in records.skip(1)) {
        incremental = incrementTrainingSnapshot(incremental, record);
      }

      expect(incremental, all);
    });
  });
}

SessionRecord _setRecord(
  String id,
  DateTime date,
  Kg load,
  int reps, {
  MesocycleWeekKind weekKind = MesocycleWeekKind.build,
  int week = 1,
}) => _record(
  id: id,
  date: date,
  weekKind: weekKind,
  week: week,
  events: [
    SetCompleted(
      exerciseId: 'squat',
      setIndex: 0,
      load: load,
      reps: reps,
      unitSystem: UnitSystem.metric,
    ),
    const EffortReported(exerciseId: 'squat', level: EffortLevel.justRight),
  ],
);

SessionRecord _record({
  required String id,
  required DateTime date,
  required List<SessionEvent> events,
  MesocycleWeekKind weekKind = MesocycleWeekKind.build,
  int week = 1,
}) => SessionRecord(
  sessionId: id,
  date: date,
  planRef: 'plan',
  mesocycleIndex: 1,
  mesocycleWeekIndex: week,
  absoluteWeekIndex: week,
  dayIndex: 1,
  weekKind: weekKind,
  events: events,
);
