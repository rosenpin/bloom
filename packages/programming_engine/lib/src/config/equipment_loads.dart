/// Which loads physically exist, per `(equipment family, unit system)`.
///
/// `ENGINE.md` › "Equipment-representable loads": every suggestion is snapped to a
/// value that exists in her gym; between steps we round **down** and add reps. This
/// is engine logic, not display formatting — a 25 lb dumbbell is 11.34 kg and no
/// amount of UI rounding makes 11.5 kg liftable.
library;

import '../content/exercise.dart';
import '../core/units.dart';

/// The set of loads an equipment family can express.
abstract interface class AvailableLoads {
  /// The lightest thing that exists — empty bar, lowest pin, smallest dumbbell,
  /// or `Kg.zero` for bodyweight with nothing added.
  Kg get floor;

  /// The smallest increment anywhere in the set.
  Kg get smallestStep;

  /// The increment from the representable value at or below [load] to the next one
  /// up. Constant for arithmetic ladders; varies for a real dumbbell rack.
  Kg stepAt(Kg load);

  bool isRepresentable(Kg load);

  /// Largest representable value ≤ [load], never below [floor].
  Kg snapDown(Kg load);

  /// Smallest representable value ≥ [load], never below [floor].
  Kg snapUp(Kg load);

  /// Moves [steps] rungs from the representable value at or below [load].
  /// Negative moves down; never goes below [floor].
  Kg shift(Kg load, int steps);

  /// Signed number of rungs between the snapped positions of [from] and [to].
  int stepsBetween(Kg from, Kg to);
}

/// `floor + n × step` — the shape of a plate ladder, a pin stack, and a European
/// dumbbell rack.
final class ArithmeticLoads implements AvailableLoads {
  ArithmeticLoads({required this.floor, required this.step, this.ceiling})
    : assert(floor.value > double.negativeInfinity),
      assert(floor.value < double.infinity),
      assert(step.value > 0 && step.value < double.infinity),
      assert(ceiling == null || ceiling.value >= floor.value),
      assert(ceiling == null || ceiling.value < double.infinity);

  @override
  final Kg floor;

  /// The one increment this ladder has.
  final Kg step;

  /// Heaviest load available, when the rack or the stack runs out.
  final Kg? ceiling;

  static const double _tolerance = 1e-6;

  @override
  Kg get smallestStep => step;

  @override
  Kg stepAt(Kg load) => step;

  @override
  bool isRepresentable(Kg load) {
    if (!load.isFinite || load < floor) return false;
    final top = ceiling;
    if (top != null && load > top) return false;
    final rungs = (load - floor).value / step.value;
    return (rungs - rungs.roundToDouble()).abs() <= _tolerance;
  }

  @override
  Kg snapDown(Kg load) {
    assert(load.isFinite);
    if (load <= floor) return floor;
    final rungs = ((load - floor).value / step.value + _tolerance)
        .floorToDouble();
    return _cap(floor + step * rungs);
  }

  @override
  Kg snapUp(Kg load) {
    assert(load.isFinite);
    if (load <= floor) return floor;
    final rungs = ((load - floor).value / step.value - _tolerance)
        .ceilToDouble();
    return _cap(floor + step * rungs);
  }

  @override
  Kg shift(Kg load, int steps) => _cap(snapDown(load) + step * steps);

  @override
  int stepsBetween(Kg from, Kg to) =>
      ((snapDown(to) - snapDown(from)).value / step.value).round();

  /// Clamps into the ladder's ends. Deliberately does **not** round the value —
  /// lb-derived rungs are irrational in kg, and rounding them would make
  /// `isRepresentable(snapDown(x))` false. Presentation rounding is the UI's job.
  Kg _cap(Kg load) {
    final top = ceiling;
    if (load < floor) return floor;
    if (top != null && load > top) return top;
    return load;
  }

  @override
  String toString() => 'ArithmeticLoads(${floor.value} + n×${step.value}kg)';
}

