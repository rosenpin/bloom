/// The training-programming engine: plan assembly, progression, in-session
/// adaptation.
///
/// Pure Dart — no Flutter, no I/O, no async, no `DateTime.now()`. The clock is
/// always injected. Compiles for the web, because the onboarding quiz funnel reuses
/// it. Design in `docs/ENGINE.md`, rules in `docs/PROGRAMMING.md`.
///
/// Built in the order `ENGINE.md` prescribes. Landed so far: the event vocabulary
/// and core types, `ProgrammingConfig` with the content interfaces, and the §4
/// progression decision logic, deterministic plan assembly, and session
/// resolution. `advanceSession` comes next.
library;

// Config
export 'src/config/equipment_loads.dart';
export 'src/config/programming_config.dart';

// Content interfaces (mirroring EXERCISES.md)
export 'src/content/catalog_v1.dart';
export 'src/content/exercise.dart';

// Core types — the schema that can't be migrated cheaply
export 'src/core/dose.dart';
export 'src/core/effort.dart';
export 'src/core/events.dart';
export 'src/core/load_suggestion.dart';
export 'src/core/prescription.dart';
export 'src/core/reason_code.dart';
export 'src/core/units.dart';
export 'src/core/warnings.dart';

// Event-log history and its deterministic fold
export 'src/history/history_fold.dart';
export 'src/history/training_history.dart';

// Plan time (§5b, §8, §9)
export 'src/plan/assemble_plan.dart';
export 'src/plan/eligibility.dart';
export 'src/plan/plan.dart';
export 'src/plan/result.dart';
export 'src/profile/profile.dart';

// Session-resolve time
export 'src/session/resolve_session.dart';

// Progression (§4, §6)
export 'src/progression/effective_load.dart';
export 'src/progression/effort_mapping.dart';
export 'src/progression/layoff.dart';
export 'src/progression/load_suggester.dart';
