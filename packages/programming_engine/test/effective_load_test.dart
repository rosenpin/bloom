/// `ENGINE.md` › "Effective load" — `external + bw_contribution × bodyMass`.
///
/// The worked example in `EXERCISES.md`: a 70 kg woman adding 2 kg to a goblet squat
/// changed her effective load ~4%, not 20%.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('the conversion', () {
    const goblet = EffectiveLoad(
      bwContribution: 0.65,
      bodyMass: referenceBodyMass,
    );

    test('a 70 kg user holding 12 kg on a goblet squat moves 57.5 kg', () {
      expect(goblet.bodyTerm, const Kg(45.5));
      expect(goblet.effective(const Kg(12)), const Kg(57.5));
    });

    test('external and effective round-trip exactly', () {
      const contributions = <double>[0, 0.1, 0.4, 0.65, 0.85, 1];
      const masses = <Kg>[Kg(45), Kg(58), Kg(70), Kg(95), Kg(120)];
      const externals = <Kg>[
        Kg(-50),
        Kg(-30),
        Kg.zero,
        Kg(2),
        Kg(12),
        Kg(22.5),
        Kg(100),
      ];
      for (final contribution in contributions) {
        for (final mass in masses) {
          final math = EffectiveLoad(
            bwContribution: contribution,
            bodyMass: mass,
          );
          for (final external in externals) {
            expect(
              math.external(math.effective(external)).value,
              closeTo(external.value, 1e-9),
              reason: 'bw $contribution, ${mass.value}kg, ${external.value}kg',
            );
          }
        }
      }
    });

    test('+2 kg on a goblet squat is ~3.5% of the load moved, not 16.7%', () {
      final before = goblet.effective(const Kg(12));
      final after = goblet.effective(const Kg(14));
      final effectiveChange = (after - before).fractionOf(before);
      final externalChange = const Kg(2).fractionOf(const Kg(12));
      expect(effectiveChange, closeTo(0.0348, 1e-3));
      expect(externalChange, closeTo(0.1667, 1e-3));
    });

    test('a pure bodyweight movement still has a load to scale', () {
      const plankMath = EffectiveLoad(
        bwContribution: 1,
        bodyMass: referenceBodyMass,
      );
      expect(plankMath.effective(Kg.zero), referenceBodyMass);
      expect(plankMath.external(referenceBodyMass), Kg.zero);
    });

    test(
      'assisted-stack external load subtracts assistance from body mass',
      () {
        const assisted = EffectiveLoad(
          bwContribution: 0.85,
          bodyMass: referenceBodyMass,
        );
        expect(assisted.bodyTerm, const Kg(59.5));
        expect(assisted.effective(const Kg(-30)), const Kg(29.5));
        expect(assisted.external(const Kg(29.5)), const Kg(-30));
      },
    );

    test('externalOnly is the no-body-mass degradation', () {
      expect(EffectiveLoad.externalOnly.effective(const Kg(12)), const Kg(12));
    });

    test('is a value type', () {
      expect(
        const EffectiveLoad(bwContribution: 0.65, bodyMass: Kg(70)),
        const EffectiveLoad(bwContribution: 0.65, bodyMass: Kg(70)),
      );
      expect(
        const EffectiveLoad(bwContribution: 0.65, bodyMass: Kg(70)).hashCode,
        const EffectiveLoad(bwContribution: 0.65, bodyMass: Kg(70)).hashCode,
      );
    });
  });

  group('the guardrails run on effective load', () {
    /// The same report and history on two exercises that differ only in
    /// `bw_contribution`.
    const externalOnlyTwin = ExerciseData(
      id: 'goblet-twin-without-bw',
      name: 'Goblet Squat (bw ignored)',
      blockRole: BlockRole.lowerSquat,
      movementClass: MovementClass.compoundLower,
      metricType: MetricType.loadReps,
      resistanceEquipment: ResistanceEquipment.dumbbell,
      bwContribution: 0,
    );

    test('bw_contribution widens the ±10% cap in external terms', () {
      ProgressionInput inputWith(ExerciseData exercise) => inputFor(
        exercise,
        range: compoundRange,
        lastLoad: const Kg(12),
        lastReps: 14,
        targetReps: 10,
        reported: EffortLevel.wayTooEasy,
      );

      final withBw = suggester.suggest(inputWith(gobletSquat));
      final withoutBw = suggester.suggest(inputWith(externalOnlyTwin));

      // 10% of 57.5 kg effective is 5.75 kg, so two dumbbell steps fit.
      expect(withBw.stepsMoved, 2);
      // 10% of 12 kg is 1.2 kg, so only the one-step floor applies.
      expect(withoutBw.stepsMoved, 1);
    });

    test(
      'a 120 kg user is not asked for the same relative jump as a 50 kg user',
      () {
        LoadDecision decisionFor(Kg bodyMass) => suggester.suggest(
          inputFor(
            gobletSquat,
            range: compoundRange,
            lastLoad: const Kg(12),
            lastReps: 12,
            targetReps: 10,
            reported: EffortLevel.wayTooEasy,
            bodyMass: bodyMass,
          ),
        );

        final lighter = decisionFor(const Kg(50));
        final heavier = decisionFor(const Kg(120));
        expect(lighter.stepsMoved, lessThanOrEqualTo(heavier.stepsMoved));
        expect(heavier.stepsMoved, lessThanOrEqualTo(2));
      },
    );

    test('a bodyweight movement can progress at all, which is the point', () {
      final decision = suggester.suggest(
        inputFor(
          gluteBridgeAdded,
          range: isolationRange,
          lastLoad: Kg.zero,
          lastReps: 15,
          targetReps: 15,
          reported: EffortLevel.wayTooEasy,
        ),
      );
      expect(decision.suggestion, isA<BodyweightOnly>());
      expect(decision.stepsMoved, greaterThan(0));
    });
  });
}
