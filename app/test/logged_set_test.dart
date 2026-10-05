import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/features/session/domain/session_presentation.dart';

void main() {
  engine.SetCompleted set({Duration? hold, double kg = 0, int reps = 1}) =>
      engine.SetCompleted(
        exerciseId: 'x',
        setIndex: 0,
        load: engine.Kg(kg),
        reps: reps,
        unitSystem: engine.UnitSystem.metric,
        hold: hold,
      );

  test('a timed set reads as its hold, never reps or load', () {
    const metric = engine.UnitSystem.metric;
    expect(
      SessionPresentation.loggedSet(
        set(hold: const Duration(seconds: 25)),
        metric,
        timed: true,
      ),
      '25 s',
    );
    expect(
      SessionPresentation.loggedSet(
        set(hold: const Duration(seconds: 30)),
        metric,
        timed: true,
        perSide: true,
      ),
      '30 s each side',
    );
    expect(SessionPresentation.loggedSet(set(), metric, timed: true), 'Held');
    expect(
      SessionPresentation.loggedSet(set(kg: 5, reps: 8), metric, timed: false),
      '8 reps · 5 kg',
    );
  });
}
