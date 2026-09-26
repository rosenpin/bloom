# Bloom

Bloom is a mobile app for women training in commercial gyms. A deterministic, rule-based engine turns a short quiz into a six-week resistance-training plan and adapts each session to effort reports, time and equipment.

[App Store](https://apps.apple.com/app/id6795461055) · [Google Play](https://play.google.com/store/apps/details?id=io.rosenpin.womensgym) · [Engine explorer](https://rosenpin.github.io/bloom/) · [Demo video](https://youtu.be/g8YY0nkYSRU)

Built for RevenueCat Shipaton 2026. Work in progress.

## 1. Problem

Women early in resistance training face open decisions in the gym: what to train, which load to start with, and what to do when a machine is taken or time is short. Guidance built around these constraints is scarce. Menstrual-cycle phase changes performance little on average and varies between women (McNulty et al., 2020), while symptoms such as tiredness and cramps are common and often affect training (Bruinvels et al., 2021). Bloom answers each of these decisions with an explicit, testable rule.

## 2. Method

1. **Practitioner expertise.** Program structure, exercise selection and progression rules draw on the author's experience as a certified gym instructor who designs programs and coaches in a gym.
2. **Literature review** of effort self-report, progression and the menstrual cycle. Where evidence exists and conflicts with practice, the evidence decides; where it is thin or silent, practitioner judgment sets the rule and the value is marked for review.
3. **Specification.** Every rule and value is written down in one programming specification, so each can be traced, reviewed and tested.
4. **Field input.** Semi-structured interviews with a coach who trains women full time, athletes, physiotherapists, fellow Human Movement Sciences master's students and women who train, with more planned. A survey of women who lift is designed and about to be distributed; informal conversations with women trainees, covering the same questions, have already informed the rules. Findings enter as candidate rules.
5. **Iterative review** of plans and simulated progressions for a fixed set of personas in the engine explorer (Section 5).

## 3. Model

The engine lives in `packages/programming_engine`.

**3.1 Inputs.** The quiz yields a profile: age band, days per week (2 to 4), session length (30 to 60 minutes), goal, emphasis area, experience, gym comfort and weeks trained. Menstrual-cycle data stays in the app, which estimates the current day and shows sourced observations, such as exercise easing period pain (Armour et al., 2019). Plans stay phase-independent, since average phase effects are small.

**3.2 Plan construction.** `assemblePlan` picks a split from the days per week and fills each day's roles (squat, hinge, push, pull, isolation, core) from ranked, eligible exercises; session length sets the count and the emphasis area gets an extra slot. Age, experience and gym comfort feed one computation for every profile, through a machine-affinity score, a seated preference and an age-based warm-up; age and safety eligibility are hard constraints. Plans run in six-week blocks (mesocycles): three build weeks, an easier week 4, a full week 5 and a lighter week 6.

**3.3 Loads and progression.** Loads come from the user's own history and round down to what exists on the equipment (dumbbell pairs, machine pins, plates), with extra repetitions covering the gap. Double progression raises repetitions through the range, then the load. An optional five-point effort report after the last set, from "way too easy" to "too hard", sets the size and direction of the next capped step. A missing report holds the load, a stalled lift steps back, and after a grace period time away lowers loads along a smooth curve.

**3.4 In-session adaptation.** `advanceSession(state, event)` maps the session state and one event to the next state. Swaps follow a ranked graph with three compatibility tiers, and the replacement uses its own history. Trimming to fewer minutes drops isolation work first. Low-energy sessions lighten the load. Pain excludes the exercise from later suggestions. A first exposure runs a calibration probe: eight easy repetitions and one effort report, within two test sets.

**3.5 Determinism.** The engine is pure Dart with every input, including the date, passed as an argument, so identical inputs give byte-identical output. Per-exercise state is recomputed from the append-only session event log, so devices converge by replay, and outputs carry engine, config and content stamps. The app calls it through `app/lib/core/programming_engine_facade.dart` and the session player.

## 4. Evaluation

| Engine tests | Count |
|---|---:|
| Progression and load rules | 108 |
| Config, equipment and catalog | 70 |
| Session model | 55 |
| Invariant sweeps | 35 |
| Persona plans (golden) | 16 |
| Progression journeys (golden) | 5 |
| **Total** | **289** |

A golden test compares output with a stored, reviewed expectation: a persona plan as text (each exercise with its role and dose), or a journey's load and target repetitions per session under scripted effort reports. Tuning changes therefore surface as small text diffs. Invariant sweeps assert properties over input grids, for example that every load exists on its equipment.

## 5. Engine explorer

`review_site/` runs the engine in the browser to inspect, during tuning, how a profile becomes a plan and how that plan progresses. The profile is encoded in the URL, and reviewer notes export as stamped JSON. Live at https://rosenpin.github.io/bloom/; the header shows the project's working title.

![Figure 1](readme/engine-explorer-plan.png)

**Figure 1.** Plan for persona "Ruth, 63" (two days, 45 minutes, "feel healthier", new to lifting): two full-body days built mostly on machines, a 7-minute warm-up, and the six-week mesocycle strip. Day 1 is shown.

![Figure 2](readme/engine-explorer-journey.png)

**Figure 2.** Twelve simulated sessions for the same profile under the "honest novice" effort script. Volume rises, dips in the easier week while loads hold, and falls in the lighter final week.

## 6. Limitations and future work

- Menstrual-phase-aware adjustment waits for evidence and in-app data that support specific rules; the app already records the inputs.
- Other weekly activities are stored with each plan, for planning once the quiz captures their days.
- A heavier final set as a readiness test, suggested by a coach we interviewed, is a candidate for the next version.

## 7. Repository and reproduction

```
app/                          Flutter app (iOS, Android)
packages/programming_engine/  engine, pure Dart
review_site/                  engine explorer, Flutter web
supabase/migrations/          schema, row-level security, content seed
.github/workflows/            CI and release workflows (Actions disabled here)
readme/                       figures
```

The app stores data in a local Drift database, synced to Supabase through a queue of pending writes (an outbox). It uses Riverpod and go_router, with RevenueCat purchases behind a custom paywall.

```sh
cd packages/programming_engine && dart pub get && dart test
cd app && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter run
cd review_site && flutter pub get && flutter run -d chrome
```

Requires Flutter 3.44 or newer. The app runs offline; sync is enabled by an `app/env.json` with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, passed with `--dart-define-from-file`. Exercise imagery is held back from the repository, so 45 of 91 app tests pass here (91 with the media).

## References

- Armour, M., Ee, C. C., Naidoo, D., Ayati, Z., Chalmers, K. J., Steel, K. A., de Manincor, M. J., & Delshad, E. (2019). Exercise for dysmenorrhoea. *Cochrane Database of Systematic Reviews*, 2019(9), Article CD004142. https://doi.org/10.1002/14651858.CD004142.pub4
- Bruinvels, G., Goldsmith, E., Blagrove, R., Simpkin, A., Lewis, N., Morton, K., Suppiah, A., Rogers, J. P., Ackerman, K. E., Newell, J., & Pedlar, C. (2021). Prevalence and frequency of menstrual cycle symptoms are associated with availability to train and compete: A study of 6812 exercising women recruited using the Strava exercise app. *British Journal of Sports Medicine*, 55(8), 438-443. https://doi.org/10.1136/bjsports-2020-102792
- McNulty, K. L., Elliott-Sale, K. J., Dolan, E., Swinton, P. A., Ansdell, P., Goodall, S., Thomas, K., & Hicks, K. M. (2020). The effects of menstrual cycle phase on exercise performance in eumenorrheic women: A systematic review and meta-analysis. *Sports Medicine*, 50(10), 1813-1827. https://doi.org/10.1007/s40279-020-01319-3

## License

Source code: MIT (`LICENSE`). The Bloom name, logo, brand assets and exercise imagery are all rights reserved; fonts are under the SIL Open Font License 1.1.
