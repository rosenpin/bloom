/// The one hardcoded plan-time eligibility predicate.
///
/// There is intentionally no data-authored rule language. Adding a dimension
/// requires a typed content field and an engine release.
library;

import '../content/exercise.dart';
import '../profile/profile.dart';

bool eligible(Exercise exercise, Profile profile) {
  if (exercise.isRetired) return false;
  if (exercise.safetyEligibility != SafetyEligibility.selfGuided) return false;

  final ageAllowed = switch (exercise.ageEligibility) {
    AgeEligibility.allAges => true,
    AgeEligibility.under60 => !profile.ageBand.isAtLeast60,
    AgeEligibility.under50 => !profile.ageBand.isAtLeast50,
  };
  if (!ageAllowed) return false;

  final experience = switch (profile.experienceTier) {
    ProfileExperienceTier.newToIt => ExperienceTier.neverTrained,
    ProfileExperienceTier.beenAWhile => ExperienceTier.returningAfterBreak,
    ProfileExperienceTier.trainsRegularly => ExperienceTier.trainsRegularly,
  };
  if (experience.index < exercise.minExperience.index) return false;

  final maximumDifficulty = switch (profile.experienceTier) {
    ProfileExperienceTier.newToIt => DifficultyTier.beginner,
    ProfileExperienceTier.beenAWhile => DifficultyTier.intermediate,
    ProfileExperienceTier.trainsRegularly => DifficultyTier.advanced,
  };
  if (exercise.difficultyTier.index > maximumDifficulty.index) return false;

  final maximumIntimidation = switch (profile.gymComfort) {
    GymComfort.low => IntimidationTier.low,
    GymComfort.mostlyFine => IntimidationTier.moderate,
    GymComfort.totallyAtHome => IntimidationTier.high,
  };
  return exercise.intimidationTier.index <= maximumIntimidation.index;
}
