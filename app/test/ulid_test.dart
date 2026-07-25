import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/core/ulid.dart';

void main() {
  test('ULIDs sort lexicographically by timestamp', () {
    final generator = UlidGenerator(random: Random(1));
    final earlier = generator.generate(
      timestamp: DateTime.utc(2026, 7, 25, 10, 0, 0, 1),
    );
    final later = generator.generate(
      timestamp: DateTime.utc(2026, 7, 25, 10, 0, 0, 2),
    );

    expect(earlier.length, 26);
    expect(later.length, 26);
    expect(earlier.compareTo(later), lessThan(0));
  });

  test('ULIDs are unique within one millisecond', () {
    final generator = UlidGenerator(random: Random(2));
    final timestamp = DateTime.utc(2026, 7, 25);
    final ids = {
      for (var index = 0; index < 1000; index++)
        generator.generate(timestamp: timestamp),
    };

    expect(ids, hasLength(1000));
  });
}
