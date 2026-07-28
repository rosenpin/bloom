import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/data/db/app_database.dart';
import 'package:womens_gym/data/db/schema.dart';
import 'package:womens_gym/features/session/data/exercise_content_repository.dart';
import 'package:womens_gym/features/session/data/session_event_codec.dart';

import 'support/session_test_support.dart';

void main() {
  test('every engine event round-trips through the Drift payload mapping', () {
    final events = <engine.SessionEvent>[
      engine.SetCompleted(
        exerciseId: 'dumbbell-goblet-squat',
        setIndex: 1,
        load: engine.Kg(12),
        reps: 11,
        unitSystem: engine.UnitSystem.imperial,
        targetReps: 10,
        targetRpe: 7,
        prescribedLoad: engine.Kg(10),
      ),
      engine.EffortReported(
        exerciseId: 'dumbbell-goblet-squat',
        level: engine.EffortLevel.harderThanIdLike,
      ),
      engine.SwapRequested(
        exerciseId: 'dumbbell-goblet-squat',
        reason: engine.SwapReason.busy,
      ),
      engine.Shorten(20),
      engine.LowEnergy(),
      engine.PainReported(
        exerciseId: 'dumbbell-goblet-squat',
        site: engine.PainSite.knee,
      ),
      engine.SessionAbandoned(),
    ];

    for (final event in events) {
      final encoded = SessionEventCodec.encode(event);
      final decoded = SessionEventCodec.decodePayload(
        type: encoded.type,
        payloadJson: encoded.payloadJson,
        unitSystemAtEntry: event is engine.SetCompleted
            ? event.unitSystem
            : engine.UnitSystem.metric,
      );
      expect(decoded, event);
    }
  });

  test('stored event garbage has one boundary decode error', () {
    final invalidPayloads = <(StoredSessionEventType, String)>[
      (
        StoredSessionEventType.setCompleted,
        '{"exerciseId":"squat","setIndex":0,"loadKg":1e999,"reps":8}',
      ),
      (
        StoredSessionEventType.setCompleted,
        '{"exerciseId":"squat","setIndex":0,"loadKg":10,"reps":0}',
      ),
      (
        StoredSessionEventType.effortReported,
        '{"exerciseId":"squat","level":0}',
      ),
      (
        StoredSessionEventType.swapRequested,
        '{"exerciseId":"squat","reason":"surprise"}',
      ),
      (
        StoredSessionEventType.painReported,
        '{"exerciseId":"squat","site":"surprise"}',
      ),
    ];

    for (final (type, payloadJson) in invalidPayloads) {
      expect(
        () => SessionEventCodec.decodePayload(
          type: type,
          payloadJson: payloadJson,
          unitSystemAtEntry: engine.UnitSystem.metric,
        ),
        throwsA(isA<SessionEventDecodeError>()),
      );
    }
  });

  test(
    'content seeding rejects a dangling swap at the load boundary',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final source = engine.catalogV1.exercises.first;
      final invalidCatalog = engine.ContentCatalogData(
        contentVersion: 'invalid-test-catalog',
        exercises: [source],
        swapEdges: [
          engine.SwapEdge(
            fromId: source.id,
            toId: 'missing-exercise',
            tier: 1,
            rank: 0,
          ),
        ],
        rotatingBlockRoles: const [],
      );
      expect(
        () => ExerciseContentSeeder(
          database,
          invalidCatalog,
          () => DateTime.utc(2026, 7, 27),
        ),
        throwsA(isA<ContentCatalogLoadError>()),
      );
    },
  );

  test(
    'stored lifecycle events are exactly the events replayed and folded',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.utc(2026, 7, 26, 10);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      await storeSessionTestPlan(container);

      final seeder = container.read(exerciseContentSeederProvider);
      await Future.wait([seeder.seedIfEmpty(), seeder.seedIfEmpty()]);
      final service = container.read(sessionLifecycleServiceProvider);
      var runtime = (await service.startOrResume())!;
      final entry = runtime.activeEntry!;
      final guidance = await container
          .read(exerciseContentRepositoryProvider)
          .loadGuidance(entry.exerciseId);
      expect(guidance, isNotNull);
      expect(guidance!.setupSteps, isNotEmpty);
      expect(
        guidance.swaps.map((swap) => swap.exerciseId),
        contains('bodyweight-squat'),
      );
      final suggestion =
          entry.prescription.suggestion as engine.NeedsCalibration;
      final dose = entry.prescription.dose as engine.RepsDose;
      runtime = await service.advance(
        runtime,
        engine.SetCompleted(
          exerciseId: entry.exerciseId,
          setIndex: 0,
          load: suggestion.floor,
          reps: suggestion.probeReps,
          unitSystem: engine.UnitSystem.metric,
          targetReps: dose.targetReps,
          targetRpe: dose.effort.rpe,
          prescribedLoad: suggestion.floor,
        ),
      );
      runtime = await service.advance(
        runtime,
        engine.EffortReported(
          exerciseId: entry.exerciseId,
          level: engine.EffortLevel.justRight,
        ),
      );
      runtime = await service.advance(
        runtime,
        engine.PainReported(
          exerciseId: entry.exerciseId,
          site: engine.PainSite.knee,
        ),
      );
      runtime = await service.advance(runtime, const engine.SessionAbandoned());

      final rows = await database.sessionEventLog(runtime.sessionId);
      final decoded = rows.map(SessionEventCodec.decode).toList();
      final history = await service.loadHistory(
        unitSystem: engine.UnitSystem.metric,
      );
      final record = await (database.select(
        database.sessionRecords,
      )..where((row) => row.id.equals(runtime.sessionId))).getSingle();

      expect(decoded, runtime.state.events);
      expect(history.records.single.events, runtime.state.events);
      expect(record.abandonedAt, isNotNull);
      expect(record.completedAt, isNull);
      expect(
        decoded.whereType<engine.SetCompleted>().single.prescribedLoad,
        suggestion.floor,
      );

      final folded = engine.foldTrainingHistory(history);
      expect(folded.exercise(entry.exerciseId).everSeen, isTrue);
      expect(
        folded.exercise(entry.exerciseId).lastEffort,
        engine.EffortLevel.justRight,
      );
      expect(folded.excludedExerciseIds, contains(entry.exerciseId));
    },
  );

  test(
    'completed session queries use the latest write for each set index',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.utc(2026, 7, 26, 10);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      final document = await storeSessionTestPlan(container);
      await database
          .into(database.sessionRecords)
          .insert(
            SessionRecordRow(
              id: 'completed-history-session',
              planId: document.row.id,
              planRef: document.plan.reference,
              dayIndex: 1,
              mesocycleIndex: 1,
              mesocycleWeekIndex: 1,
              absoluteWeekIndex: 1,
              weekKind: engine.MesocycleWeekKind.build,
              startedAt: now,
              completedAt: now.add(const Duration(minutes: 44)),
            ),
          );

      final events = <engine.SessionEvent>[
        engine.SetCompleted(
          exerciseId: 'dumbbell-goblet-squat',
          setIndex: 0,
          load: engine.Kg(10),
          reps: 10,
          unitSystem: engine.UnitSystem.metric,
          targetReps: 10,
          targetRpe: 7,
          prescribedLoad: engine.Kg(10),
        ),
        engine.SetCompleted(
          exerciseId: 'dumbbell-goblet-squat',
          setIndex: 0,
          load: engine.Kg(12),
          reps: 10,
          unitSystem: engine.UnitSystem.metric,
          targetReps: 10,
          targetRpe: 7,
          prescribedLoad: engine.Kg(10),
        ),
        engine.SetCompleted(
          exerciseId: 'dumbbell-goblet-squat',
          setIndex: 1,
          load: engine.Kg(12),
          reps: 8,
          unitSystem: engine.UnitSystem.metric,
          targetReps: 10,
          targetRpe: 7,
          prescribedLoad: engine.Kg(12),
        ),
        engine.SwapRequested(
          exerciseId: 'dumbbell-goblet-squat',
          reason: engine.SwapReason.busy,
        ),
        engine.SetCompleted(
          exerciseId: 'bodyweight-squat',
          setIndex: 0,
          load: engine.Kg.zero,
          reps: 10,
          unitSystem: engine.UnitSystem.metric,
          targetReps: 10,
          targetRpe: 7,
          prescribedLoad: engine.Kg.zero,
        ),
        engine.EffortReported(
          exerciseId: 'dumbbell-goblet-squat',
          level: engine.EffortLevel.justRight,
        ),
      ];
      for (var index = 0; index < events.length; index++) {
        final encoded = SessionEventCodec.encode(events[index]);
        await database
            .into(database.sessionEvents)
            .insert(
              SessionEventRow(
                id: 'completed-history-event-$index',
                sessionId: 'completed-history-session',
                seq: index,
                type: encoded.type,
                payloadJson: encoded.payloadJson,
                recordedAt: now.add(Duration(minutes: index + 1)),
                unitSystemAtEntry: engine.UnitSystem.metric,
              ),
            );
      }

      final service = container.read(sessionLifecycleServiceProvider);
      final history = await service.completedSessions();
      final detail = await service.completedSession(
        'completed-history-session',
      );
      final preview = await service.preview();

      expect(history, hasLength(1));
      expect(detail, isNotNull);
      expect(detail!.latestSets, hasLength(3));
      expect(detail.totalLoad, engine.Kg(216));
      expect(detail.duration, const Duration(minutes: 44));
      expect(detail.lastEffort, engine.EffortLevel.justRight);
      expect(detail.swappedExerciseIds, contains('bodyweight-squat'));
      expect(preview!.completedToday?.record.id, 'completed-history-session');
    },
  );
}
