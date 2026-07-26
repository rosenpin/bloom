import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_repository.dart';
import '../domain/onboarding_answers.dart';

final class OnboardingRepository {
  const OnboardingRepository(this._database, this._clock, this._outbox);

  final AppDatabase _database;
  final DateTime Function() _clock;
  final OutboxSink _outbox;

  static engine.UnitSystem defaultUnitSystem(String? countryCode) =>
      countryCode?.toUpperCase() == 'US'
      ? engine.UnitSystem.imperial
      : engine.UnitSystem.metric;

  Future<OnboardingAnswers> ensureProfile({String? countryCode}) async {
    final existing = await _localProfile();
    if (existing != null) return _decode(existing);

    final answers = OnboardingAnswers(
      unitSystem: defaultUnitSystem(countryCode),
    );
    await save(answers);
    return answers;
  }

  Future<OnboardingAnswers?> load() async {
    final profile = await _localProfile();
    return profile == null ? null : _decode(profile);
  }

  Stream<OnboardingAnswers?> watch() {
    final query = _database.select(_database.profiles)
      ..where((profile) => profile.id.equals('local'));
    return query.watchSingleOrNull().map(
      (profile) => profile == null ? null : _decode(profile),
    );
  }

  Future<bool> hasCompletedProfile() async =>
      (await load())?.completed ?? false;

  Future<void> update(
    OnboardingAnswers Function(OnboardingAnswers current) transform, {
    String? countryCode,
  }) async {
    final current = await ensureProfile(countryCode: countryCode);
    await save(transform(current));
  }

  Future<void> save(OnboardingAnswers answers) async {
    final updatedAt = _clock().toUtc();
    await _database.transaction(() async {
      final unitPromptSeen = (await _localProfile())?.unitPromptSeen ?? false;
      await _database
          .into(_database.profiles)
          .insertOnConflictUpdate(
            ProfilesCompanion.insert(
              id: const Value('local'),
              unitSystem: answers.unitSystem,
              quizAnswersJson: answers.toJson(),
              lastPeriodStart: Value(answers.lastPeriodStart),
              usualGapDays: Value(answers.usualGapDays),
              updatedAt: updatedAt,
            ),
          );
      await _outbox.enqueue(
        targetTable: 'profiles',
        rowId: 'local',
        payload: _syncPayload(answers, updatedAt, unitPromptSeen),
      );
    });
  }

  Future<void> markUnitPromptSeen() async {
    final answers = await load();
    if (answers == null) return;
    final updatedAt = _clock().toUtc();
    await _database.transaction(() async {
      await (_database.update(
        _database.profiles,
      )..where((row) => row.id.equals('local'))).write(
        ProfilesCompanion(
          unitPromptSeen: const Value(true),
          updatedAt: Value(updatedAt),
        ),
      );
      await _outbox.enqueue(
        targetTable: 'profiles',
        rowId: 'local',
        payload: _syncPayload(answers, updatedAt, true),
      );
    });
  }

  Future<LocalProfile?> _localProfile() {
    final query = _database.select(_database.profiles)
      ..where((profile) => profile.id.equals('local'));
    return query.getSingleOrNull();
  }

  OnboardingAnswers _decode(LocalProfile profile) {
    final decoded = OnboardingAnswers.fromJson(
      profile.quizAnswersJson,
      fallbackUnitSystem: profile.unitSystem,
    );
    return decoded.copyWith(
      unitSystem: profile.unitSystem,
      lastPeriodStart: decoded.lastPeriodStart ?? profile.lastPeriodStart,
    );
  }

  static Map<String, Object?> _syncPayload(
    OnboardingAnswers answers,
    DateTime updatedAt,
    bool unitPromptSeen,
  ) => {
    'unit_system': answers.unitSystem.name,
    'quiz_answers': jsonDecode(answers.toJson()),
    'last_period_start': answers.lastPeriodStart
        ?.toUtc()
        .toIso8601String()
        .split('T')
        .first,
    'usual_gap_days': answers.usualGapDays,
    'unit_prompt_seen': unitPromptSeen,
    'updated_at': updatedAt.toIso8601String(),
  };
}
