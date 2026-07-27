import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/plan_fixtures.dart';

void main() {
  group('advanceSession events', () {
    test('SetCompleted records by set index and marks the exercise done', () {
      var state = _freshState();
      final entry = _firstLoadEntry(state);
      state = _replaceWithWorkingLoad(state, entry.exerciseId, const Kg(20));
      final working = _entry(state, entry.exerciseId);
      final sets = working.prescription.dose.sets;

      for (var index = 0; index < sets; index++) {
        state = advanceSession(
          state,
          _completedSet(working, index, load: const Kg(20)),
        );
      }

      final completed = _entry(state, entry.exerciseId);
      expect(completed.setsCompleted, sets);
      expect(completed.status, SessionExerciseStatus.done);
      expect(state.budget.completedSetCount, sets);
    });

    test('set 1 below the range immediately drops remaining load by 10%', () {
      var state = _freshState();
      final entry = _firstLoadEntry(state);
      final loads = state.config.availableLoads(
        entry.planExercise,
        state.unitSystem,
      );
      final base = loads.shift(loads.floor, 4);
      state = _replaceWithWorkingLoad(state, entry.exerciseId, base);
      final working = _entry(state, entry.exerciseId);
      final dose = working.prescription.dose as RepsDose;

      state = advanceSession(
        state,
        _completedSet(working, 0, load: base, reps: dose.range.min - 1),
      );

      final updated = _entry(state, entry.exerciseId);
      final reduced = (updated.prescription.suggestion as SuggestedLoad).kg;
      expect(reduced.value, lessThan(base.value));
      expect(loads.isRepresentable(reduced), isTrue);
      expect(
        updated.prescription.why,
        contains(ReasonCode.missedBottomSameSessionDrop),
      );
      expect(
        state.reasonCodes,
        contains(ReasonCode.missedBottomSameSessionDrop),
      );
    });

    test('EffortReported attaches to the exercise and last report wins', () {
      var state = _freshState();
      final entry = state.exercises.first;
      state = advanceSession(
        state,
        EffortReported(
          exerciseId: entry.exerciseId,
          level: EffortLevel.justRight,
        ),
      );
      state = advanceSession(
        state,
        EffortReported(
          exerciseId: entry.exerciseId,
          level: EffortLevel.aBitEasy,
        ),
      );

      expect(_entry(state, entry.exerciseId).feelReport, EffortLevel.aBitEasy);
    });

    test('all SwapReasons reach the same tier-ranked graph', () {
      final initial = _freshState();
      final source = initial.exercises.firstWhere(
        (entry) => entry.planExercise.orderedSwapCandidates.isNotEmpty,
      );
      final expected = [...source.planExercise.orderedSwapCandidates]
        ..sort((left, right) {
          final tier = left.tier.compareTo(right.tier);
          return tier != 0 ? tier : left.rank.compareTo(right.rank);
        });

      for (final reason in SwapReason.values) {
        final swapped = advanceSession(
          initial,
          SwapRequested(exerciseId: source.exerciseId, reason: reason),
        );
        final replacement = swapped.exercises.firstWhere(
          (entry) => entry.originalExerciseId == source.originalExerciseId,
        );
        expect(replacement.exerciseId, expected.first.exerciseId);
        expect(replacement.status, SessionExerciseStatus.swapped);
        expect(
          swapped.pendingPlanEditSuggestions.single.tier,
          expected.first.tier,
        );
      }
    });

    test('tier ordering beats rank after exclusions', () {
      final initial = _freshState();
      final source = initial.exercises.firstWhere((entry) {
        final tiers = entry.planExercise.orderedSwapCandidates
            .map((candidate) => candidate.tier)
            .toSet();
        return tiers.length >= 2;
      });
      final lowestTier = source.planExercise.orderedSwapCandidates
          .map((candidate) => candidate.tier)
          .reduce((left, right) => left < right ? left : right);
      final excluded = source.planExercise.orderedSwapCandidates
          .where((candidate) => candidate.tier == lowestTier)
          .map((candidate) => candidate.exerciseId)
          .toSet();
      final withExclusions = initial.copyWith(
        excludedExerciseIds: <String>{
          ...initial.excludedExerciseIds,
          ...excluded,
        },
      );

      final swapped = advanceSession(
        withExclusions,
        SwapRequested(
          exerciseId: source.exerciseId,
          reason: SwapReason.uncomfortable,
        ),
      );
      final chosen = swapped.pendingPlanEditSuggestions.single;
      final bestRemainingTier = source.planExercise.orderedSwapCandidates
          .where((candidate) => !excluded.contains(candidate.exerciseId))
          .map((candidate) => candidate.tier)
          .reduce((left, right) => left < right ? left : right);
      expect(chosen.tier, bestRemainingTier);
      expect(chosen.tier, greaterThan(lowestTier));
    });

    test(
      'a swap target resolves from its own history instead of transferring load',
      () {
        final plan = successfulPlan(personaFixtures[0].profile);
        final initial = resolveSession(
          plan,
          TrainingHistory(bodyMass: const Kg(65)),
          DateTime.utc(2026, 7, 20),
        );
        final source = initial.exercises.firstWhere(
          (entry) => entry.planExercise.orderedSwapCandidates.isNotEmpty,
        );
        final candidate = source.planExercise.orderedSwapCandidates.first;
        final loads = initial.config.availableLoads(
          candidate,
          initial.unitSystem,
        );
        final ownLoad = loads.shift(loads.floor, 2);
        final history = TrainingHistory(
          bodyMass: const Kg(65),
          records: [
            SessionRecord(
              sessionId: 'candidate-history',
              date: DateTime.utc(2026, 7, 17),
              planRef: 'older-plan',
              mesocycleIndex: 1,
              mesocycleWeekIndex: 1,
              absoluteWeekIndex: 1,
              dayIndex: 1,
              weekKind: MesocycleWeekKind.build,
              events: [
                SetCompleted(
                  exerciseId: candidate.exerciseId,
                  setIndex: 0,
                  load: ownLoad,
                  reps: candidate.repRange?.min ?? 1,
                  unitSystem: UnitSystem.metric,
                  targetReps: candidate.repRange?.min ?? 1,
                  prescribedLoad: ownLoad,
                ),
                EffortReported(
                  exerciseId: candidate.exerciseId,
                  level: EffortLevel.justRight,
                ),
              ],
            ),
          ],
        );
        var state = resolveSession(plan, history, DateTime.utc(2026, 7, 20));
        state = advanceSession(
          state,
          SwapRequested(exerciseId: source.exerciseId, reason: SwapReason.busy),
        );

        final replacement = _entry(state, source.originalExerciseId);
        expect(replacement.exerciseId, candidate.exerciseId);
        expect(
          replacement.prescription.suggestion,
          isNot(isA<NeedsCalibration>()),
        );
      },
    );

    test('LowEnergy lowers only unstarted work and uses bottom targets', () {
      var state = _freshState();
      final first = _firstLoadEntry(state);
      final loads = state.config.availableLoads(
        first.planExercise,
        state.unitSystem,
      );
      final base = loads.shift(loads.floor, 4);
      state = _replaceWithWorkingLoad(state, first.exerciseId, base);

      state = advanceSession(state, const LowEnergy());

      final reducedEntry = _entry(state, first.exerciseId);
      final reduced =
          (reducedEntry.prescription.suggestion as SuggestedLoad).kg;
      final dose = reducedEntry.prescription.dose as RepsDose;
      expect(reduced.value, lessThan(base.value));
      expect(loads.isRepresentable(reduced), isTrue);
      expect(dose.targetReps, dose.range.min);
      expect(state.reasonCodes, contains(ReasonCode.lowEnergyApplied));
    });

    test('Shorten and LowEnergy are idempotent with a warning', () {
      final initial = _freshState();
      final shortened = advanceSession(initial, const Shorten(30));
      final shortenedTwice = advanceSession(shortened, const Shorten(30));
      expect(
        shortenedTwice.exercises.map((entry) => entry.status),
        shortened.exercises.map((entry) => entry.status),
      );
      expect(
        shortenedTwice.warnings.last.code,
        WarningCode.sessionModifierAlreadyApplied,
      );

      final low = advanceSession(initial, const LowEnergy());
      final lowTwice = advanceSession(low, const LowEnergy());
      expect(
        lowTwice.exercises.map((entry) => entry.prescription),
        low.exercises.map((entry) => entry.prescription),
      );
      expect(
        lowTwice.warnings.last.code,
        WarningCode.sessionModifierAlreadyApplied,
      );
    });

    test('PainReported stops, excludes and offers only tier 1/2', () {
      var state = _freshState();
      final source = state.exercises.firstWhere(
        (entry) => entry.planExercise.orderedSwapCandidates.isNotEmpty,
      );

      state = advanceSession(
        state,
        PainReported(exerciseId: source.exerciseId, site: PainSite.knee),
      );

      expect(
        _entry(state, source.exerciseId).status,
        SessionExerciseStatus.removed,
      );
      expect(state.pendingExclusions, contains(source.exerciseId));
      expect(state.excludedExerciseIds, contains(source.exerciseId));
      final suggestion = state.pendingSwapSuggestions.single;
      expect(suggestion.tier, lessThanOrEqualTo(2));
      expect(state.reasonCodes, contains(ReasonCode.painExclusion));
    });

    test('SessionAbandoned marks remaining skipped and stays valid', () {
      var state = _freshState();
      final first = state.exercises.first;
      state = advanceSession(state, SessionAbandoned());

      expect(state.isAbandoned, isTrue);
      expect(
        state.exercises
            .where((entry) => entry.exerciseId == first.exerciseId)
            .single
            .status,
        SessionExerciseStatus.skipped,
      );
      final ignored = advanceSession(
        state,
        EffortReported(
          exerciseId: first.exerciseId,
          level: EffortLevel.justRight,
        ),
      );
      expect(ignored.isAbandoned, isTrue);
      expect(ignored.warnings.last.code, WarningCode.sessionEventIgnored);
    });

    test('unknown exercise ids warn instead of throwing', () {
      final state = advanceSession(
        _freshState(),
        SetCompleted(
          exerciseId: 'missing',
          setIndex: 0,
          load: Kg(10),
          reps: 10,
          unitSystem: UnitSystem.metric,
        ),
      );
      expect(state.warnings.last.code, WarningCode.unknownSessionExercise);
    });
  });

  group('§7 calibration walkthroughs', () {
    test('a probe jump has a one-equipment-step natural floor', () {
      var state = _freshState();
      final source = state.exercises.firstWhere(
        (entry) =>
            entry.prescription.suggestion is NeedsCalibration &&
            !(entry.planExercise.resistanceEquipment ==
                    ResistanceEquipment.machine &&
                entry.planExercise.movementClass.isLowerBody),
      );
      final floor = (source.prescription.suggestion as NeedsCalibration).floor;
      final loads = state.config.availableLoads(
        source.planExercise,
        state.unitSystem,
      );

      state = advanceSession(
        state,
        _completedSet(
          source,
          0,
          load: floor,
          reps: state.config.calibrationProbeReps,
        ),
      );
      state = advanceSession(
        state,
        EffortReported(
          exerciseId: source.exerciseId,
          level: EffortLevel.aBitEasy,
        ),
      );
      final secondProbe = _entry(state, source.exerciseId);
      final next =
          (secondProbe.prescription.suggestion as NeedsCalibration).floor;
      expect(loads.stepsBetween(floor, next), 1);

      state = advanceSession(
        state,
        _completedSet(
          secondProbe,
          1,
          load: next,
          reps: state.config.calibrationProbeReps,
        ),
      );
      final settled = _entry(state, source.exerciseId);
      expect(settled.calibration.phase, CalibrationPhase.settled);
      expect(settled.prescription.suggestion, SuggestedLoad(next));
      expect(settled.prescription.why, contains(ReasonCode.calibrationSettled));
    });

    test(
      'body mass and movement coefficient can produce a multi-step jump',
      () {
        var state = _freshState(profile: personaFixtures[2].profile);
        final source = state.exercises.firstWhere(
          (entry) =>
              entry.prescription.suggestion is NeedsCalibration &&
              entry.planExercise.resistanceEquipment ==
                  ResistanceEquipment.machine &&
              entry.planExercise.movementClass.isLowerBody,
        );
        final floor =
            (source.prescription.suggestion as NeedsCalibration).floor;
        state = advanceSession(
          state,
          _completedSet(
            source,
            0,
            load: floor,
            reps: state.config.calibrationProbeReps,
          ),
        );
        state = advanceSession(
          state,
          EffortReported(
            exerciseId: source.exerciseId,
            level: EffortLevel.wayTooEasy,
          ),
        );
        final next =
            ((_entry(state, source.exerciseId).prescription.suggestion)
                    as NeedsCalibration)
                .floor;
        final loads = state.config.availableLoads(
          source.planExercise,
          state.unitSystem,
        );
        final coefficient =
            state.config.probeLoadFractionByMovementClass[source
                .planExercise
                .movementClass]!;
        final expectedWorkingLoad =
            coefficient *
            state.bodyMass.value *
            (1 - source.planExercise.bwContribution);
        final jump = state.config.calibrationJumpFraction * expectedWorkingLoad;
        var expected = loads.snapDown(floor + Kg(jump));
        if (expected <= floor) expected = loads.shift(floor, 1);
        expect(next, expected);
      },
    );

    test('absent body mass falls back to exactly one equipment step', () {
      var state = _freshState(bodyMass: Kg.zero);
      final source = state.exercises.firstWhere(
        (entry) => entry.prescription.suggestion is NeedsCalibration,
      );
      final floor = (source.prescription.suggestion as NeedsCalibration).floor;
      final loads = state.config.availableLoads(
        source.planExercise,
        state.unitSystem,
      );
      state = advanceSession(
        state,
        _completedSet(
          source,
          0,
          load: floor,
          reps: state.config.calibrationProbeReps,
        ),
      );
      state = advanceSession(
        state,
        EffortReported(
          exerciseId: source.exerciseId,
          level: EffortLevel.aBitEasy,
        ),
      );
      final next =
          (_entry(state, source.exerciseId).prescription.suggestion
                  as NeedsCalibration)
              .floor;
      expect(loads.stepsBetween(floor, next), 1);
    });

    test(
      'fewer than five clean reps at floor stops and offers easier swap',
      () {
        var state = _freshState();
        final source = state.exercises.firstWhere(
          (entry) =>
              entry.prescription.suggestion is NeedsCalibration &&
              entry.planExercise.orderedSwapCandidates.any(
                (candidate) => candidate.tier <= 2,
              ),
        );
        final floor =
            (source.prescription.suggestion as NeedsCalibration).floor;
        state = advanceSession(
          state,
          _completedSet(
            source,
            0,
            load: floor,
            reps: state.config.calibrationMinCleanReps - 1,
          ),
        );

        final failed = _entry(state, source.exerciseId);
        expect(failed.status, SessionExerciseStatus.removed);
        expect(failed.calibration.phase, CalibrationPhase.failed);
        expect(
          state.warnings.map((warning) => warning.code),
          contains(WarningCode.calibrationFloorFailed),
        );
        expect(state.pendingSwapSuggestions.single.tier, lessThanOrEqualTo(2));
      },
    );
  });

  test('shorten never drops a primary across catalog rotations', () {
    for (final fixture in personaFixtures) {
      for (var mesocycleIndex = 1; mesocycleIndex <= 8; mesocycleIndex++) {
        final plan = successfulPlan(
          fixture.profile.copyWith(mesocycleIndex: mesocycleIndex),
        );
        for (final day in plan.days) {
          final dayPlan = Plan(
            mesocycleIndex: plan.mesocycleIndex,
            stamps: plan.stamps,
            mesocycleCalendar: plan.mesocycleCalendar,
            days: <PlanDay>[day],
            warnings: plan.warnings,
          );
          final state = resolveSession(
            dayPlan,
            TrainingHistory(bodyMass: const Kg(65)),
            DateTime.utc(2026, 7, 20),
          );
          final shortened = advanceSession(state, const Shorten(20));
          for (final entry in shortened.exercises) {
            if (entry.planExercise.blockRole.isPrimary) {
              expect(
                entry.status,
                isNot(SessionExerciseStatus.removed),
                reason:
                    '${fixture.name}/m$mesocycleIndex/'
                    '${entry.exerciseId}',
              );
            }
          }
        }
      }
    }
  });

  test('same initial state and events produce byte-identical state', () {
    final initial = _freshState();
    final source = initial.exercises.firstWhere(
      (entry) => entry.planExercise.orderedSwapCandidates.isNotEmpty,
    );
    final events = <SessionEvent>[
      const LowEnergy(),
      SwapRequested(exerciseId: source.exerciseId, reason: SwapReason.busy),
      const Shorten(30),
    ];

    SessionState run() {
      var state = initial;
      for (final event in events) {
        state = advanceSession(state, event);
      }
      return state;
    }

    final first = run();
    final second = run();
    expect(first, second);
    expect(first.toCanonicalString(), second.toCanonicalString());
  });

  test('full scripted session projection golden', () {
    var state = _freshState();
    final primaries = state.exercises
        .where((entry) => entry.planExercise.blockRole.isPrimary)
        .toList(growable: false);
    final calibrating = primaries.first;
    final floor =
        (calibrating.prescription.suggestion as NeedsCalibration).floor;
    state = advanceSession(
      state,
      _completedSet(
        calibrating,
        0,
        load: floor,
        reps: state.config.calibrationProbeReps,
      ),
    );
    state = advanceSession(
      state,
      EffortReported(
        exerciseId: calibrating.exerciseId,
        level: EffortLevel.justRight,
      ),
    );
    state = advanceSession(
      state,
      SwapRequested(
        exerciseId: primaries[1].exerciseId,
        reason: SwapReason.unavailable,
      ),
    );
    state = advanceSession(state, const Shorten(30));
    state = _completeRemaining(state);

    expect(_sessionProjection(state), '''
budget=30
done=4
removed=2
skipped=0
pendingEdits=1
painExclusions=0
abandoned=false
exercises=dumbbell-glute-bridge:done,dumbbell-goblet-squat:done,dumbbell-romanian-deadlift:done,machine-leg-press:done,machine-leg-extension:removed,machine-hip-abduction:removed
''');
    expect(
      state.pendingPlanEditSuggestions.single,
      isA<KeepSwapPlanEditSuggestion>(),
    );
  });
}

