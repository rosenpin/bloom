import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/ulid.dart';
import '../../../data/analytics/app_events_logger.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/schema.dart';
import '../../../data/sync/outbox_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/onboarding_answers.dart';
import '../../plan/data/plan_repository.dart';
import '../../plan/domain/stored_plan_document.dart';
import '../data/exercise_content_repository.dart';
import '../data/session_event_codec.dart';

final class PreviousSessionMemory {
  const PreviousSessionMemory({
    required this.minutes,
    required this.completedSets,
    required this.lastEffort,
  });

  final int minutes;
  final int completedSets;
  final engine.EffortLevel? lastEffort;
}

final class SessionPreview {
  const SessionPreview({
    required this.document,
    required this.answers,
    required this.state,
    required this.history,
    required this.previousMemory,
    required this.unitPromptSeen,
  });

  final StoredPlanDocument document;
  final OnboardingAnswers answers;
  final engine.SessionState state;
  final engine.TrainingHistory history;
  final PreviousSessionMemory? previousMemory;
  final bool unitPromptSeen;

  engine.PlanDay get day => document.plan.days.firstWhere(
    (day) => day.dayIndex == state.dayIndex,
    orElse: () => document.plan.days.first,
  );

  Duration get restDuration =>
      state.config.repSchemes[answers.goal]?.rest ??
      const Duration(seconds: 75);

  bool get isComeback =>
      state.reasonCodes.contains(engine.ReasonCode.layoffTier1) ||
      state.reasonCodes.contains(engine.ReasonCode.layoffTier2) ||
      state.reasonCodes.contains(engine.ReasonCode.layoffTier3);
}

final class SessionRuntime {
  SessionRuntime({
    required this.sessionId,
    required this.startedAt,
    required this.document,
    required this.answers,
    required this.state,
    required this.history,
    required this.previousMemory,
    required this.unitPromptSeen,
    required this.displayUnitSystem,
    Map<String, engine.Kg> loadOverrides = const <String, engine.Kg>{},
  }) : loadOverrides = Map<String, engine.Kg>.unmodifiable(loadOverrides);

  factory SessionRuntime.fromPreview({
    required String sessionId,
    required DateTime startedAt,
    required SessionPreview preview,
  }) => SessionRuntime(
    sessionId: sessionId,
    startedAt: startedAt,
    document: preview.document,
    answers: preview.answers,
    state: preview.state,
    history: preview.history,
    previousMemory: preview.previousMemory,
    unitPromptSeen: preview.unitPromptSeen,
    displayUnitSystem: preview.answers.unitSystem,
  );

  final String sessionId;
  final DateTime startedAt;
  final StoredPlanDocument document;
  final OnboardingAnswers answers;
  final engine.SessionState state;
  final engine.TrainingHistory history;
  final PreviousSessionMemory? previousMemory;
  final bool unitPromptSeen;
  final engine.UnitSystem displayUnitSystem;
  final Map<String, engine.Kg> loadOverrides;

  engine.PlanDay get day => document.plan.days.firstWhere(
    (day) => day.dayIndex == state.dayIndex,
    orElse: () => document.plan.days.first,
  );

  Duration get restDuration =>
      state.config.repSchemes[answers.goal]?.rest ??
      const Duration(seconds: 75);

  bool get isComeback =>
      state.reasonCodes.contains(engine.ReasonCode.layoffTier1) ||
      state.reasonCodes.contains(engine.ReasonCode.layoffTier2) ||
      state.reasonCodes.contains(engine.ReasonCode.layoffTier3);

  bool get isComplete =>
      !state.isAbandoned &&
      state.exercises.isNotEmpty &&
      state.exercises.every((entry) => entry.isTerminal);

  engine.SessionExerciseEntry? get activeEntry {
    for (final entry in state.exercises) {
      if (!entry.isTerminal) return entry;
    }
    return null;
  }

  SessionRuntime copyWith({
    StoredPlanDocument? document,
    OnboardingAnswers? answers,
    engine.SessionState? state,
    bool? unitPromptSeen,
    engine.UnitSystem? displayUnitSystem,
    Map<String, engine.Kg>? loadOverrides,
  }) => SessionRuntime(
    sessionId: sessionId,
    startedAt: startedAt,
    document: document ?? this.document,
    answers: answers ?? this.answers,
    state: state ?? this.state,
    history: history,
    previousMemory: previousMemory,
    unitPromptSeen: unitPromptSeen ?? this.unitPromptSeen,
    displayUnitSystem: displayUnitSystem ?? this.displayUnitSystem,
    loadOverrides: loadOverrides ?? this.loadOverrides,
  );
}