/// An explicit inventory, for the day a gym profile lists the dumbbells it owns.
/// Values are sorted and de-duplicated by the constructor's caller; ties would
/// break determinism.
final class ExplicitLoads implements AvailableLoads {
  ExplicitLoads(Iterable<Kg> loads)
    : _loads = List<Kg>.unmodifiable(
        loads.toList(growable: false)..sort((a, b) => a.compareTo(b)),
      ) {
    assert(
      _loads.length >= 2,
      'an equipment family needs at least two loads to define a step',
    );
    assert(_loads.every((load) => load.isFinite));
    assert(
      _loads.indexed.skip(1).every((entry) => entry.$2 > _loads[entry.$1 - 1]),
      'equipment loads must be unique',
    );
  }

  final List<Kg> _loads;

  @override
  Kg get floor => _loads.first;

  @override
  Kg get smallestStep {
    var smallest = _loads[1] - _loads[0];
    for (var i = 2; i < _loads.length; i++) {
      final gap = _loads[i] - _loads[i - 1];
      if (gap < smallest) smallest = gap;
    }
    return smallest;
  }

  @override
  Kg stepAt(Kg load) {
    final index = _indexAtOrBelow(load);
    if (index >= _loads.length - 1) return smallestStep;
    return _loads[index + 1] - _loads[index];
  }

  @override
  bool isRepresentable(Kg load) =>
      load.isFinite && _loads.any((candidate) => candidate.isCloseTo(load));

  @override
  Kg snapDown(Kg load) => _loads[_indexAtOrBelow(load)];

  @override
  Kg snapUp(Kg load) {
    assert(load.isFinite);
    for (final candidate in _loads) {
      if (candidate >= load || candidate.isCloseTo(load)) return candidate;
    }
    return _loads.last;
  }

  @override
  Kg shift(Kg load, int steps) =>
      _loads[(_indexAtOrBelow(load) + steps).clamp(0, _loads.length - 1)];

  @override
  int stepsBetween(Kg from, Kg to) =>
      _indexAtOrBelow(to) - _indexAtOrBelow(from);

