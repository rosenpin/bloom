import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/data/db/schema.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'stores a profile and replays session events in sequence order',
    () async {
      final now = DateTime.utc(2026, 7, 25, 10);
      await database
          .into(database.profiles)
          .insert(
            ProfilesCompanion.insert(
              unitSystem: engine.UnitSystem.metric,
              quizAnswersJson: '{"daysPerWeek":3}',
              lastPeriodStart: Value(DateTime.utc(2026, 7, 1)),
              usualGapDays: const Value(28),
              updatedAt: now,
            ),
          );
      await database
          .into(database.plans)
          .insert(
            PlansCompanion.insert(
              id: '01K11K5YQ00000000000000000',
              documentJson: '{"days":[]}',
              engineVersion: 'engine-1',
              configHash: 'config-hash',
              contentHash: 'content-hash',
              profileHash: 'profile-hash',
              mesocycleIndex: 1,
              createdAt: now,
            ),
          );
      await database
          .into(database.sessionRecords)
          .insert(
            SessionRecordsCompanion.insert(
              id: '01K11K5YQ10000000000000000',
              planId: '01K11K5YQ00000000000000000',
              dayIndex: 1,
              startedAt: now,
            ),
          );

      await database.appendSessionEvent(
        SessionEventsCompanion.insert(
          id: '01K11K5YQ30000000000000000',
          sessionId: '01K11K5YQ10000000000000000',
          seq: 1,
          type: StoredSessionEventType.effortReported,
          payloadJson: '{"exerciseId":"goblet-squat","level":3}',
          recordedAt: now.add(const Duration(seconds: 2)),
          unitSystemAtEntry: engine.UnitSystem.metric,
        ),
      );
      await database.appendSessionEvent(
        SessionEventsCompanion.insert(
          id: '01K11K5YQ20000000000000000',
          sessionId: '01K11K5YQ10000000000000000',
          seq: 0,
          type: StoredSessionEventType.setCompleted,
          payloadJson:
              '{"exerciseId":"goblet-squat","setIndex":0,"loadKg":8,"reps":10}',
          recordedAt: now.add(const Duration(seconds: 1)),
          unitSystemAtEntry: engine.UnitSystem.metric,
        ),
      );

      final profile = await database.select(database.profiles).getSingle();
      final events = await database.sessionEventLog(
        '01K11K5YQ10000000000000000',
      );

      expect(profile.unitSystem, engine.UnitSystem.metric);
      expect(profile.usualGapDays, 28);
      expect(events.map((event) => event.seq), [0, 1]);
      expect(events.first.type, StoredSessionEventType.setCompleted);
      expect(events.last.type, StoredSessionEventType.effortReported);
    },
  );

  test('session event rows are guarded as append-only', () async {
    final now = DateTime.utc(2026, 7, 25, 10);
    await database
        .into(database.plans)
        .insert(
          PlansCompanion.insert(
            id: '01K11K5YQ00000000000000000',
            documentJson: '{}',
            engineVersion: 'engine-1',
            configHash: 'config-hash',
            contentHash: 'content-hash',
            profileHash: 'profile-hash',
            mesocycleIndex: 1,
            createdAt: now,
          ),
        );
    await database
        .into(database.sessionRecords)
        .insert(
          SessionRecordsCompanion.insert(
            id: '01K11K5YQ10000000000000000',
            planId: '01K11K5YQ00000000000000000',
            dayIndex: 1,
            startedAt: now,
          ),
        );
    await database.appendSessionEvent(
      SessionEventsCompanion.insert(
        id: '01K11K5YQ20000000000000000',
        sessionId: '01K11K5YQ10000000000000000',
        seq: 0,
        type: StoredSessionEventType.lowEnergy,
        payloadJson: '{}',
        recordedAt: now,
        unitSystemAtEntry: engine.UnitSystem.metric,
      ),
    );

    final update = database.update(database.sessionEvents)
      ..where((event) => event.id.equals('01K11K5YQ20000000000000000'));
    await expectLater(
      update.write(
        const SessionEventsCompanion(payloadJson: Value('{"changed":true}')),
      ),
      throwsA(anything),
    );
    expect(
      await database.sessionEventLog('01K11K5YQ10000000000000000'),
      hasLength(1),
    );
  });
}
