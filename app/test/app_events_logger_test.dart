import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/data/analytics/app_events_logger.dart';
import 'package:womens_gym/data/db/schema.dart';
import 'package:womens_gym/data/sync/outbox_repository.dart';

void main() {
  test('event schemas expose only their explicit privacy allowlists', () {
    final sink = _RecordingSink();
    var sequence = 0;
    final logger = AppEventsLogger(
      sink,
      () => DateTime.utc(2026, 7, 26, 10),
      () =>
          '00000000-0000-4000-8000-${(++sequence).toString().padLeft(12, '0')}',
    );

    logger.onboardingStepCompleted(3);
    logger.planGenerated(
      days: 3,
      minutes: 45,
      goal: engine.Goal.stronger,
      emphasis: engine.Emphasis.glutes,
    );
    logger.sessionStarted();
    logger.setLogged();
    logger.effortReported(engine.EffortLevel.justRight);
    logger.swapUsed(reason: engine.SwapReason.busy, tier: 2);
    logger.sessionCompleted(durationMinutes: 41, exercises: 6);
    logger.sessionAbandoned();
    logger.comebackShown(2);

    expect(sink.entries, hasLength(9));
    const forbiddenFragments = <String>[
      'cycle',
      'menstrual',
      'period',
      'body_mass',
      'weight',
      'load',
      'reps',
    ];
    for (final entry in sink.entries) {
      expect(entry.targetTable, 'app_events');
      final name = entry.payload['name']! as String;
      final props = (entry.payload['props']! as Map<Object?, Object?>)
          .cast<String, Object?>();
      expect(
        props.keys.where(
          (key) => !AppEventsLogger.allowedPropsByEvent[name]!.contains(key),
        ),
        isEmpty,
      );
      for (final key in props.keys) {
        expect(
          forbiddenFragments.any(key.toLowerCase().contains),
          isFalse,
          reason: '$name must not include $key',
        );
      }
    }
  });
}

final class _RecordingSink implements OutboxSink {
  final entries = <_Entry>[];

  @override
  Future<void> enqueue({
    required String targetTable,
    required String rowId,
    required Map<String, Object?> payload,
    OutboxOperation operation = OutboxOperation.update,
  }) async {
    entries.add(_Entry(targetTable, rowId, payload));
  }
}

final class _Entry {
  const _Entry(this.targetTable, this.rowId, this.payload);

  final String targetTable;
  final String rowId;
  final Map<String, Object?> payload;
}