  int _indexAtOrBelow(Kg load) {
    assert(load.isFinite);
    var index = 0;
    for (var i = 0; i < _loads.length; i++) {
      if (_loads[i] <= load || _loads[i].isCloseTo(load)) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  @override
  String toString() =>
      'ExplicitLoads(${_loads.map((l) => l.value).join(', ')}kg)';
}

/// One market's worth of equipment steps (§3 "Weight increments").
///
/// A "step" is one *whole* increment as she would make it: the next pair of
/// dumbbells up, one pin, or both sides of the bar.
final class EquipmentLoadTable {
  factory EquipmentLoadTable({
    required Kg barbellBar,
    required Kg barbellUpperStep,
    required Kg barbellLowerStep,
    required Kg dumbbellFloor,
    required Kg dumbbellStep,
    required Kg machineFloor,
    required Kg machineStep,
    required Kg assistedStackMaxAssistance,
    required Kg assistedStackStep,
    required Kg cableFloor,
    required Kg cableStep,
    required Kg addedLoadStep,
  }) {
    assert(barbellBar.isFinite && barbellBar.isPositive);
    assert(barbellUpperStep.isFinite && barbellUpperStep.isPositive);
    assert(barbellLowerStep.isFinite && barbellLowerStep.isPositive);
    assert(dumbbellFloor.isFinite && dumbbellFloor.isPositive);
    assert(dumbbellStep.isFinite && dumbbellStep.isPositive);
    assert(machineFloor.isFinite && machineFloor.isPositive);
    assert(machineStep.isFinite && machineStep.isPositive);
    assert(
      assistedStackMaxAssistance.isFinite &&
          assistedStackMaxAssistance.isPositive,
    );
    assert(assistedStackStep.isFinite && assistedStackStep.isPositive);
    assert(cableFloor.isFinite && cableFloor.isPositive);
    assert(cableStep.isFinite && cableStep.isPositive);
    assert(addedLoadStep.isFinite && addedLoadStep.isPositive);
    return EquipmentLoadTable.trusted(
      barbellBar: barbellBar,
      barbellUpperStep: barbellUpperStep,
      barbellLowerStep: barbellLowerStep,
      dumbbellFloor: dumbbellFloor,
      dumbbellStep: dumbbellStep,
      machineFloor: machineFloor,
      machineStep: machineStep,
      assistedStackMaxAssistance: assistedStackMaxAssistance,
      assistedStackStep: assistedStackStep,
      cableFloor: cableFloor,
      cableStep: cableStep,
      addedLoadStep: addedLoadStep,
    );
  }

  /// For compile-time shipped constants whose values are reviewed in this
  /// library. Runtime-authored tables use the validating default factory.
  const EquipmentLoadTable.trusted({
    required this.barbellBar,
    required this.barbellUpperStep,
    required this.barbellLowerStep,
    required this.dumbbellFloor,
    required this.dumbbellStep,
    required this.machineFloor,
    required this.machineStep,
    required this.assistedStackMaxAssistance,
    required this.assistedStackStep,
    required this.cableFloor,
    required this.cableStep,
    required this.addedLoadStep,
  });

  /// The empty bar. §7's calibration floor for barbell movements.
  final Kg barbellBar;

  /// +2.5 kg total (2 × 1.25) in the metric market.
  final Kg barbellUpperStep;

  /// +5 kg total (2 × 2.5) in the metric market.
  final Kg barbellLowerStep;

  final Kg dumbbellFloor;

  /// The next pair up — 2 kg metric, 5 lb imperial. Commercial gyms rarely have
  /// 1 kg steps.
  final Kg dumbbellStep;

  /// The lowest pin.
  final Kg machineFloor;

  /// One pin. Varies by machine — [LoadProfile.loadStepOverride] wins when known.
  final Kg machineStep;

  /// Magnitude of the largest available assistance. The actual external-load
  /// floor is its negative; zero is the unassisted ceiling.
  final Kg assistedStackMaxAssistance;

  /// One assistance pin. Progression moves up by this amount, toward zero.
  final Kg assistedStackStep;

  final Kg cableFloor;
  final Kg cableStep;

  /// Load added to a bodyweight movement (a dumbbell between the feet, a plate on
  /// the hips). Floor is zero: bodyweight alone is always representable.
  final Kg addedLoadStep;

  /// The available-load set for [profile]. [LoadProfile.loadStepOverride] replaces
  /// the family step when the machine's real pin size is authored.
  AvailableLoads loadsFor(LoadProfile profile) {
    final override = profile.loadStepOverride;
    assert(override == null || (override.isFinite && override.isPositive));
    switch (profile.resistanceEquipment) {
      case ResistanceEquipment.barbell:
        return ArithmeticLoads(
          floor: barbellBar,
          step:
              override ??
              (profile.movementClass.isLowerBody
                  ? barbellLowerStep
                  : barbellUpperStep),
        );
      case ResistanceEquipment.dumbbell:
        return ArithmeticLoads(
          floor: dumbbellFloor,
          step: override ?? dumbbellStep,
        );
      case ResistanceEquipment.machine:
        return ArithmeticLoads(
          floor: override ?? machineFloor,
          step: override ?? machineStep,
        );
      case ResistanceEquipment.assistedStack:
        return ArithmeticLoads(
          floor: -assistedStackMaxAssistance,
          step: override ?? assistedStackStep,
          ceiling: Kg.zero,
        );
      case ResistanceEquipment.cable:
        return ArithmeticLoads(
          floor: override ?? cableFloor,
          step: override ?? cableStep,
        );
      case ResistanceEquipment.bodyweight:
        return ArithmeticLoads(floor: Kg.zero, step: override ?? addedLoadStep);
    }
  }

  @override
  String toString() =>
      'EquipmentLoadTable(bar ${barbellBar.value}kg, '
      'db ${dumbbellStep.value}kg, machine ${machineStep.value}kg, '
      'assisted ${assistedStackStep.value}kg)';
}
