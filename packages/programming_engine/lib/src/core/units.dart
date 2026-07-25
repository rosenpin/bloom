/// Canonical load unit and the two markets we ship into.
///
/// Loads are stored and reasoned about in **kilograms, always**. The unit system
/// is a property of *the gym she trains in* (which plates and dumbbells exist),
/// not a display preference — which is why it lives in the engine at all. See
/// `ENGINE.md` › "Equipment-representable loads".
library;

/// Exact conversion factor (international pound).
const double kgPerLb = 0.45359237;

/// A load in kilograms. Never a raw `double`.
///
/// Equality and hashing come from the representation type, so `Kg(2.5)` equals
/// `Kg(2.5)` and can be used as a map key. Because floating-point loads are
/// derived from lb→kg conversions, **compare loads with [isCloseTo], not `==`**,
/// anywhere the value has been through arithmetic.
extension type const Kg(double value) {
  /// Bodyweight-only, or "no load added".
  static const Kg zero = Kg(0);

  /// Reads a load expressed in pounds. `const Kg(45 * kgPerLb)` where a const
  /// expression is needed.
  static Kg fromLb(double lb) => Kg(lb * kgPerLb);

  /// Display value in pounds. Conversion only — rounding is the UI's business.
  double get inLb => value / kgPerLb;

  Kg operator +(Kg other) => Kg(value + other.value);
  Kg operator -(Kg other) => Kg(value - other.value);
  Kg operator *(num factor) => Kg(value * factor);
  Kg operator /(num divisor) => Kg(value / divisor);
  Kg operator -() => Kg(-value);

  bool operator <(Kg other) => value < other.value;
  bool operator <=(Kg other) => value <= other.value;
  bool operator >(Kg other) => value > other.value;
  bool operator >=(Kg other) => value >= other.value;

  int compareTo(Kg other) => value.compareTo(other.value);

  Kg get abs => Kg(value.abs());
  bool get isZero => value == 0;
  bool get isPositive => value > 0;
  bool get isNegative => value < 0;
  bool get isFinite => value.isFinite;

  /// The fraction [other] represents of this load. Returns 0 for a zero base,
  /// so callers never divide by zero on a bodyweight movement.
  double fractionOf(Kg other) => other.value == 0 ? 0 : value / other.value;

  /// Tolerant comparison, in kilograms.
  bool isCloseTo(Kg other, {double tolerance = 1e-6}) =>
      (value - other.value).abs() <= tolerance;

  /// Rounds to a whole number of grams — enough to make lb-derived loads
  /// print and compare stably without pretending to more precision.
  Kg get roundedToGrams => Kg((value * 1000).roundToDouble() / 1000);
}

/// Which loads physically exist in her gym.
enum UnitSystem {
  /// Metric market: 2 kg dumbbell steps, 1.25/2.5 kg plates, 20 kg bar.
  metric,

  /// US/UK market: 5 lb dumbbell steps, 2.5/5 lb plates, 45 lb bar.
  imperial;

  bool get isMetric => this == UnitSystem.metric;
}
