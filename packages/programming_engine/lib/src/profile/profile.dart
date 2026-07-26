/// Immutable onboarding answers consumed at plan time.
library;

import 'package:collection/collection.dart';

import '../config/programming_config.dart';

enum AgeBand {
  age18To29(18, 29),
  age30To39(30, 39),
  age40To49(40, 49),
  age50To59(50, 59),
  age60Plus(60, null);

  const AgeBand(this.minimumAge, this.maximumAge);

  final int minimumAge;
  final int? maximumAge;

  bool get isAtLeast50 => minimumAge >= 50;
  bool get isAtLeast60 => minimumAge >= 60;
}

enum TrainingDaysPerWeek {
  two(2),
  three(3),
  four(4);

  const TrainingDaysPerWeek(this.value);
  final int value;
}

enum SessionMinutes {
  thirty(30),
  fortyFive(45),
  sixty(60);

  const SessionMinutes(this.value);
  final int value;
}

enum Emphasis { balanced, glutes, back, arms, core, legs }

/// The three answers exposed by the quiz. [newToIt] is the assembler's
/// never-trained tier; [beenAWhile] maps to returning experience.
enum ProfileExperienceTier { newToIt, beenAWhile, trainsRegularly }

enum GymComfort { low, mostlyFine, totallyAtHome }

enum ActivityKind { running, cycling, groupClasses, sport, yogaPilates, other }

/// One collected answer to "what else do you do?".
final class WeeklyActivity {
  const WeeklyActivity({required this.kind, required this.sessionsPerWeek})
    : assert(sessionsPerWeek >= 0);

  final ActivityKind kind;
  final int sessionsPerWeek;

  @override
  bool operator ==(Object other) =>
      other is WeeklyActivity &&
      other.kind == kind &&
      other.sessionsPerWeek == sessionsPerWeek;

  @override
  int get hashCode => Object.hash(kind, sessionsPerWeek);
}

/// A quiz snapshot. Every field participates in value equality and the profile
/// stamp, even when a field is deliberately not a v1 assembly input.
final class Profile {
  const Profile({
    required this.ageBand,
    required this.daysPerWeek,
    required this.sessionMinutes,
    required this.goal,
    required this.emphasis,
    required this.experienceTier,
    required this.gymComfort,
    required this.weeksTrained,
    required this.mesocycleIndex,
    this.otherActivities = const <WeeklyActivity>[],
  }) : assert(weeksTrained >= 0),
       assert(mesocycleIndex >= 1);

  final AgeBand ageBand;
  final TrainingDaysPerWeek daysPerWeek;
  final SessionMinutes sessionMinutes;
  final Goal goal;
  final Emphasis emphasis;
  final ProfileExperienceTier experienceTier;
  final GymComfort gymComfort;
  final int weeksTrained;

  /// 1-based authored-variation selector.
  final int mesocycleIndex;

  /// Collected and retained, but deliberately ignored by `assemblePlan` in v1.
  ///
  /// Decided 2026-07-25: the quiz does not ask which days these activities occur,
  /// so volume caps or day placement would be guesswork. The answers become an
  /// assembly input only if a day picker is added with an evidence-backed rule.
  final List<WeeklyActivity> otherActivities;

  Profile copyWith({
    AgeBand? ageBand,
    TrainingDaysPerWeek? daysPerWeek,
    SessionMinutes? sessionMinutes,
    Goal? goal,
    Emphasis? emphasis,
    ProfileExperienceTier? experienceTier,
    GymComfort? gymComfort,
    int? weeksTrained,
    int? mesocycleIndex,
    List<WeeklyActivity>? otherActivities,
  }) => Profile(
    ageBand: ageBand ?? this.ageBand,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    goal: goal ?? this.goal,
    emphasis: emphasis ?? this.emphasis,
    experienceTier: experienceTier ?? this.experienceTier,
    gymComfort: gymComfort ?? this.gymComfort,
    weeksTrained: weeksTrained ?? this.weeksTrained,
    mesocycleIndex: mesocycleIndex ?? this.mesocycleIndex,
    otherActivities: otherActivities ?? this.otherActivities,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.ageBand == ageBand &&
      other.daysPerWeek == daysPerWeek &&
      other.sessionMinutes == sessionMinutes &&
      other.goal == goal &&
      other.emphasis == emphasis &&
      other.experienceTier == experienceTier &&
      other.gymComfort == gymComfort &&
      other.weeksTrained == weeksTrained &&
      other.mesocycleIndex == mesocycleIndex &&
      const ListEquality<WeeklyActivity>().equals(
        other.otherActivities,
        otherActivities,
      );

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
    Object.hashAll(otherActivities),
  );
}
