import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart' as engine;
import 'package:womens_gym/core/providers.dart';
import 'package:womens_gym/data/db/app_database.dart';

import 'support/session_test_support.dart';

void main() {
  test('every user-data repository write enqueues its sync table', () async {
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

    final onboarding = container.read(onboardingRepositoryProvider);
    await onboarding.save(sessionTestAnswers());
    expect(await _targets(database), contains('profiles'));

    await database.delete(database.outbox).go();
    await storeSessionTestPlan(container);
    expect(await _targets(database), ['profiles', 'plans', 'profiles']);

    await database.delete(database.outbox).go();
    await container.read(exerciseContentSeederProvider).seedIfEmpty();
    final service = container.read(sessionLifecycleServiceProvider);
    final runtime = (await service.startOrResume())!;
    expect(await _targets(database), contains('session_records'));

    await Future<void>.delayed(Duration.zero);
    await database.delete(database.outbox).go();
    await service.advance(
      runtime,
      engine.PainReported(
        exerciseId: runtime.activeEntry!.exerciseId,
        site: engine.PainSite.knee,
      ),
    );
    expect(
      await _targets(database),
      containsAll(['session_events', 'user_exercise_prefs']),
    );
  });
}

Future<List<String>> _targets(AppDatabase database) async {
  final query = database.select(database.outbox)
    ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
  return [for (final row in await query.get()) row.targetTable];
}