final class SessionRecap {
  const SessionRecap({
    required this.totalLoad,
    required this.completedThisWeek,
    required this.plannedThisWeek,
    required this.totalSessions,
    required this.duration,
    required this.weekStreak,
  });

  final engine.Kg totalLoad;
  final int completedThisWeek;
  final int plannedThisWeek;
  final int totalSessions;
  final Duration duration;
  final int? weekStreak;
}

final class SessionLifecycleService {
  const SessionLifecycleService(
    this._database,
    this._planRepository,
    this._onboardingRepository,
    this._contentSeeder,
    this._ulid,
    this._clock,
    this._outbox,
    this._events,
    this._requestSync, [
    this._config = const engine.ProgrammingConfig(),
  ]);

  final AppDatabase _database;
  final PlanRepository _planRepository;
  final OnboardingRepository _onboardingRepository;
  final ExerciseContentSeeder _contentSeeder;
  final UlidGenerator _ulid;
  final DateTime Function() _clock;
  final engine.ProgrammingConfig _config;
  final OutboxSink _outbox;
  final AppEventsLogger _events;
  final void Function() _requestSync;

  Future<SessionPreview?> preview() async {
    await _contentSeeder.seedIfEmpty();
    final document = await _planRepository.loadLatest();
    final answers = await _onboardingRepository.load();
    if (document == null || answers == null) return null;
    final history = await loadHistory(unitSystem: answers.unitSystem);
    final state = engine.resolveSession(
      document.plan,
      history,
      _clock(),
      config: _config,
    );
    return SessionPreview(
      document: document,
      answers: answers,
      state: state,
      history: history,
      previousMemory: await _previousMemory(),
      unitPromptSeen: await _unitPromptSeen(),
    );
  }

