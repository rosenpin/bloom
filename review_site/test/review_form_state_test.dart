import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart';
import 'package:review_site/models/review_form_state.dart';

void main() {
  test('form maps every engine profile and history input', () {
    const state = ReviewFormState(
      ageBand: AgeBand.age50To59,
      daysPerWeek: TrainingDaysPerWeek.four,
      sessionMinutes: SessionMinutes.sixty,
      goal: Goal.buildCurves,
      emphasis: Emphasis.back,
      experienceTier: ProfileExperienceTier.trainsRegularly,
      gymComfort: GymComfort.totallyAtHome,
      weeksTrained: 17,
      mesocycleIndex: 3,
      unitSystem: UnitSystem.imperial,
      bodyMassKg: 71.5,
      otherActivities: <ActivityKind, int>{
        ActivityKind.running: 2,
        ActivityKind.yogaPilates: 1,
      },
    );

    expect(
      state.toProfile(),
      const Profile(
        ageBand: AgeBand.age50To59,
        daysPerWeek: TrainingDaysPerWeek.four,
        sessionMinutes: SessionMinutes.sixty,
        goal: Goal.buildCurves,
        emphasis: Emphasis.back,
        experienceTier: ProfileExperienceTier.trainsRegularly,
        gymComfort: GymComfort.totallyAtHome,
        weeksTrained: 17,
        mesocycleIndex: 3,
        otherActivities: <WeeklyActivity>[
          WeeklyActivity(kind: ActivityKind.running, sessionsPerWeek: 2),
          WeeklyActivity(kind: ActivityKind.yogaPilates, sessionsPerWeek: 1),
        ],
      ),
    );
    expect(state.toHistory().unitSystem, UnitSystem.imperial);
    expect(state.toHistory().bodyMass, const Kg(71.5));
  });
}
