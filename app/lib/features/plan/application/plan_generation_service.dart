import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/programming_engine_facade.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../data/plan_repository.dart';
import '../domain/stored_plan_document.dart';

final class PlanGenerationService {
  const PlanGenerationService(
    this._onboardingRepository,
    this._planRepository,
    this._engineFacade,
    this._catalog,
  );

  final OnboardingRepository _onboardingRepository;
  final PlanRepository _planRepository;
  final ProgrammingEngineFacade _engineFacade;
  final engine.ContentCatalog _catalog;

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
      engine.Success<engine.Plan>(:final value) => _planRepository.store(
        value,
        onboardingRepository: _onboardingRepository,
        unitSystem: answers.unitSystem,
      ),
      engine.Failure<engine.Plan>(:final error) => throw StateError(
        'Plan generation failed: ${error.message}',
      ),
    };
  }
}