  Future<SessionRuntime?> startOrResume() async {
    await _contentSeeder.seedIfEmpty();
    final openQuery = _database.select(_database.sessionRecords)
      ..where((row) => row.completedAt.isNull() & row.abandonedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
      ..limit(1);
    final open = await openQuery.getSingleOrNull();
    if (open != null) {
      final document = await _planRepository.loadById(open.planId);
      final answers = await _onboardingRepository.load();
      if (document == null || answers == null) return null;
      final history = await loadHistory(
        unitSystem: answers.unitSystem,
        excludingSessionId: open.id,
      );
      var state = engine.resolveSession(
        document.plan,
        history,
        open.startedAt,
        config: _config,
      );
      for (final row in await _database.sessionEventLog(open.id)) {
        state = _reduce(state, SessionEventCodec.decode(row));
      }
      return SessionRuntime(
        sessionId: open.id,
        startedAt: open.startedAt,
        document: document,
        answers: answers,
        state: state,
        history: history,
        previousMemory: await _previousMemory(excludingSessionId: open.id),
        unitPromptSeen: await _unitPromptSeen(),
        displayUnitSystem: answers.unitSystem,
      );
    }

    final previewValue = await preview();
    if (previewValue == null || previewValue.state.exercises.isEmpty) {
      return null;
    }
    final startedAt = _clock();
    final sessionId = _ulid.generate(timestamp: startedAt);
    final state = previewValue.state;
    final row = SessionRecordRow(
      id: sessionId,
      planId: previewValue.document.row.id,
      planRef: state.planRef,
      dayIndex: state.dayIndex,
      mesocycleIndex: state.mesocycleIndex,
      mesocycleWeekIndex: state.mesocycleWeekIndex,
      absoluteWeekIndex: state.absoluteWeekIndex,
      weekKind: state.weekKind,
      startedAt: startedAt,
      completedAt: null,
      abandonedAt: null,
    );
    await _database.transaction(() async {
      await _database.into(_database.sessionRecords).insert(row);
      await _outbox.enqueue(
        targetTable: 'session_records',
        rowId: row.id,
        payload: _sessionRecordPayload(row),
      );
    });
    final runtime = SessionRuntime.fromPreview(
      sessionId: sessionId,
      startedAt: startedAt,
      preview: previewValue,
    );
    _events.sessionStarted();
    if (runtime.isComeback) {
      _events.comebackShown(_comebackTier(runtime.state.reasonCodes));
    }
    return runtime;
  }

  Future<SessionRuntime> advance(
    SessionRuntime runtime,
    engine.SessionEvent event,
  ) async {
    final nextState = _reduce(runtime.state, event);
    final encoded = SessionEventCodec.encode(event);
    final recordedAt = _clock();
    final unitSystemAtEntry = event is engine.SetCompleted
        ? event.unitSystem
        : runtime.displayUnitSystem;
    final eventId = _ulid.generate(timestamp: recordedAt);
    final completed =
        !runtime.isComplete &&
        nextState.exercises.isNotEmpty &&
        nextState.exercises.every((entry) => entry.isTerminal);

    await _database.transaction(() async {
      await _database.appendSessionEvent(
        SessionEventsCompanion.insert(
          id: eventId,
          sessionId: runtime.sessionId,
          seq: runtime.state.events.length,
          type: encoded.type,
          payloadJson: encoded.payloadJson,
          recordedAt: recordedAt,
          unitSystemAtEntry: unitSystemAtEntry,
        ),
      );
      await _outbox.enqueue(
        targetTable: 'session_events',
        rowId: eventId,
        payload: {
          'id': eventId,
          'session_id': runtime.sessionId,
          'seq': runtime.state.events.length,
          'type': encoded.type.name,
          'payload': jsonDecode(encoded.payloadJson),
          'recorded_at': recordedAt.toUtc().toIso8601String(),
          'unit_system_at_entry': unitSystemAtEntry.name,
        },
      );

      if (event is engine.PainReported) {
        await _database
            .into(_database.userExercisePrefs)
            .insertOnConflictUpdate(
              UserExercisePrefsCompanion.insert(
                exerciseId: event.exerciseId,
                excluded: true,
                source: UserExercisePreferenceSource.pain,
                updatedAt: recordedAt,
              ),
            );
        await _outbox.enqueue(
          targetTable: 'user_exercise_prefs',
          rowId:
              '${event.exerciseId}|${UserExercisePreferenceSource.pain.name}',
          payload: {
            'exercise_id': event.exerciseId,
            'excluded': true,
            'source': UserExercisePreferenceSource.pain.name,
            'updated_at': recordedAt.toUtc().toIso8601String(),
          },
        );
      }

      if (event is engine.SessionAbandoned) {
        await (_database.update(_database.sessionRecords)
              ..where((row) => row.id.equals(runtime.sessionId)))
            .write(SessionRecordsCompanion(abandonedAt: Value(recordedAt)));
        final record = await (_database.select(
          _database.sessionRecords,
        )..where((row) => row.id.equals(runtime.sessionId))).getSingle();
        await _outbox.enqueue(
          targetTable: 'session_records',
          rowId: record.id,
          payload: _sessionRecordPayload(record),
        );
      } else if (completed) {
        await (_database.update(_database.sessionRecords)
              ..where((row) => row.id.equals(runtime.sessionId)))
            .write(SessionRecordsCompanion(completedAt: Value(recordedAt)));
        final record = await (_database.select(
          _database.sessionRecords,
        )..where((row) => row.id.equals(runtime.sessionId))).getSingle();
        await _outbox.enqueue(
          targetTable: 'session_records',
          rowId: record.id,
          payload: _sessionRecordPayload(record),
        );
      }
    });

    switch (event) {
      case engine.SetCompleted():
        _events.setLogged();
      case engine.EffortReported(:final level):
        _events.effortReported(level);
      case engine.SessionAbandoned():
        _events.sessionAbandoned();
      default:
        break;
    }
    if (completed) {
      _events.sessionCompleted(
        durationMinutes: recordedAt.difference(runtime.startedAt).inMinutes,
        exercises: nextState.exercises.length,
      );
      _requestSync();
    }
    return runtime.copyWith(state: nextState);
  }

  Future<SessionRuntime> swapToCandidate(
    SessionRuntime runtime,
    engine.PlanSwapCandidate candidate, {
    required engine.SwapReason reason,
  }) async {
    var next = runtime;
    final maximumAttempts =
        (runtime.activeEntry?.planExercise.orderedSwapCandidates.length ?? 0) +
        1;
    for (var attempt = 0; attempt < maximumAttempts; attempt++) {
      if (next.activeEntry?.exerciseId == candidate.exerciseId) return next;
      final sourceId =
          _pendingSwapSource(next.state) ?? next.activeEntry?.exerciseId;
      if (sourceId == null) return next;
      final before = next.activeEntry?.exerciseId;
      next = await advance(
        next,
        engine.SwapRequested(exerciseId: sourceId, reason: reason),
      );
      if (next.activeEntry?.exerciseId == candidate.exerciseId) {
        _events.swapUsed(reason: reason, tier: candidate.tier);
        return next;
      }
      if (next.activeEntry?.exerciseId == before &&
          _pendingSwapSource(next.state) == null) {
        return next;
      }
    }
    return next;
  }

  Future<SessionRuntime> keepSwap(
    SessionRuntime runtime,
    engine.PendingPlanEditSuggestion suggestion,
  ) async {
    if (suggestion is! engine.KeepSwapPlanEditSuggestion) return runtime;
    final edited = engine.applyPlanEdit(runtime.document.plan, suggestion.edit);
    final document = await _planRepository.update(runtime.document, edited);
    await _database.transaction(() async {
      await (_database.update(_database.sessionRecords)
            ..where((row) => row.id.equals(runtime.sessionId)))
          .write(SessionRecordsCompanion(planRef: Value(edited.reference)));
      final record = await (_database.select(
        _database.sessionRecords,
      )..where((row) => row.id.equals(runtime.sessionId))).getSingle();
      await _outbox.enqueue(
        targetTable: 'session_records',
        rowId: record.id,
        payload: _sessionRecordPayload(record),
      );
    });
    return runtime.copyWith(document: document);
  }

  Future<SessionRuntime> changeUnitSystem(
    SessionRuntime runtime,
    engine.UnitSystem unitSystem,
  ) async {
    await _onboardingRepository.update(
      (answers) => answers.copyWith(unitSystem: unitSystem),
    );
    await markUnitPromptSeen();
    return runtime.copyWith(
      answers: runtime.answers.copyWith(unitSystem: unitSystem),
      displayUnitSystem: unitSystem,
      unitPromptSeen: true,
    );
  }

  Future<SessionRuntime> markUnitPromptSeenForRuntime(
    SessionRuntime runtime,
  ) async {
    await markUnitPromptSeen();
    return runtime.copyWith(unitPromptSeen: true);
  }

  Future<void> markUnitPromptSeen() async {
    await _onboardingRepository.markUnitPromptSeen();
  }

  SessionRuntime overrideLoad(
    SessionRuntime runtime,
    String exerciseId,
    engine.Kg load,
  ) => runtime.copyWith(
    loadOverrides: <String, engine.Kg>{
      ...runtime.loadOverrides,
      exerciseId: load,
    },
  );

  SessionRuntime useUsualWeights(SessionRuntime runtime) {
    final overrides = <String, engine.Kg>{...runtime.loadOverrides};
    final snapshot = engine.foldTrainingHistory(runtime.history);
    for (final entry in runtime.state.exercises) {
      final history = snapshot.exercise(entry.exerciseId);
      final load = history.lastWorkingLoad ?? history.lastLoad;
      if (load != null) overrides[entry.exerciseId] = load;
    }
    return runtime.copyWith(loadOverrides: overrides);
  }

  Future<SessionRecap> recap(SessionRuntime runtime) async {
    var total = engine.Kg.zero;
    for (final event in runtime.state.events) {
      if (event is engine.SetCompleted) {
        total += event.load * event.reps;
      }
    }
    final rowsQuery = _database.select(_database.sessionRecords)
      ..where((row) => row.completedAt.isNotNull())
      ..orderBy([(row) => OrderingTerm.asc(row.startedAt)]);
    final rows = await rowsQuery.get();
    final currentWeekRows = rows.where(
      (row) =>
          row.planId == runtime.document.row.id &&
          row.absoluteWeekIndex == runtime.state.absoluteWeekIndex,
    );
    final completedWeeks = <int>{
      for (final row in rows)
        if (row.planId == runtime.document.row.id) row.absoluteWeekIndex,
    };
    int? streak;
    if (completedWeeks.isNotEmpty) {
      var value = runtime.state.absoluteWeekIndex;
      var count = 0;
      while (completedWeeks.contains(value)) {
        count++;
        value--;
      }
      if (count >= 2) streak = count;
    }
    final closedAt = rows
        .where((row) => row.id == runtime.sessionId)
        .firstOrNull
        ?.completedAt;
    return SessionRecap(
      totalLoad: total,
      completedThisWeek: currentWeekRows.length,
      plannedThisWeek: runtime.document.plan.days.length,
      totalSessions: rows.length,
      duration: (closedAt ?? _clock()).difference(runtime.startedAt),
      weekStreak: streak,
    );
  }

  Future<engine.TrainingHistory> loadHistory({
    required engine.UnitSystem unitSystem,
    String? excludingSessionId,
  }) async {
    final recordQuery = _database.select(_database.sessionRecords)
      ..where(
        (row) => row.completedAt.isNotNull() | row.abandonedAt.isNotNull(),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.startedAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    final rows = await recordQuery.get();
    final records = <engine.SessionRecord>[];
    for (final row in rows) {
      if (row.id == excludingSessionId) continue;
      final document = await _planRepository.loadById(row.planId);
      final planRef = row.planRef.isNotEmpty
          ? row.planRef
          : document?.plan.reference ?? row.planId;
      records.add(
        engine.SessionRecord(
          sessionId: row.id,
          date: row.startedAt,
          planRef: planRef,
          mesocycleIndex: row.mesocycleIndex,
          mesocycleWeekIndex: row.mesocycleWeekIndex,
          absoluteWeekIndex: row.absoluteWeekIndex,
          dayIndex: row.dayIndex,
          weekKind: row.weekKind,
          events: [
            for (final event in await _database.sessionEventLog(row.id))
              SessionEventCodec.decode(event),
          ],
        ),
      );
    }

    final preferenceQuery = _database.select(_database.userExercisePrefs)
      ..where((row) => row.excluded.equals(true));
    final preferences = await preferenceQuery.get();
    return engine.TrainingHistory(
      records: records,
      userExcludedExerciseIds: {
        for (final preference in preferences) preference.exerciseId,
      },
      unitSystem: unitSystem,
      bodyMass: engine.Kg.zero,
    );
  }

  Future<bool> _unitPromptSeen() async {
    final query = _database.select(_database.profiles)
      ..where((row) => row.id.equals('local'));
    return (await query.getSingleOrNull())?.unitPromptSeen ?? false;
  }

  Future<PreviousSessionMemory?> _previousMemory({
    String? excludingSessionId,
  }) async {
    final query = _database.select(_database.sessionRecords)
      ..where((row) => row.completedAt.isNotNull())
      ..orderBy([(row) => OrderingTerm.desc(row.completedAt)])
      ..limit(2);
    final rows = await query.get();
    SessionRecordRow? row;
    for (final candidate in rows) {
      if (candidate.id != excludingSessionId) {
        row = candidate;
        break;
      }
    }
    if (row == null) return null;
    final events = [
      for (final event in await _database.sessionEventLog(row.id))
        SessionEventCodec.decode(event),
    ];
    return PreviousSessionMemory(
      minutes: (row.completedAt ?? row.startedAt)
          .difference(row.startedAt)
          .inMinutes
          .clamp(1, 999),
      completedSets: events.whereType<engine.SetCompleted>().length,
      lastEffort: events.whereType<engine.EffortReported>().lastOrNull?.level,
    );
  }

  static engine.SessionState _reduce(
    engine.SessionState state,
    engine.SessionEvent event,
  ) {
    var input = state;
    String? acceptedPendingSource;
    if (event is engine.SwapRequested) {
      final pending = state.pendingSwapSuggestions
          .where((item) => item.sourceExerciseId == event.exerciseId)
          .firstOrNull;
      if (pending != null) {
        acceptedPendingSource = pending.sourceExerciseId;
        input = state.copyWith(
          exercises: [
            for (final entry in state.exercises)
              if (entry.exerciseId == pending.sourceExerciseId ||
                  entry.originalExerciseId == pending.sourceExerciseId)
                entry.copyWith(status: engine.SessionExerciseStatus.pending)
              else
                entry,
          ],
        );
      }
    }
    var reduced = engine.advanceSession(input, event);
    if (acceptedPendingSource != null) {
      reduced = reduced.copyWith(
        pendingSwapSuggestions: reduced.pendingSwapSuggestions.where(
          (item) => item.sourceExerciseId != acceptedPendingSource,
        ),
      );
    }
    return reduced;
  }

  static String? _pendingSwapSource(engine.SessionState state) =>
      state.pendingSwapSuggestions.firstOrNull?.sourceExerciseId;

  static Map<String, Object?> _sessionRecordPayload(SessionRecordRow row) => {
    'id': row.id,
    'plan_id': row.planId,
    'plan_ref': row.planRef,
    'day_index': row.dayIndex,
    'mesocycle_index': row.mesocycleIndex,
    'mesocycle_week_index': row.mesocycleWeekIndex,
    'absolute_week_index': row.absoluteWeekIndex,
    'week_kind': row.weekKind.name,
    'started_at': row.startedAt.toUtc().toIso8601String(),
    'completed_at': row.completedAt?.toUtc().toIso8601String(),
    'abandoned_at': row.abandonedAt?.toUtc().toIso8601String(),
  };

  static int _comebackTier(Iterable<engine.ReasonCode> codes) {
    if (codes.contains(engine.ReasonCode.layoffTier3)) return 3;
    if (codes.contains(engine.ReasonCode.layoffTier2)) return 2;
    return 1;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  T? get lastOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    var result = iterator.current;
    while (iterator.moveNext()) {
      result = iterator.current;
    }
    return result;
  }
}
