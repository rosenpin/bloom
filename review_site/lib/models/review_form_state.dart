import 'dart:convert';

import 'package:programming_engine/programming_engine.dart';

const _unset = Object();

final class ReviewFormState {
  const ReviewFormState({
    required this.ageBand,
    required this.daysPerWeek,
    required this.sessionMinutes,
    required this.goal,
    required this.emphasis,
    required this.experienceTier,
    required this.gymComfort,
    required this.weeksTrained,
    required this.mesocycleIndex,
    required this.unitSystem,
    required this.bodyMassKg,
    this.otherActivities = const <ActivityKind, int>{},
  });

  static const defaults = ReviewFormState(
    ageBand: AgeBand.age18To29,
    daysPerWeek: TrainingDaysPerWeek.three,
    sessionMinutes: SessionMinutes.fortyFive,
    goal: Goal.tonedAndDefined,
    emphasis: Emphasis.glutes,
    experienceTier: ProfileExperienceTier.newToIt,
    gymComfort: GymComfort.low,
    weeksTrained: 0,
    mesocycleIndex: 1,
    unitSystem: UnitSystem.metric,
    bodyMassKg: 65,
  );

  final AgeBand ageBand;
  final TrainingDaysPerWeek daysPerWeek;
  final SessionMinutes sessionMinutes;
  final Goal goal;
  final Emphasis emphasis;
  final ProfileExperienceTier experienceTier;
  final GymComfort gymComfort;
  final int weeksTrained;
  final int mesocycleIndex;
  final UnitSystem unitSystem;

  /// Canonical storage stays in kg even when the form displays pounds.
  final double bodyMassKg;
  final Map<ActivityKind, int> otherActivities;

  Profile toProfile() => Profile(
    ageBand: ageBand,
    daysPerWeek: daysPerWeek,
    sessionMinutes: sessionMinutes,
    goal: goal,
    emphasis: emphasis,
    experienceTier: experienceTier,
    gymComfort: gymComfort,
    weeksTrained: weeksTrained,
    mesocycleIndex: mesocycleIndex,
    otherActivities: <WeeklyActivity>[
      for (final entry in otherActivities.entries)
        if (entry.value > 0)
          WeeklyActivity(kind: entry.key, sessionsPerWeek: entry.value),
    ],
  );

  TrainingHistory toHistory() =>
      TrainingHistory(unitSystem: unitSystem, bodyMass: Kg(bodyMassKg));

  double get displayBodyMass =>
      unitSystem.isMetric ? bodyMassKg : Kg(bodyMassKg).inLb;

  ReviewFormState copyWith({
    AgeBand? ageBand,
    TrainingDaysPerWeek? daysPerWeek,
    SessionMinutes? sessionMinutes,
    Goal? goal,
    Emphasis? emphasis,
    ProfileExperienceTier? experienceTier,
    GymComfort? gymComfort,
    int? weeksTrained,
    int? mesocycleIndex,
    UnitSystem? unitSystem,
    double? bodyMassKg,
    Object? otherActivities = _unset,
  }) => ReviewFormState(
    ageBand: ageBand ?? this.ageBand,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    goal: goal ?? this.goal,
    emphasis: emphasis ?? this.emphasis,
    experienceTier: experienceTier ?? this.experienceTier,
    gymComfort: gymComfort ?? this.gymComfort,
    weeksTrained: weeksTrained ?? this.weeksTrained,
    mesocycleIndex: mesocycleIndex ?? this.mesocycleIndex,
    unitSystem: unitSystem ?? this.unitSystem,
    bodyMassKg: bodyMassKg ?? this.bodyMassKg,
    otherActivities: identical(otherActivities, _unset)
        ? this.otherActivities
        : otherActivities! as Map<ActivityKind, int>,
  );

  Map<String, Object> toJson() => <String, Object>{
    'ageBand': ageBand.name,
    'daysPerWeek': daysPerWeek.name,
    'sessionMinutes': sessionMinutes.name,
    'goal': goal.name,
    'emphasis': emphasis.name,
    'experienceTier': experienceTier.name,
    'gymComfort': gymComfort.name,
    'weeksTrained': weeksTrained,
    'mesocycleIndex': mesocycleIndex,
    'unitSystem': unitSystem.name,
    'bodyMassKg': bodyMassKg,
    'otherActivities': <String, int>{
      for (final entry in otherActivities.entries) entry.key.name: entry.value,
    },
  };

  static ReviewFormState fromJson(Map<String, Object?> json) {
    T named<T extends Enum>(List<T> values, String key, T fallback) {
      final name = json[key];
      if (name is! String) return fallback;
      return values.where((value) => value.name == name).firstOrNull ??
          fallback;
    }

    final rawActivities = json['otherActivities'];
    final activities = <ActivityKind, int>{};
    if (rawActivities is Map) {
      for (final entry in rawActivities.entries) {
        final kind = ActivityKind.values
            .where((value) => value.name == entry.key)
            .firstOrNull;
        final sessions = entry.value;
        if (kind != null && sessions is num && sessions >= 0) {
          activities[kind] = sessions.round();
        }
      }
    }
    return ReviewFormState(
      ageBand: named(AgeBand.values, 'ageBand', defaults.ageBand),
      daysPerWeek: named(
        TrainingDaysPerWeek.values,
        'daysPerWeek',
        defaults.daysPerWeek,
      ),
      sessionMinutes: named(
        SessionMinutes.values,
        'sessionMinutes',
        defaults.sessionMinutes,
      ),
      goal: named(Goal.values, 'goal', defaults.goal),
      emphasis: named(Emphasis.values, 'emphasis', defaults.emphasis),
      experienceTier: named(
        ProfileExperienceTier.values,
        'experienceTier',
        defaults.experienceTier,
      ),
      gymComfort: named(GymComfort.values, 'gymComfort', defaults.gymComfort),
      weeksTrained:
          (json['weeksTrained'] as num?)?.round().clamp(0, 520) ??
          defaults.weeksTrained,
      mesocycleIndex:
          (json['mesocycleIndex'] as num?)?.round().clamp(1, 999) ??
          defaults.mesocycleIndex,
      unitSystem: named(UnitSystem.values, 'unitSystem', defaults.unitSystem),
      bodyMassKg:
          (json['bodyMassKg'] as num?)?.toDouble().clamp(20, 400) ??
          defaults.bodyMassKg,
      otherActivities: activities,
    );
  }

  String toCanonicalJson() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is ReviewFormState &&
      other.ageBand == ageBand &&
      other.daysPerWeek == daysPerWeek &&
      other.sessionMinutes == sessionMinutes &&
      other.goal == goal &&
      other.emphasis == emphasis &&
      other.experienceTier == experienceTier &&
      other.gymComfort == gymComfort &&
      other.weeksTrained == weeksTrained &&
      other.mesocycleIndex == mesocycleIndex &&
      other.unitSystem == unitSystem &&
      other.bodyMassKg == bodyMassKg &&
      _sameActivities(other.otherActivities, otherActivities);

  @override
  int get hashCode => Object.hash(
    ageBand,
    daysPerWeek,
    sessionMinutes,
    goal,
    emphasis,
    experienceTier,
    gymComfort,
    weeksTrained,
    mesocycleIndex,
    unitSystem,
    bodyMassKg,
    Object.hashAll(
      ActivityKind.values.map(
        (kind) => Object.hash(kind, otherActivities[kind]),
      ),
    ),
  );
}

bool _sameActivities(
  Map<ActivityKind, int> left,
  Map<ActivityKind, int> right,
) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
