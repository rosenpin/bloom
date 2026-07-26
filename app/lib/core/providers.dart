import 'dart:async';
import 'dart:ui';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:programming_engine/programming_engine.dart' as programming;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/db/app_database.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/domain/onboarding_answers.dart';
import '../features/plan/application/plan_generation_service.dart';
import '../features/plan/data/plan_repository.dart';
import '../features/plan/domain/stored_plan_document.dart';
import '../features/session/application/rest_timer_foundation.dart';
import '../features/session/application/session_lifecycle_service.dart';
import '../features/session/data/exercise_content_repository.dart';
import 'programming_engine_facade.dart';
import 'ulid.dart';
import 'version_gate.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;

@Riverpod(keepAlive: true)
Locale deviceLocale(Ref ref) => PlatformDispatcher.instance.locale;

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
}

@Riverpod(keepAlive: true)
ProgrammingEngineFacade engine(Ref ref) => const ProgrammingEngineFacade(
  config: programming.ProgrammingConfig(
    exerciseCountByMinutes: {15: 1, 20: 2, 30: 4, 45: 6, 60: 8},
  ),
);

@Riverpod(keepAlive: true)
programming.ContentCatalog contentCatalog(Ref ref) => programming.catalogV1;

@Riverpod(keepAlive: true)
UlidGenerator ulid(Ref ref) => UlidGenerator(clock: ref.watch(clockProvider));

@Riverpod(keepAlive: true)
OnboardingRepository onboardingRepository(Ref ref) =>
    OnboardingRepository(ref.watch(databaseProvider), ref.watch(clockProvider));

@Riverpod(keepAlive: true)
PlanRepository planRepository(Ref ref) => PlanRepository(
  ref.watch(databaseProvider),
  ref.watch(ulidProvider),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
ExerciseContentRepository exerciseContentRepository(Ref ref) =>
    ExerciseContentRepository(ref.watch(databaseProvider));

@Riverpod(keepAlive: true)
ExerciseContentSeeder exerciseContentSeeder(Ref ref) => ExerciseContentSeeder(
  ref.watch(databaseProvider),
  ref.watch(contentCatalogProvider),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
Future<void> seedExerciseContent(Ref ref) =>
    ref.watch(exerciseContentSeederProvider).seedIfEmpty();

@Riverpod(keepAlive: true)
SessionLifecycleService sessionLifecycleService(Ref ref) =>
    SessionLifecycleService(
      ref.watch(databaseProvider),
      ref.watch(planRepositoryProvider),
      ref.watch(onboardingRepositoryProvider),
      ref.watch(exerciseContentSeederProvider),
      ref.watch(ulidProvider),
      ref.watch(clockProvider),
      ref.watch(engineProvider).config,
    );

@Riverpod(keepAlive: true)
FlutterLocalNotificationsPlugin localNotificationsPlugin(Ref ref) =>
    FlutterLocalNotificationsPlugin();

@Riverpod(keepAlive: true)
RestNotificationScheduler restNotificationScheduler(Ref ref) =>
    LocalRestNotificationScheduler(
      ref.watch(localNotificationsPluginProvider),
      ref.watch(clockProvider),
    );

@Riverpod(keepAlive: true)
RestTimerFoundation restTimerFoundation(Ref ref) =>
    RestTimerFoundation(ref.watch(restNotificationSchedulerProvider));

@Riverpod(keepAlive: true)
PlanGenerationService planGenerationService(Ref ref) => PlanGenerationService(
  ref.watch(onboardingRepositoryProvider),
  ref.watch(planRepositoryProvider),
  ref.watch(engineProvider),
  ref.watch(contentCatalogProvider),
);

@riverpod
Stream<OnboardingAnswers?> onboardingAnswers(Ref ref) =>
    ref.watch(onboardingRepositoryProvider).watch();

@riverpod
Stream<StoredPlanDocument?> latestPlan(Ref ref) =>
    ref.watch(planRepositoryProvider).watchLatest();

@riverpod
Future<SessionPreview?> sessionPreview(Ref ref) =>
    ref.watch(sessionLifecycleServiceProvider).preview();

@Riverpod(keepAlive: true)
Duration minimumGenerationDelay(Ref ref) => const Duration(milliseconds: 2500);

@Riverpod(keepAlive: true)
SupabaseClient Function() supabaseClient(Ref ref) =>
    () => Supabase.instance.client;

@Riverpod(keepAlive: true)
SharedPreferencesAsync sharedPreferences(Ref ref) => SharedPreferencesAsync();

@Riverpod(keepAlive: true)
VersionGateRemote versionGateRemote(Ref ref) =>
    SupabaseVersionGateRemote(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
VersionGateCache versionGateCache(Ref ref) =>
    SharedPreferencesVersionGateCache(ref.watch(sharedPreferencesProvider));

@Riverpod(keepAlive: true)
VersionGate versionGate(Ref ref) => FailOpenVersionGate(
  remote: ref.watch(versionGateRemoteProvider),
  cache: ref.watch(versionGateCacheProvider),
);

@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async =>
    (await PackageInfo.fromPlatform()).version;

@Riverpod(keepAlive: true)
Future<VersionGateDecision> startupVersionGate(Ref ref) async {
  try {
    final currentVersion = await ref.watch(appVersionProvider.future);
    return ref.watch(versionGateProvider).check(currentVersion: currentVersion);
  } on Object {
    return const VersionGateDecision.allowed();
  }
}
