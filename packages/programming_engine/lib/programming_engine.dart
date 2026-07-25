/// The training-programming engine: plan assembly, progression, in-session
/// adaptation.
///
/// Pure Dart — no Flutter, no I/O, no async, no `DateTime.now()`. The clock is
/// always injected. Compiles for the web, because the onboarding quiz funnel reuses
/// it. Design in `docs/ENGINE.md`, rules in `docs/PROGRAMMING.md`.
///
/// Built in the order `ENGINE.md` prescribes. Landed so far: the event vocabulary
/// and core types, `ProgrammingConfig` with the content interfaces, and the §4
/// progression decision logic. `assemblePlan`, `resolveSession` and
/// `advanceSession` come next.
library;

// Config
export 'src/config/equipment_loads.dart';
export 'src/config/programming_config.dart';

// Content interfaces (mirroring EXERCISES.md)
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

// Progression (§4, §6)
export 'src/progression/effective_load.dart';
export 'src/progression/effort_mapping.dart';
export 'src/progression/layoff.dart';
export 'src/progression/load_suggester.dart';
