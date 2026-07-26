import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/programming_engine_facade.dart';
import '../../../data/analytics/app_events_logger.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/onboarding_answers.dart';
import '../data/plan_repository.dart';
import '../domain/stored_plan_document.dart';

final class PlanGenerationService {
  const PlanGenerationService(
    this._onboardingRepository,
    this._planRepository,
    this._engineFacade,
    this._catalog,
    this._events,
  );

  final OnboardingRepository _onboardingRepository;
  final PlanRepository _planRepository;
  final ProgrammingEngineFacade _engineFacade;
  final engine.ContentCatalog _catalog;
  final AppEventsLogger _events;

  Future<StoredPlanDocument> generate() async {
    final answers = await _onboardingRepository.load();
    if (answers == null || !answers.hasAllQuizAnswers) {
      throw StateError('Finish the onboarding quiz before generating a plan.');
    }

    final result = _engineFacade.assemblePlan(
      answers.toEngineProfile(),
      _catalog,
    );
    return switch (result) {
      engine.Success<engine.Plan>(:final value) => _storeAndLog(value, answers),
      engine.Failure<engine.Plan>(:final error) => throw StateError(
        'Plan generation failed: ${error.message}',
      ),
    };
  }

  Future<StoredPlanDocument> _storeAndLog(
    engine.Plan plan,
    OnboardingAnswers answers,
  ) async {
    final stored = await _planRepository.store(
      plan,
      onboardingRepository: _onboardingRepository,
      unitSystem: answers.unitSystem,
    );
    _events.planGenerated(
      days: answers.daysPerWeek!.value,
      minutes: answers.sessionMinutes!.value,
      goal: answers.goal!,
      emphasis: answers.emphasis!,
    );
    return stored;
  }
}
