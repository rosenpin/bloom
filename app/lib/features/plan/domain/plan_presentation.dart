import 'package:programming_engine/programming_engine.dart' as engine;

import '../../onboarding/domain/onboarding_answers.dart';

abstract final class PlanPresentation {
  static String planName(OnboardingAnswers answers) {
    final goal = switch (answers.goal) {
      engine.Goal.tonedAndDefined => 'Strong & Toned',
      engine.Goal.stronger => 'Everyday Strong',
      engine.Goal.buildCurves => 'Shape & Strength',
      engine.Goal.feelHealthier => 'Feel-Good Strength',
      null => 'Made-for-You Strength',
    };
    final emphasis = switch (answers.emphasis) {
      engine.Emphasis.glutes => 'Glute Focus',
      engine.Emphasis.legs => 'Leg Focus',
      engine.Emphasis.core => 'Core Focus',
      engine.Emphasis.arms => 'Arm Focus',
      engine.Emphasis.back => 'Back Focus',
      _ => null,
    };
    return emphasis == null ? goal : '$goal — $emphasis';
  }

  static String profileSummary(OnboardingAnswers answers) {
    final days = answers.daysPerWeek?.value ?? 0;
    final emphasis = emphasisLabel(answers.emphasis);
    final activities = _activitiesLabel(answers);
    return ['$days gym days', '$emphasis focus', ?activities].join(' · ');
  }

  static String emphasisLabel(engine.Emphasis? emphasis) => switch (emphasis) {
    engine.Emphasis.glutes => 'glute',
    engine.Emphasis.legs => 'leg',
    engine.Emphasis.core => 'core',
    engine.Emphasis.arms => 'arm',
    engine.Emphasis.back => 'back',
    _ => 'balanced',
  };

  static String dayName(engine.PlanDay day, OnboardingAnswers? answers) {
    final emphasis = answers?.emphasis;
    return switch (day.kind) {
      engine.PlanDayKind.fullBodyA => 'Full Body A',
      engine.PlanDayKind.fullBodyB => 'Full Body B',
      engine.PlanDayKind.lowerGluteLed => 'Lower Body — Glute Focus',
      engine.PlanDayKind.lower when emphasis == engine.Emphasis.glutes =>
        'Lower Body — Glute Focus',
      engine.PlanDayKind.lower when emphasis == engine.Emphasis.legs =>
        'Lower Body — Leg Focus',
      engine.PlanDayKind.lower => 'Lower Body',
      engine.PlanDayKind.upper when emphasis == engine.Emphasis.back =>
        'Upper Body — Back Focus',
      engine.PlanDayKind.upper when emphasis == engine.Emphasis.arms =>
        'Upper Body — Arm Focus',
      engine.PlanDayKind.upper => 'Upper Body — Tone & Posture',
    };
  }

  static String weekdayLabel(int dayIndex, int daysPerWeek) {
    final labels = switch (daysPerWeek) {
      2 => const ['MONDAY', 'THURSDAY'],
      4 => const ['MONDAY', 'TUESDAY', 'THURSDAY', 'SATURDAY'],
      _ => const ['MONDAY', 'WEDNESDAY', 'FRIDAY'],
    };
    return labels[(dayIndex - 1).clamp(0, labels.length - 1)];
  }

  static String weekKindLabel(engine.MesocycleWeekKind kind) => switch (kind) {
    engine.MesocycleWeekKind.build => 'Build week',
    engine.MesocycleWeekKind.easier => 'Easier week',
    engine.MesocycleWeekKind.push => 'Push week',
    engine.MesocycleWeekKind.deload => 'Deload week',
  };

  static String? _activitiesLabel(OnboardingAnswers answers) {
    if (answers.otherActivities.containsKey(engine.ActivityKind.yogaPilates)) {
      return 'yoga in your week';
    }
    if (answers.otherActivities.isNotEmpty) {
      return 'your other training in view';
    }
    return null;
  }
}