SessionState _freshState({Profile? profile, Kg bodyMass = const Kg(65)}) {
  final plan = successfulPlan(profile ?? personaFixtures[0].profile);
  return resolveSession(
    plan,
    TrainingHistory(bodyMass: bodyMass),
    DateTime.utc(2026, 7, 20),
  );
}

SessionExerciseEntry _firstLoadEntry(SessionState state) =>
    state.exercises.firstWhere(
      (entry) => entry.planExercise.metricType == MetricType.loadReps,
    );

SessionExerciseEntry _entry(SessionState state, String exerciseId) =>
    state.exercises.firstWhere(
      (entry) =>
          entry.exerciseId == exerciseId ||
          entry.originalExerciseId == exerciseId,
    );

SessionState _replaceWithWorkingLoad(
  SessionState state,
  String exerciseId,
  Kg load,
) => state.copyWith(
  exercises: <SessionExerciseEntry>[
    for (final entry in state.exercises)
      if (entry.exerciseId != exerciseId)
        entry
      else
        entry.copyWith(
          prescription: ExercisePrescription(
            exerciseId: entry.exerciseId,
            dose: entry.prescription.dose,
            suggestion: SuggestedLoad(load),
            laterality: entry.prescription.laterality,
            bridge: entry.prescription.bridge,
            why: entry.prescription.why,
          ),
          calibration: const CalibrationState(
            phase: CalibrationPhase.notRequired,
            probeSetsCompleted: 0,
          ),
        ),
  ],
);

