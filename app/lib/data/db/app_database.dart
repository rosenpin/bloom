import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:programming_engine/programming_engine.dart';

import 'schema.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Profiles,
    Plans,
    SessionRecords,
    SessionEvents,
    Exercises,
    ExerciseCopy,
    SwapEdges,
    UserExercisePrefs,
    Outbox,
    SyncCursors,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS session_events_no_update
        BEFORE UPDATE ON session_events
        BEGIN
          SELECT RAISE(ABORT, 'session_events is append-only');
        END
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS session_events_no_delete
        BEFORE DELETE ON session_events
        BEGIN
          SELECT RAISE(ABORT, 'session_events is append-only');
        END
      ''');
    },
  );

  Future<int> appendSessionEvent(SessionEventsCompanion event) =>
      into(sessionEvents).insert(event, mode: InsertMode.insert);

  Future<List<SessionEventRow>> sessionEventLog(String sessionId) {
    final query = select(sessionEvents)
      ..where((event) => event.sessionId.equals(sessionId))
      ..orderBy([(event) => OrderingTerm.asc(event.seq)]);
    return query.get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/womens_gym.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
