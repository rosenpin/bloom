import 'package:drift/drift.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

enum StoredSessionEventType {
  setCompleted,
  effortReported,
  swapRequested,
  shorten,
  lowEnergy,
  painReported,
  sessionAbandoned,
}

enum UserExercisePreferenceSource { pain, user }

enum OutboxOperation { insert, update, delete }

@DataClassName('LocalProfile')
class Profiles extends Table {
  @override
  String get tableName => 'profile';

  TextColumn get id => text().withDefault(const Constant('local'))();
  TextColumn get unitSystem => textEnum<engine.UnitSystem>()();
  TextColumn get quizAnswersJson => text()();
  DateTimeColumn get lastPeriodStart => dateTime().nullable()();
  IntColumn get usualGapDays => integer().nullable()();
  BoolColumn get unitPromptSeen =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (id = 'local')",
    'CHECK (usual_gap_days IS NULL OR usual_gap_days > 0)',
  ];
}

@DataClassName('StoredPlan')
class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get documentJson => text()();
  TextColumn get engineVersion => text()();
  TextColumn get configHash => text()();
  TextColumn get contentHash => text()();
  TextColumn get profileHash => text()();
  IntColumn get mesocycleIndex => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (mesocycle_index >= 1)'];
}

@DataClassName('SessionRecordRow')
@TableIndex(name: 'session_records_plan', columns: {#planId})
class SessionRecords extends Table {
  TextColumn get id => text()();
  TextColumn get planId =>
      text().references(Plans, #id, onDelete: KeyAction.restrict)();
  TextColumn get planRef => text().withDefault(const Constant(''))();
  IntColumn get dayIndex => integer()();
  IntColumn get mesocycleIndex => integer().withDefault(const Constant(1))();
  IntColumn get mesocycleWeekIndex =>
      integer().withDefault(const Constant(1))();
  IntColumn get absoluteWeekIndex => integer().withDefault(const Constant(1))();
  TextColumn get weekKind => textEnum<engine.MesocycleWeekKind>().withDefault(
    const Constant('build'),
  )();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get abandonedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (day_index >= 1)',
    'CHECK (mesocycle_index >= 1)',
    'CHECK (mesocycle_week_index >= 1)',
    'CHECK (absolute_week_index >= 1)',
    'CHECK (completed_at IS NULL OR abandoned_at IS NULL)',
  ];
}

@DataClassName('SessionEventRow')
@TableIndex(
  name: 'session_events_session_seq',
  columns: {#sessionId, #seq},
  unique: true,
)
class SessionEvents extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(SessionRecords, #id, onDelete: KeyAction.restrict)();
  IntColumn get seq => integer()();
  TextColumn get type => textEnum<StoredSessionEventType>()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get unitSystemAtEntry => textEnum<engine.UnitSystem>()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (seq >= 0)'];
}

@DataClassName('ExerciseRow')
@TableIndex(name: 'exercises_block_role', columns: {#blockRole})
@TableIndex(name: 'exercises_retired_at', columns: {#retiredAt})
class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get slug => text()();
  TextColumn get name => text()();
  TextColumn get movementClass => textEnum<engine.MovementClass>()();
  TextColumn get blockRole => textEnum<engine.BlockRole>()();
  TextColumn get metricType => textEnum<engine.MetricType>()();
  TextColumn get laterality => textEnum<engine.Laterality>()();
  RealColumn get bwContribution => real()();
  RealColumn get loadStepOverrideKg => real().nullable()();
  TextColumn get resistanceEquipment =>
      textEnum<engine.ResistanceEquipment>()();
  TextColumn get supportEquipment => textEnum<engine.SupportEquipment>()();
  TextColumn get targetMusclesJson => text()();
  TextColumn get primaryJointActionsJson => text()();
  TextColumn get secondaryJointActionsJson => text()();
  IntColumn get romRank => integer()();
  IntColumn get stabilityRank => integer()();
  TextColumn get difficultyTier => textEnum<engine.DifficultyTier>()();
  TextColumn get minExperience => textEnum<engine.ExperienceTier>()();
  TextColumn get intimidationTier => textEnum<engine.IntimidationTier>()();
  TextColumn get ageEligibility => textEnum<engine.AgeEligibility>()();
  TextColumn get safetyEligibility => textEnum<engine.SafetyEligibility>()();
  BoolColumn get machineLeanOk => boolean()();
  BoolColumn get seatedVariant => boolean()();
  DateTimeColumn get retiredAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (bw_contribution BETWEEN 0 AND 1)',
    'CHECK (rom_rank BETWEEN 1 AND 5)',
    'CHECK (stability_rank BETWEEN 1 AND 5)',
  ];
}

@DataClassName('ExerciseCopyRow')
class ExerciseCopy extends Table {
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.restrict)();
  TextColumn get setupStepsJson => text()();
  TextColumn get shouldFeel => text()();
  TextColumn get stopIf => text()();
  TextColumn get findIt => text()();
  TextColumn get dosJson => text()();
  TextColumn get dontsJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId};
}

@DataClassName('SwapEdgeRow')
@TableIndex(
  name: 'swap_edges_rank',
  columns: {#fromId, #reason, #rank},
  unique: true,
)
class SwapEdges extends Table {
  @ReferenceName('outgoingSwapEdges')
  TextColumn get fromId =>
      text().references(Exercises, #id, onDelete: KeyAction.restrict)();
  @ReferenceName('incomingSwapEdges')
  TextColumn get toId =>
      text().references(Exercises, #id, onDelete: KeyAction.restrict)();
  TextColumn get reason => textEnum<engine.SwapReason>()();
  IntColumn get rank => integer()();
  IntColumn get tier => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {fromId, toId, reason};

  @override
  List<String> get customConstraints => [
    'CHECK (rank >= 0)',
    'CHECK (tier BETWEEN 1 AND 3)',
  ];
}

@DataClassName('UserExercisePrefRow')
class UserExercisePrefs extends Table {
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.restrict)();
  BoolColumn get excluded => boolean()();
  TextColumn get source => textEnum<UserExercisePreferenceSource>()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId, source};
}

@DataClassName('OutboxEntry')
@TableIndex(name: 'outbox_created_at', columns: {#createdAt})
class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get rowId => text()();
  TextColumn get op => textEnum<OutboxOperation>()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get targetTable => text().named('table_name')();
  DateTimeColumn get lastPulledAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {targetTable};
}
