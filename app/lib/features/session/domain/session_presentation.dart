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

  static String? imageAsset(String exerciseId) {
    if (exerciseId.contains('goblet-squat')) {
      return 'assets/images/goblet-squat-2.jpg';
    }
    if (exerciseId.contains('hip-thrust') ||
        exerciseId.contains('glute-bridge')) {
      return 'assets/images/hip-thrust-2.jpg';
    }
    if (exerciseId.contains('lateral-raise')) {
      return 'assets/images/lateral-raise-2.jpg';
    }
    return null;
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
      switch (entry.prescription.dose) {
        engine.RepsDose(:final targetReps) => targetReps,
        engine.TimedDose() => 1,
      };

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
