import 'dart:math';

/// Small dependency-free ULID generator.
///
/// The first 10 Crockford Base32 characters encode milliseconds since epoch;
/// the final 16 are 80 random bits. Values therefore sort by timestamp. IDs
/// created in the same millisecond are intentionally not monotonic.
final class UlidGenerator {
  UlidGenerator({DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random.secure();

  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const _maxTimestamp = 0xFFFFFFFFFFFF;

  final DateTime Function() _clock;
  final Random _random;

  String generate({DateTime? timestamp}) {
    final millis = (timestamp ?? _clock()).toUtc().millisecondsSinceEpoch;
    if (millis < 0 || millis > _maxTimestamp) {
      throw RangeError.range(millis, 0, _maxTimestamp, 'timestamp');
    }

    final chars = List<String>.filled(26, '0');
    var remaining = millis;
    for (var index = 9; index >= 0; index--) {
      chars[index] = _alphabet[remaining & 31];
      remaining >>= 5;
    }
    for (var index = 10; index < chars.length; index++) {
      chars[index] = _alphabet[_random.nextInt(32)];
    }
    return chars.join();
  }
}
