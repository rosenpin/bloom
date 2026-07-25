# programming_engine

Pure Dart training-programming engine: plan assembly, progression, in-session
adaptation. Not published — consumed by `app/` and by the web quiz funnel.

Design: `docs/ENGINE.md`. Training rules: `docs/PROGRAMMING.md`. Content schema:
`docs/EXERCISES.md`. **Read those before changing anything here** — every number in
`ProgrammingConfig` traces to a line in the spec.

## Rules this package lives by

- No Flutter, no `dart:io`, no `async`, no `DateTime.now()`. The clock and the
  calendar are always parameters.
- **No code generation.** Dart 3 sealed classes and hand-written `==`/`hashCode`.
- Never the bare word "cycle" — `mesocycle` or `menstrual`.
- Loads are canonical kg (`Kg`), and every suggested load is snapped to a value that
  physically exists for that equipment family in that unit system.
- `LoadSuggester` is **total**: no input makes it throw. Weird-but-possible values
  come back as `EngineWarning`s alongside a usable decision.

## What's here

| Layer | Files | What it holds |
|---|---|---|
| Core | `src/core/` | `SessionEvent` log vocabulary, `Kg`, `Dose`, `LoadSuggestion`, `ExercisePrescription`, `ReasonCode`, `EngineWarning` |
| Config | `src/config/` | `ProgrammingConfig` — every tuning number — and the per-market equipment ladders |
| Content | `src/content/` | typed attribute interfaces mirroring `EXERCISES.md`; no persistence |
| Progression | `src/progression/` | §4 effort mapping, the Epley-ratio `LoadSuggester`, §6 layoff tiers |

Still to come, in `ENGINE.md`'s build order: `assemblePlan` (+ persona snapshots),
`resolveSession` (+ journey goldens), `advanceSession` (+ calibration tests).

## Two layers, in one paragraph

The plan is weight-agnostic: sets × rep range × an effort target. `LoadSuggester`
turns that plus *her own history for one exercise* into "try 12 kg", using
`newLoad = lastLoad × (30 + lastReps + lastRIR) / (30 + targetReps + targetRIR)` on
**effective** load (`external + bw_contribution × bodyMass`), then the §4 guardrails
in order, then equipment snapping. Every decision carries `why: List<ReasonCode>`.

```dart
const suggester = LoadSuggester();
final decision = suggester.suggest(ProgressionInput(
  profile: gobletSquat,                 // any LoadProfile from the content tables
  range: const RepRange(10, 12),
  effort: EffortTarget.rpe7,            // internal only, never shown to her
  unitSystem: UnitSystem.metric,
  bodyMass: const Kg(70),
  daysSinceLastSession: 3,
  history: const ExerciseSnapshot(
    lastLoad: Kg(12),
    lastReps: 12,
    targetReps: 12,
    reportedEffort: EffortLevel.justRight,
  ),
));
// SuggestedLoad(14.0kg), 10 reps, why [topOfRangeStepUp, weightStep, repsReset]
```

## Tests

```sh
dart analyze && dart test
```

`test/progression_rules_test.dart` is `PROGRAMMING.md` §3–§4 encoded 1:1 — one row per
rule, named after the rule. A tuning change edits the config and that table in the
same reviewed commit. `test/progression_invariants_test.dart` asserts the properties
over a swept grid instead of snapshotting them, and
`test/superseded_feel_table_test.dart` shows where the two-layer model reproduces the
older three-way feel table and where it deliberately refines it.
