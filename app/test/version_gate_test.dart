import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/core/version_gate.dart';

void main() {
  test('version comparison table', () {
    const cases = <(String, String, int)>[
      ('1.0.0', '1.0.0', 0),
      ('1.0', '1.0.0', 0),
      ('1.10.0', '1.9.9', 1),
      ('2.0.0', '10.0.0', -1),
      ('v2.1.0+42', '2.1.0+7', 0),
      ('2.1.0-beta.2', '2.1.0-beta.11', -1),
      ('2.1.0-rc.1', '2.1.0', -1),
      ('2.1.1', '2.1.0', 1),
    ];

    for (final (left, right, expectedSign) in cases) {
      expect(
        compareVersions(left, right).sign,
        expectedSign,
        reason: '$left compared with $right',
      );
    }
  });

  test('version comparison rejects malformed versions', () {
    expect(
      () => compareVersions('not-a-version', '1.0.0'),
      throwsFormatException,
    );
  });

  test('throwing remote fails open', () async {
    final gate = FailOpenVersionGate(
      remote: _ThrowingRemote(),
      cache: _MemoryCache(),
      timeout: const Duration(milliseconds: 10),
    );

    final result = await gate.check(currentVersion: '1.0.0');

    expect(result.isBlocked, isFalse);
    expect(result.updateRecommended, isFalse);
  });
}

final class _ThrowingRemote implements VersionGateRemote {
  @override
  Future<VersionGateConfig> fetch() => Future.error(StateError('offline'));
}

final class _MemoryCache implements VersionGateCache {
  VersionGateConfig? value;

  @override
  Future<VersionGateConfig?> read() async => value;

  @override
  Future<void> write(VersionGateConfig config) async {
    value = config;
  }
}
