/// §3 "Weight increments" as available-load sets, in both markets.
///
/// `ENGINE.md` › "Units": loads must be snapped to values that physically exist for
/// the equipment family and unit system. This is engine logic, not display
/// formatting.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

typedef Ladder = ({
  String rule,
  ExerciseData exercise,
  UnitSystem unitSystem,

  /// The first rungs, in the unit system's own numbers.
  List<double> firstRungs,
});

void main() {
  group('§3 one step per equipment family', () {
    const ladders = <Ladder>[
      (
        rule: 'metric dumbbells: 2 kg steps from 2 kg',
        exercise: lateralRaise,
        unitSystem: UnitSystem.metric,
        firstRungs: [2, 4, 6, 8, 10],
      ),
      (
        rule: 'metric selectorized machine: 5 kg pins',
        exercise: legPress,
        unitSystem: UnitSystem.metric,
        firstRungs: [5, 10, 15, 20],
      ),
      (
        rule: 'metric cable: 2.5 kg pins',
        exercise: cablePushdown,
        unitSystem: UnitSystem.metric,
        firstRungs: [2.5, 5, 7.5, 10],
      ),
      (
        rule: 'metric barbell upper body: 20 kg bar, +2.5 kg total',
        exercise: barbellBench,
        unitSystem: UnitSystem.metric,
        firstRungs: [20, 22.5, 25, 27.5],
      ),
      (
        rule: 'metric barbell lower body: 20 kg bar, +5 kg total',
        exercise: barbellSquat,
        unitSystem: UnitSystem.metric,
        firstRungs: [20, 25, 30, 35],
      ),
      (
        rule: 'bodyweight with added load: from zero, in 2 kg steps',
        exercise: gluteBridgeAdded,
        unitSystem: UnitSystem.metric,
        firstRungs: [0, 2, 4, 6],
      ),
      (
        rule: 'lb dumbbells: 5 lb steps from 5 lb',
        exercise: lateralRaise,
        unitSystem: UnitSystem.imperial,
        firstRungs: [5, 10, 15, 20, 25],
      ),
      (
        rule: 'lb selectorized machine: 10 lb pins',
        exercise: legPress,
        unitSystem: UnitSystem.imperial,
        firstRungs: [10, 20, 30, 40],
      ),
      (
        rule: 'lb barbell lower body: 45 lb bar, +10 lb total',
        exercise: barbellSquat,
        unitSystem: UnitSystem.imperial,
        firstRungs: [45, 55, 65, 75],
      ),
      (
        rule: 'lb barbell upper body: 45 lb bar, +5 lb total',
        exercise: barbellBench,
        unitSystem: UnitSystem.imperial,
        firstRungs: [45, 50, 55, 60],
      ),
    ];

    for (final ladder in ladders) {
      test(ladder.rule, () {
        final loads = config.availableLoads(ladder.exercise, ladder.unitSystem);
        final toKg = ladder.unitSystem.isMetric
            ? (double value) => Kg(value)
            : (double value) => Kg(value * kgPerLb);
        expect(loads.floor.value, closeTo(toKg(ladder.firstRungs.first).value, 1e-9));
        for (var i = 0; i < ladder.firstRungs.length; i++) {
          final expected = toKg(ladder.firstRungs[i]);
          expect(
            loads.shift(loads.floor, i).value,
            closeTo(expected.value, 1e-9),
            reason: 'rung $i of ${ladder.rule}',
          );
          expect(loads.isRepresentable(expected), isTrue, reason: '${expected.value}');
        }
      });
    }

    test('a per-exercise pin size overrides the family default', () {
      final loads = config.availableLoads(hipAbduction, UnitSystem.metric);
      expect(loads.smallestStep, const Kg(2.5));
      expect(loads.floor, const Kg(2.5));
      expect(loads.isRepresentable(const Kg(22.5)), isTrue);
      expect(loads.isRepresentable(const Kg(21)), isFalse);
    });

    test('a nonsense override is ignored in favour of the family default', () {
      const broken = ExerciseData(
        id: 'broken',
        name: 'Broken',
        blockRole: BlockRole.legIsolation,
        movementClass: MovementClass.isolationLower,
        metricType: MetricType.loadReps,
        resistanceEquipment: ResistanceEquipment.machine,
        bwContribution: 0,
        loadStepOverride: Kg(-5),
      );
      expect(
        config.availableLoads(broken, UnitSystem.metric).smallestStep,
        const Kg(5),
      );
    });
  });

  group('snapping', () {
    final dumbbells = config.availableLoads(lateralRaise, UnitSystem.metric);

    test('snapDown never rounds up (§4.5)', () {
      for (final value in <double>[2, 2.1, 3.9, 4, 5.99, 11.4, 13.99]) {
        final snapped = dumbbells.snapDown(Kg(value));
        expect(snapped.value, lessThanOrEqualTo(value + 1e-9), reason: '$value');
        expect(dumbbells.isRepresentable(snapped), isTrue, reason: '$value');
      }
      expect(dumbbells.snapDown(const Kg(13.9)), const Kg(12));
    });

    test('snapping is clamped to the floor, never below it', () {
      expect(dumbbells.snapDown(const Kg(0.5)), const Kg(2));
      expect(dumbbells.snapDown(const Kg(-30)), const Kg(2));
      expect(dumbbells.shift(const Kg(4), -10), const Kg(2));
    });

    test('non-finite input is answered with the floor rather than an exception', () {
      expect(dumbbells.snapDown(const Kg(double.nan)), dumbbells.floor);
      expect(dumbbells.snapDown(const Kg(double.infinity)), dumbbells.floor);
      expect(dumbbells.isRepresentable(const Kg(double.nan)), isFalse);
    });

    test('shift and stepsBetween are inverses', () {
      for (final steps in <int>[-2, -1, 0, 1, 2, 5]) {
        final from = const Kg(12);
        final to = dumbbells.shift(from, steps);
        expect(dumbbells.stepsBetween(from, to), steps, reason: '$steps');
      }
    });

    test('lb-derived rungs stay representable in canonical kg', () {
      final loads = config.availableLoads(lateralRaise, UnitSystem.imperial);
      final twentyFive = loads.shift(loads.floor, 4);
      expect(twentyFive.inLb, closeTo(25, 1e-9));
      expect(loads.isRepresentable(twentyFive), isTrue);
      expect(loads.isRepresentable(loads.snapDown(const Kg(11.5))), isTrue);
      // 11.5 kg is between the 25 lb and 30 lb dumbbells: round down.
      expect(loads.snapDown(const Kg(11.5)).inLb, closeTo(25, 1e-9));
    });

    test('a ceiling stops the ladder where the rack does', () {
      const rack = ArithmeticLoads(floor: Kg(2), step: Kg(2), ceiling: Kg(10));
      expect(rack.snapDown(const Kg(30)), const Kg(10));
      expect(rack.shift(const Kg(10), 3), const Kg(10));
      expect(rack.isRepresentable(const Kg(12)), isFalse);
    });
  });

  group('an explicit inventory (a real dumbbell rack)', () {
    final rack = ExplicitLoads(const [
      Kg(1), Kg(2), Kg(3), Kg(4), Kg(5), Kg(6), Kg(7.5), Kg(10), Kg(12.5), Kg(15),
    ]);

    test('the step size varies along the rack', () {
      expect(rack.stepAt(const Kg(3)), const Kg(1));
      expect(rack.stepAt(const Kg(6)), const Kg(1.5));
      expect(rack.stepAt(const Kg(7.5)), const Kg(2.5));
      expect(rack.smallestStep, const Kg(1));
    });

    test('snapping picks real dumbbells', () {
      expect(rack.snapDown(const Kg(9)), const Kg(7.5));
      expect(rack.snapUp(const Kg(9)), const Kg(10));
      expect(rack.snapDown(const Kg(0.5)), const Kg(1));
      expect(rack.shift(const Kg(6), 2), const Kg(10));
      expect(rack.shift(const Kg(1), -5), const Kg(1));
      // 5 → 6 → 7.5 → 10 is three rungs on this rack, not one 5 kg jump.
      expect(rack.stepsBetween(const Kg(5), const Kg(10)), 3);
    });

    test('a degenerate inventory still answers every question', () {
      final single = ExplicitLoads(const [Kg.zero]);
      expect(single.floor, Kg.zero);
      expect(single.snapDown(const Kg(50)), Kg.zero);
      expect(single.shift(Kg.zero, 4), Kg.zero);
      expect(single.stepAt(Kg.zero), Kg.zero);
    });
  });

  group('Kg', () {
    test('is a value type with structural equality', () {
      expect(const Kg(2.5) == const Kg(2.5), isTrue);
      expect({const Kg(2.5): 'a'}[const Kg(2.5)], 'a');
      expect(const Kg(2.5) < const Kg(5), isTrue);
      expect((const Kg(5) - const Kg(7)).abs, const Kg(2));
      expect(const Kg(10) * 0.9, const Kg(9));
      expect((-const Kg(2)).isNegative, isTrue);
      expect(Kg.zero.isZero, isTrue);
    });

    test('converts between markets without losing the canonical value', () {
      expect(Kg.fromLb(45).inLb, closeTo(45, 1e-12));
      expect(const Kg(45 * kgPerLb).value, closeTo(20.4117, 1e-4));
      expect(const Kg(20).inLb, closeTo(44.0925, 1e-4));
    });

    test('fractionOf never divides by zero', () {
      expect(const Kg(5).fractionOf(Kg.zero), 0);
      expect(const Kg(5).fractionOf(const Kg(10)), 0.5);
    });

    test('sorts and compares', () {
      final loads = <Kg>[const Kg(10), const Kg(2), const Kg(5)]
        ..sort((a, b) => a.compareTo(b));
      expect(loads, <Kg>[const Kg(2), const Kg(5), const Kg(10)]);
    });
  });
}
