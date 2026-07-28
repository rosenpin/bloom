import 'package:programming_engine/programming_engine.dart' as engine;

abstract final class SessionPresentation {
  static String formatLoad(
    engine.Kg load,
    engine.UnitSystem unitSystem, {
    bool includeUnit = true,
  }) {
    final value = unitSystem.isMetric ? load.value : load.inLb;
    final rounded = value.roundToDouble();
    final text = (value - rounded).abs() < 0.05
        ? rounded.toInt().toString()
        : value.toStringAsFixed(1);
    if (!includeUnit) return text;
    return '$text ${unitSystem.isMetric ? 'kg' : 'lb'}';
  }

  static String effortLabel(engine.EffortLevel level) => switch (level) {
    engine.EffortLevel.wayTooEasy => 'Way too easy',
    engine.EffortLevel.aBitEasy => 'A bit easy',
    engine.EffortLevel.justRight => 'Just right',
    engine.EffortLevel.harderThanIdLike => "Harder than I'd like",
    engine.EffortLevel.tooHard => 'Too hard',
  };

  static String blockRole(engine.BlockRole role) => switch (role) {
    engine.BlockRole.warmUp => 'Warm-up',
    engine.BlockRole.lowerHinge => 'Hinge',
    engine.BlockRole.lowerSquat => 'Squat',
    engine.BlockRole.upperPush => 'Upper push',
    engine.BlockRole.upperPull => 'Upper pull',
    engine.BlockRole.gluteIsolation => 'Glute focus',
    engine.BlockRole.legIsolation => 'Leg focus',
    engine.BlockRole.armShoulderIsolation => 'Arm and shoulder',
    engine.BlockRole.core => 'Core',
    engine.BlockRole.finisherCardio => 'Finisher',
  };

  static String cue(engine.SessionExerciseEntry entry) {
    final name = entry.planExercise.name.toLowerCase();
    if (name.contains('goblet squat')) {
      return 'Hold it like a cup at your chest';
    }
    if (name.contains('hip thrust')) return 'Drive through your heels';
    if (name.contains('lateral raise')) return 'Lead softly with your elbows';
    return 'Move slowly and keep the position steady';
  }

  static String feelQuestion(engine.SessionExerciseEntry entry) {
    final dose = entry.prescription.dose;
    if (dose is engine.RepsDose && dose.effort.rir >= 4) {
      return 'Could you have done a couple more?';
    }
    return 'How did that feel?';
  }

  static engine.Kg suggestionLoad(
    engine.SessionExerciseEntry entry, {
    engine.Kg? override,
  }) {
    if (override != null) return override;
    return switch (entry.prescription.suggestion) {
      engine.SuggestedLoad(:final kg) => kg,
      engine.BodyweightOnly(:final added) => added,
      engine.NeedsCalibration(:final floor) => floor,
      engine.RepOrDurationTarget() => engine.Kg.zero,
    };
  }

  static int targetReps(engine.SessionExerciseEntry entry) =>
      switch (entry.prescription.suggestion) {
        engine.NeedsCalibration(:final probeReps) => probeReps,
        engine.RepOrDurationTarget(:final reps) => reps,
        engine.SuggestedLoad() ||
        engine.BodyweightOnly() => switch (entry.prescription.dose) {
          engine.RepsDose(:final targetReps) => targetReps,
          engine.TimedDose() => 1,
        },
      };

  static String prescriptionNote(engine.SessionExerciseEntry entry) {
    if (entry.calibration.phase == engine.CalibrationPhase.settled &&
        entry.calibration.probeSetsCompleted > 0) {
      return 'ready for you · found together';
    }
    if (entry.setLogs.isNotEmpty) {
      return 'ready for you · based on your last set';
    }
    return 'ready for you · same as last time';
  }

  static int exercisePosition(
    engine.SessionState state,
    engine.SessionExerciseEntry current,
  ) {
    final slots = <String>{};
    for (final entry in state.exercises) {
      slots.add(entry.originalExerciseId);
      if (identical(entry, current) || entry == current) return slots.length;
    }
    return slots.length;
  }

  static int exerciseCount(engine.SessionState state) =>
      state.exercises.map((entry) => entry.originalExerciseId).toSet().length;

  static List<List<engine.SessionExerciseEntry>> exerciseSlots(
    engine.SessionState state,
  ) {
    final slots = <String, List<engine.SessionExerciseEntry>>{};
    for (final entry in state.exercises) {
      (slots[entry.originalExerciseId] ??= []).add(entry);
    }
    return List<List<engine.SessionExerciseEntry>>.unmodifiable(
      slots.values.map(List<engine.SessionExerciseEntry>.unmodifiable),
    );
  }

  static engine.SessionExerciseEntry? nextExercise(
    engine.SessionState state,
    engine.SessionExerciseEntry current,
  ) {
    final slots = exerciseSlots(state);
    final currentIndex = slots.indexWhere((slot) => slot.contains(current));
    if (currentIndex == -1) return null;
    for (final slot in slots.skip(currentIndex + 1)) {
      for (final entry in slot.reversed) {
        if (!entry.isTerminal) return entry;
      }
    }
    return null;
  }

  static bool hasLoggedExercise(
    engine.TrainingHistory history,
    engine.SessionState state,
    engine.SessionExerciseEntry entry,
  ) {
    final snapshot = engine.foldTrainingHistory(history);
    if (snapshot.exercise(entry.exerciseId).everSeen) return true;
    return state.exercises.any(
      (candidate) =>
          candidate.exerciseId == entry.exerciseId &&
          candidate.setLogs.isNotEmpty,
    );
  }

  static String upcomingDose(engine.SessionExerciseEntry entry) =>
      switch (entry.prescription.dose) {
        engine.RepsDose(:final sets, :final targetReps) =>
          '$sets sets × $targetReps',
        engine.TimedDose(:final sets, :final hold) =>
          '$sets sets × ${hold.inSeconds} sec',
      };

  static String? savedSwapWork(
    engine.SessionState state,
    engine.SessionExerciseEntry current,
  ) {
    final saved = state.exercises.where(
      (entry) =>
          entry != current &&
          entry.originalExerciseId == current.originalExerciseId &&
          entry.setLogs.isNotEmpty,
    );
    if (saved.isEmpty) return null;
    final savedSets = saved.fold<int>(
      0,
      (total, entry) => total + entry.setLogs.length,
    );
    final sourceName = saved.first.planExercise.name;
    return 'Your $savedSets $sourceName ${savedSets == 1 ? 'set is' : 'sets are'} saved. Only the remaining work moved here.';
  }

  static List<String> swapRecapLines(engine.SessionState state) {
    final entriesBySlot = <String, List<engine.SessionExerciseEntry>>{};
    for (final entry in state.exercises) {
      (entriesBySlot[entry.originalExerciseId] ??= []).add(entry);
    }
    return [
      for (final entries in entriesBySlot.values)
        if (entries.length > 1 &&
            entries.any((entry) => entry.setLogs.isNotEmpty))
          entries
              .where((entry) => entry.setLogs.isNotEmpty)
              .map((entry) {
                final sets = entry.setLogs.length;
                return '$sets ${entry.planExercise.name} ${sets == 1 ? 'set' : 'sets'}';
              })
              .join(' + '),
    ];
  }

  static String dayComparison(engine.Kg total) {
    if (total.value >= 1000) {
      return 'about the weight of a small car';
    }
    if (total.value >= 400) {
      return 'about the weight of a grand piano';
    }
    return 'a solid stack of loaded suitcases';
  }
}
