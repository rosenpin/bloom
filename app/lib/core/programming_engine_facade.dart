import 'package:programming_engine/programming_engine.dart' as engine;

/// App-facing seam over the pure package's two plan/progression entry points.
final class ProgrammingEngineFacade {
  const ProgrammingEngineFacade({
    this.config = const engine.ProgrammingConfig(),
  });

  final engine.ProgrammingConfig config;

  engine.Result<engine.Plan> assemblePlan(
    engine.Profile profile,
    engine.ContentCatalog catalog,
  ) => engine.assemblePlan(profile, config, catalog);

  engine.LoadDecision suggestLoad(engine.ProgressionInput input) =>
      engine.LoadSuggester(config).suggest(input);
}
