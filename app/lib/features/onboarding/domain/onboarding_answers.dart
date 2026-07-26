import 'dart:convert';

import 'package:programming_engine/programming_engine.dart' as engine;

enum MenstrualPreference { undecided, optedIn, notApplicable, declined }

enum MenstrualGap {
  days26(26),
  days28(28),
  days30Plus(30),
  notSure(null);

  const MenstrualGap(this.days);

  final int? days;
}

/// The resumable, app-owned snapshot of every onboarding answer.
///
/// Menstrual answers live beside the quiz snapshot for resumption, while their
/// two sensitive values are also mirrored into the dedicated profile columns.
final class OnboardingAnswers {
  const OnboardingAnswers({
    required this.unitSystem,
    this.ageBand,
    this.goal,
    this.daysPerWeek,
    this.sessionMinutes,
    this.experienceTier,
    this.gymComfort,
    this.emphasis,
    this.otherActivities = const <engine.ActivityKind, int>{},
    this.menstrualPreference = MenstrualPreference.undecided,
    this.lastPeriodStart,
    this.menstrualGap,
    this.completed = false,
  });

  final engine.UnitSystem unitSystem;
  final engine.AgeBand? ageBand;
  final engine.Goal? goal;
  final engine.TrainingDaysPerWeek? daysPerWeek;
  final engine.SessionMinutes? sessionMinutes;
  final engine.ProfileExperienceTier? experienceTier;
  final engine.GymComfort? gymComfort;
  final engine.Emphasis? emphasis;
  final Map<engine.ActivityKind, int> otherActivities;
  final MenstrualPreference menstrualPreference;
  final DateTime? lastPeriodStart;
  final MenstrualGap? menstrualGap;
  final bool completed;

  int? get usualGapDays => menstrualGap?.days;

  bool get hasAllQuizAnswers =>
      ageBand != null &&
      goal != null &&
      daysPerWeek != null &&
      sessionMinutes != null &&
      experienceTier != null &&
      gymComfort != null &&
      emphasis != null;

  String get resumePath {
    if (ageBand == null) return '/onboarding/age';
    if (goal == null) return '/onboarding/goal';
    if (daysPerWeek == null) return '/onboarding/days';
    if (sessionMinutes == null) return '/onboarding/session-length';
    if (experienceTier == null || gymComfort == null) {
      return '/onboarding/experience';
    }
    if (emphasis == null) return '/onboarding/emphasis';
    return '/onboarding/activities';
  }

  engine.Profile toEngineProfile() {
    if (!hasAllQuizAnswers) {
      throw StateError('The seven onboarding questions are not complete.');
    }

    return engine.Profile(
      ageBand: ageBand!,
      daysPerWeek: daysPerWeek!,
      sessionMinutes: sessionMinutes!,
      goal: goal!,
      emphasis: emphasis!,
      experienceTier: experienceTier!,
      gymComfort: gymComfort!,
      weeksTrained: switch (experienceTier!) {
        engine.ProfileExperienceTier.newToIt => 0,
        engine.ProfileExperienceTier.beenAWhile => 4,
        engine.ProfileExperienceTier.trainsRegularly => 12,
      },
      mesocycleIndex: 1,
      // These answers are intentionally passed through for replay/profile
      // stamping but ignored by v1 assembly. The quiz does not collect which
      // weekdays they happen, so moving or reducing training would be guesswork.
      otherActivities: [
        for (final entry in otherActivities.entries)
          if (entry.value > 0)
            engine.WeeklyActivity(
              kind: entry.key,
              sessionsPerWeek: entry.value,
            ),
      ],
    );
  }

  static const Object _unchanged = Object();

