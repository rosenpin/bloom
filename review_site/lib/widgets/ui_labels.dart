import 'package:programming_engine/programming_engine.dart';

import '../models/journey_simulator.dart';
import '../models/review_notes.dart';

String ageBandLabel(AgeBand value) => switch (value) {
  AgeBand.age18To29 => '18–29',
  AgeBand.age30To39 => '30–39',
  AgeBand.age40To49 => '40–49',
  AgeBand.age50To59 => '50–59',
  AgeBand.age60Plus => '60+',
};

String goalLabel(Goal value) => switch (value) {
  Goal.tonedAndDefined => 'Toned & defined',
  Goal.stronger => 'Stronger',
  Goal.buildCurves => 'Build curves',
  Goal.feelHealthier => 'Feel healthier',
};

String emphasisLabel(Emphasis value) => switch (value) {
  Emphasis.balanced => 'Keep it balanced',
  Emphasis.glutes => 'Glutes',
  Emphasis.back => 'Back',
  Emphasis.arms => 'Arms',
  Emphasis.core => 'Core',
  Emphasis.legs => 'Legs',
};

String experienceLabel(ProfileExperienceTier value) => switch (value) {
  ProfileExperienceTier.newToIt => 'New to it / never trained',
  ProfileExperienceTier.beenAWhile => 'Been a while',
  ProfileExperienceTier.trainsRegularly => 'Trains regularly',
};

String comfortLabel(GymComfort value) => switch (value) {
  GymComfort.low => 'Low comfort',
  GymComfort.mostlyFine => 'Mostly fine',
  GymComfort.totallyAtHome => 'Totally at home',
};

String activityLabel(ActivityKind value) => switch (value) {
  ActivityKind.running => 'Running',
  ActivityKind.cycling => 'Cycling',
  ActivityKind.groupClasses => 'Group classes',
  ActivityKind.sport => 'Sport',
  ActivityKind.yogaPilates => 'Yoga / Pilates',
  ActivityKind.other => 'Other',
};

String dayKindLabel(PlanDayKind value) => switch (value) {
  PlanDayKind.fullBodyA => 'Full Body A',
  PlanDayKind.fullBodyB => 'Full Body B',
  PlanDayKind.lower => 'Lower',
  PlanDayKind.upper => 'Upper',
  PlanDayKind.lowerGluteLed => 'Lower · glute-led',
};

String blockRoleLabel(BlockRole value) => switch (value) {
  BlockRole.warmUp => 'Warm-up',
  BlockRole.lowerHinge => 'Lower hinge',
  BlockRole.lowerSquat => 'Lower squat',
  BlockRole.upperPush => 'Upper push',
  BlockRole.upperPull => 'Upper pull',
  BlockRole.gluteIsolation => 'Glute isolation',
  BlockRole.legIsolation => 'Leg isolation',
  BlockRole.armShoulderIsolation => 'Arm / shoulder isolation',
  BlockRole.core => 'Core',
  BlockRole.finisherCardio => 'Cardio finisher',
};

String equipmentLabel(ResistanceEquipment value) => switch (value) {
  ResistanceEquipment.barbell => 'Barbell',
  ResistanceEquipment.dumbbell => 'Dumbbell',
  ResistanceEquipment.machine => 'Machine',
  ResistanceEquipment.assistedStack => 'Assisted stack',
  ResistanceEquipment.cable => 'Cable',
  ResistanceEquipment.bodyweight => 'Bodyweight',
};

String supportEquipmentLabel(SupportEquipment value) => switch (value) {
  SupportEquipment.none => '',
  SupportEquipment.bench => 'bench',
  SupportEquipment.inclineBench => 'incline bench',
  SupportEquipment.rack => 'rack',
  SupportEquipment.mat => 'mat',
  SupportEquipment.box => 'box',
  SupportEquipment.platform => 'platform',
  SupportEquipment.hipThrustPad => 'hip-thrust pad',
};

String weekKindLabel(MesocycleWeekKind value) => switch (value) {
  MesocycleWeekKind.build => 'Build',
  MesocycleWeekKind.easier => 'Easier',
  MesocycleWeekKind.push => 'Push',
  MesocycleWeekKind.deload => 'Deload',
};

String journeyPatternLabel(JourneyPattern value) => switch (value) {
  JourneyPattern.honestNovice => 'Honest novice',
  JourneyPattern.alwaysJustRight => 'Always just right',
  JourneyPattern.struggling => 'Struggling',
};

String journeyPatternDescription(JourneyPattern value) => switch (value) {
  JourneyPattern.honestNovice =>
    'Per exercise: first 2 exposures way too easy, next 2 a bit easy, then just right.',
  JourneyPattern.alwaysJustRight =>
    'Every exercise reports just right after each simulated session.',
  JourneyPattern.struggling =>
    'Every third exposure reports harder than I’d like; the others are just right.',
};

String reviewerRoleLabel(ReviewerRole value) => switch (value) {
  ReviewerRole.trainer => 'Trainer',
  ReviewerRole.trainee => 'Trainee',
  ReviewerRole.owner => 'Owner',
};

String feedbackTagLabel(FeedbackTag value) => switch (value) {
  FeedbackTag.wrongExercise => 'Wrong exercise',
  FeedbackTag.wrongOrder => 'Wrong order',
  FeedbackTag.tooMuch => 'Too much',
  FeedbackTag.tooLittle => 'Too little',
  FeedbackTag.wrongProgression => 'Wrong progression',
};
