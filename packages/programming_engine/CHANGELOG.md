## 1.0.0 (unreleased)

Build-order steps 1–3 from `docs/ENGINE.md`:

- **Event vocabulary + core types**: `SessionEvent` (sealed), `Kg`, `EffortTarget`,
  `RepRange`, `Dose`, `LoadSuggestion` (sealed), `Laterality`, `DropBridge`,
  `ReasonCode`, `ExercisePrescription`, `EngineWarning`. No codegen; hand-written
  value semantics.
- **`ProgrammingConfig`**: the tuning numbers from `docs/PROGRAMMING.md` — rep
  schemes per goal with the novice 4-week cap, per-market equipment ladders, the
  6-week mesocycle (easier week 4, deload week 6), layoff tiers, calibration
  parameters, and the §4 guardrail constants — plus typed content interfaces
  mirroring `docs/EXERCISES.md`.
- **Progression (§4, §6)**: effort mapping (5 levels → RPE bands → RIR, clamped at
  5), `LoadSuggester` (Epley-ratio formula on effective load, guardrails in spec
  order, equipment-step discretization), and the layoff tiers applied before
  progression. Every decision carries its `ReasonCode`s.

Not yet implemented: `assemblePlan`, `resolveSession`, `advanceSession`.