SetCompleted _completedSet(
  SessionExerciseEntry entry,
  int setIndex, {
  Kg? load,
  int? reps,
}) {
  final dose = entry.prescription.dose;
  return SetCompleted(
    exerciseId: entry.exerciseId,
    setIndex: setIndex,
    load: load ?? _suggestedLoad(entry.prescription.suggestion),
    reps:
        reps ??
        switch (dose) {
          RepsDose(:final targetReps) => targetReps,
          TimedDose() => 1,
        },
    unitSystem: UnitSystem.metric,
    targetReps: dose is RepsDose ? dose.targetReps : 1,
    targetRpe: dose is RepsDose ? dose.effort.rpe : null,
    prescribedLoad: load ?? _suggestedLoad(entry.prescription.suggestion),
  );
}

Kg _suggestedLoad(LoadSuggestion suggestion) => switch (suggestion) {
  SuggestedLoad(:final kg) => kg,
  BodyweightOnly(:final added) => added,
  NeedsCalibration(:final floor) => floor,
  RepOrDurationTarget() => Kg.zero,
};

SessionState _completeRemaining(SessionState state) {
  var current = state;
  for (final original in state.exercises) {
    while (true) {
      final entry = _entry(current, original.originalExerciseId);
      if (entry.status == SessionExerciseStatus.removed ||
          entry.status == SessionExerciseStatus.skipped ||
          entry.status == SessionExerciseStatus.done) {
        break;
      }
      current = advanceSession(
        current,
        _completedSet(entry, entry.setsCompleted),
      );
    }
  }
  return current;
}

String _sessionProjection(SessionState state) {
  int count(SessionExerciseStatus status) =>
      state.exercises.where((entry) => entry.status == status).length;
  final output = StringBuffer()
    ..writeln('budget=${state.budget.availableMinutes}')
    ..writeln('done=${count(SessionExerciseStatus.done)}')
    ..writeln('removed=${count(SessionExerciseStatus.removed)}')
    ..writeln('skipped=${count(SessionExerciseStatus.skipped)}')
    ..writeln('pendingEdits=${state.pendingPlanEditSuggestions.length}')
    ..writeln('painExclusions=${state.pendingExclusions.length}')
    ..writeln('abandoned=${state.isAbandoned}')
    ..writeln(
      'exercises=${state.exercises.map((entry) => '${entry.exerciseId}:${entry.status.name}').join(',')}',
    );
  return output.toString();
}