  OnboardingAnswers copyWith({
    engine.UnitSystem? unitSystem,
    Object? ageBand = _unchanged,
    Object? goal = _unchanged,
    Object? daysPerWeek = _unchanged,
    Object? sessionMinutes = _unchanged,
    Object? experienceTier = _unchanged,
    Object? gymComfort = _unchanged,
    Object? emphasis = _unchanged,
    Map<engine.ActivityKind, int>? otherActivities,
    MenstrualPreference? menstrualPreference,
    Object? lastPeriodStart = _unchanged,
    Object? menstrualGap = _unchanged,
    bool? completed,
  }) {
    return OnboardingAnswers(
      unitSystem: unitSystem ?? this.unitSystem,
      ageBand: identical(ageBand, _unchanged)
          ? this.ageBand
          : ageBand as engine.AgeBand?,
      goal: identical(goal, _unchanged) ? this.goal : goal as engine.Goal?,
      daysPerWeek: identical(daysPerWeek, _unchanged)
          ? this.daysPerWeek
          : daysPerWeek as engine.TrainingDaysPerWeek?,
      sessionMinutes: identical(sessionMinutes, _unchanged)
          ? this.sessionMinutes
          : sessionMinutes as engine.SessionMinutes?,
      experienceTier: identical(experienceTier, _unchanged)
          ? this.experienceTier
          : experienceTier as engine.ProfileExperienceTier?,
      gymComfort: identical(gymComfort, _unchanged)
          ? this.gymComfort
          : gymComfort as engine.GymComfort?,
      emphasis: identical(emphasis, _unchanged)
          ? this.emphasis
          : emphasis as engine.Emphasis?,
      otherActivities: otherActivities ?? this.otherActivities,
      menstrualPreference: menstrualPreference ?? this.menstrualPreference,
      lastPeriodStart: identical(lastPeriodStart, _unchanged)
          ? this.lastPeriodStart
          : lastPeriodStart as DateTime?,
      menstrualGap: identical(menstrualGap, _unchanged)
          ? this.menstrualGap
          : menstrualGap as MenstrualGap?,
      completed: completed ?? this.completed,
    );
  }

  String toJson() => jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'unitSystem': unitSystem.name,
    'ageBand': ageBand?.name,
    'goal': goal?.name,
    'daysPerWeek': daysPerWeek?.name,
    'sessionMinutes': sessionMinutes?.name,
    'experienceTier': experienceTier?.name,
    'gymComfort': gymComfort?.name,
    'emphasis': emphasis?.name,
    'otherActivities': {
      for (final entry in otherActivities.entries) entry.key.name: entry.value,
    },
    'menstrualPreference': menstrualPreference.name,
    'lastPeriodStart': lastPeriodStart?.toIso8601String(),
    'menstrualGap': menstrualGap?.name,
    'completed': completed,
  });

  factory OnboardingAnswers.fromJson(
    String source, {
    required engine.UnitSystem fallbackUnitSystem,
  }) {
    try {
      final json = jsonDecode(source) as Map<String, Object?>;
      final rawActivities =
          json['otherActivities'] as Map<String, Object?>? ??
          const <String, Object?>{};
      return OnboardingAnswers(
        unitSystem:
            _enumOrNull(engine.UnitSystem.values, json['unitSystem']) ??
            fallbackUnitSystem,
        ageBand: _enumOrNull(engine.AgeBand.values, json['ageBand']),
        goal: _enumOrNull(engine.Goal.values, json['goal']),
        daysPerWeek: _enumOrNull(
          engine.TrainingDaysPerWeek.values,
          json['daysPerWeek'],
        ),
        sessionMinutes: _enumOrNull(
          engine.SessionMinutes.values,
          json['sessionMinutes'],
        ),
        experienceTier: _enumOrNull(
          engine.ProfileExperienceTier.values,
          json['experienceTier'],
        ),
        gymComfort: _enumOrNull(engine.GymComfort.values, json['gymComfort']),
        emphasis: _enumOrNull(engine.Emphasis.values, json['emphasis']),
        otherActivities: _decodeActivities(rawActivities),
        menstrualPreference:
            _enumOrNull(
              MenstrualPreference.values,
              json['menstrualPreference'],
            ) ??
            MenstrualPreference.undecided,
        lastPeriodStart: switch (json['lastPeriodStart']) {
          final String value => DateTime.tryParse(value),
          _ => null,
        },
        menstrualGap: _enumOrNull(MenstrualGap.values, json['menstrualGap']),
        completed: json['completed'] == true,
      );
    } on Object {
      return OnboardingAnswers(unitSystem: fallbackUnitSystem);
    }
  }
}

T? _enumOrNull<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

Map<engine.ActivityKind, int> _decodeActivities(
  Map<String, Object?> rawActivities,
) {
  final activities = <engine.ActivityKind, int>{};
  for (final entry in rawActivities.entries) {
    final kind = _enumOrNull(engine.ActivityKind.values, entry.key);
    if (kind != null && entry.value is num) {
      activities[kind] = (entry.value! as num).toInt();
    }
  }
  return activities;
}
