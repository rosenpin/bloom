/// v1 fixture/seed catalog.
///
/// values DRAFT pending instructor review
///
/// In particular, `bwContribution`, biomechanics ranks, swap ordering, and copy
/// are seed-quality drafts. IDs and the 40-exercise membership
/// follow `docs/EXERCISES.md`.
library;

import '../core/prescription.dart';
import 'exercise.dart';

final ContentCatalog catalogV1 = ContentCatalogData(
  contentVersion: 'catalog-v1-tiered-swaps-2026-07-25',
  exercises: _exercises,
  swapEdges: _swapEdges,
  rotatingBlockRoles: const <BlockRole>{
    BlockRole.lowerSquat,
    BlockRole.lowerHinge,
    BlockRole.upperPush,
    BlockRole.upperPull,
    BlockRole.gluteIsolation,
    BlockRole.armShoulderIsolation,
    BlockRole.core,
  },
);

final List<Exercise> _exercises = <Exercise>[
  // Lower — squat pattern.
  _exercise(
    id: 'dumbbell-goblet-squat',
    name: 'Goblet Squat',
    slug: 'dumbbell-goblet-squat',
    role: BlockRole.lowerSquat,
    movement: MovementClass.compoundLower,
    equipment: ResistanceEquipment.dumbbell,
    bw: 0.65,
    primary: const [MuscleGroup.quads, MuscleGroup.glutes],
    secondary: const [MuscleGroup.core],
    actions: const [JointAction.kneeExtension, JointAction.hipExtension],
    secondaryActions: const [JointAction.trunkBrace, JointAction.grip],
    rom: 4,
    stability: 3,
    setupSteps: const [
      'Pick one dumbbell and hold it upright against your chest, both hands cupping the top end.',
      'Stand with feet a little wider than your hips and turn your toes out slightly.',
      'Sit down between your knees, keeping your chest tall and elbows inside your thighs.',
      'Go as deep as feels smooth, then push the floor away to stand.',
    ],
    shouldFeel:
        'Your thighs and glutes working, with your weight balanced over your whole foot.',
    stopIf:
        'If your lower back rounds or a knee pinches, stop and tap Swaps for a kinder version.',
    findIt:
        'Find the dumbbell rack by the mirrors, start around 10-14 kg, and use any open floor space.',
    dos: const [
      'Keep the dumbbell touching your chest so it cannot pull you forward.',
      'Share your weight across your heel, big toe, and little toe.',
      'Push the floor away to stand tall.',
    ],
    donts: const [
      'Do not let your knees cave inward; aim them toward your toes.',
      'Do not lift your heels to get lower; stop where your whole foot stays down.',
      'Do not drop into the bottom; keep your legs working on the way down.',
    ],
  ),
  _exercise(
    id: 'barbell-squat',
    name: 'Barbell Back Squat',
    slug: 'barbell-squat',
    role: BlockRole.lowerSquat,
    movement: MovementClass.compoundLower,
    equipment: ResistanceEquipment.barbell,
    support: SupportEquipment.rack,
    bw: 0.85,
    primary: const [MuscleGroup.quads, MuscleGroup.glutes],
    secondary: const [MuscleGroup.core],
    actions: const [JointAction.kneeExtension, JointAction.hipExtension],
    secondaryActions: const [JointAction.trunkBrace],
    rom: 5,
    stability: 4,
    intimidation: IntimidationTier.high,
    setupSteps: const [
      'Set the rack hooks just below shoulder height and the safety arms just below your lowest squat.',
      'Step under the bar, rest it across your upper back, and place both hands evenly.',
      'Stand up with the bar, take two short steps back, and set your feet about shoulder-width apart.',
      'Sit down between your knees, then press through both feet to stand.',
    ],
    shouldFeel:
        'Your thighs and glutes working while your middle stays firm and your whole foot stays grounded.',
    stopIf:
        'If the bar presses your neck, your wrists ache, or your back folds, re-rack it and tap Swaps.',
    findIt:
        'Head to the squat racks in the weights area; an empty 15-20 kg bar is plenty for a first try.',
    dos: const [
      'Tighten your middle as if you expect a cough so your torso stays steady.',
      'Point your knees the same way as your toes to give your hips room.',
      'Stand by driving both feet into the floor.',
    ],
    donts: const [
      'Do not rest the bar on your neck; keep it on the muscle below it.',
      'Do not walk far from the rack; two short steps make re-racking easier.',
      'Do not let your knees cave as you stand; that shifts pressure into them.',
    ],
  ),
  _exercise(
    id: 'machine-leg-press',
    name: 'Leg Press',
    slug: 'machine-leg-press',
    role: BlockRole.lowerSquat,
    movement: MovementClass.compoundLower,
    equipment: ResistanceEquipment.machine,
    bw: 0,
    primary: const [MuscleGroup.quads, MuscleGroup.glutes],
    actions: const [JointAction.kneeExtension, JointAction.hipExtension],
    rom: 4,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Adjust the seat so your knees start near a right angle and your lower back stays on the pad.',
      'Place both feet shoulder-width apart in the middle of the large footplate.',
      'Choose a light pin setting, around 20-40 kg, then release the safety handles.',
      'Lower the plate until your knees feel comfortably bent, then press it away without locking them.',
    ],
    shouldFeel:
        'Your thighs and glutes working, with your hips and lower back heavy against the seat.',
    stopIf:
        'If your hips curl off the pad or a knee pinches, stop, shorten the depth, and tap Swaps.',
    findIt:
        'Look in the leg-machine row for a reclined seat facing a broad footplate; start with 20-40 kg on the pin.',
    dos: const [
      'Press through your whole foot so your heels stay planted.',
      'Let your knees travel in line with your middle toes.',
      'Lower only as far as your back can stay against the pad.',
    ],
    donts: const [
      'Do not place your feet so low that your heels peel off the plate.',
      'Do not press your knees together; that makes them carry the wrong angle.',
      'Do not snap your knees straight or lift your hips at the top.',
    ],
  ),
  _exercise(
    id: 'dumbbell-bulgarian-split-squat',
    name: 'Bulgarian Split Squat',
    slug: 'dumbbell-bulgarian-split-squat',
    role: BlockRole.lowerSquat,
    movement: MovementClass.compoundLower,
    metric: MetricType.loadReps,
    equipment: ResistanceEquipment.dumbbell,
    support: SupportEquipment.bench,
    laterality: Laterality.perSide,
    bw: 0.75,
    primary: const [MuscleGroup.quads, MuscleGroup.glutes],
    secondary: const [MuscleGroup.core],
    actions: const [JointAction.kneeExtension, JointAction.hipExtension],
    secondaryActions: const [JointAction.trunkBrace],
    rom: 5,
    stability: 5,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Stand about two foot-lengths in front of a flat bench, with your feet still hip-width apart.',
      'Rest the top of one foot on the bench and keep most of your weight on the front leg.',
      'Hold a dumbbell in each hand, or start without them while you learn the balance.',
      'Lower your back knee toward the floor, then drive through the front foot to rise.',
    ],
    shouldFeel:
        'Your front thigh and glute working, with your whole front foot grounded and your torso steady.',
    stopIf:
        'If the front knee pinches, the back hip pulls sharply, or balance feels unsafe, tap Swaps.',
    findIt:
        'Take a flat bench near the dumbbell rack; begin bodyweight or with 4-8 kg in each hand.',
    dos: const [
      'Keep your feet hip-width apart so you have a stable base.',
      'Lean your chest forward a little to load the front glute.',
      'Push the front foot down instead of springing off the back toes.',
    ],
    donts: const [
      'Do not stand too close to the bench; a rising front heel means you need more space.',
      'Do not put most of your weight on the bench leg; it is there for balance.',
      'Do not place both feet on one narrow line; that makes every rep wobble.',
    ],
  ),
  _exercise(
    id: 'bodyweight-squat',
    name: 'Bodyweight Squat',
    slug: 'bodyweight-squat',
    role: BlockRole.lowerSquat,
    movement: MovementClass.compoundLower,
    metric: MetricType.repsOnly,
    equipment: ResistanceEquipment.bodyweight,
    bw: 0.65,
    primary: const [MuscleGroup.quads, MuscleGroup.glutes],
    secondary: const [MuscleGroup.core],
    actions: const [JointAction.kneeExtension, JointAction.hipExtension],
    secondaryActions: const [JointAction.trunkBrace],
    rom: 4,
    stability: 2,
    machineLean: true,
    setupSteps: const [
      'Stand in open floor space with your feet just wider than hip-width.',
      'Turn your toes out a little and reach both arms forward for balance.',
      'Send your hips down between your knees while keeping your full foot on the floor.',
      'Pause at a comfortable depth, then press the floor away to stand.',
    ],
    shouldFeel:
        'Your thighs and glutes working evenly, with steady pressure under both feet.',
    stopIf:
        'If a knee pinches or your back rounds before a comfortable depth, use a bench target or tap Swaps.',
    findIt:
        'Use the stretching area, a quiet patch by the mirrors, or any clear floor space; no gear is needed.',
    dos: const [
      'Reach your hands forward to help your chest stay tall.',
      'Track your knees over the middle of your feet.',
      'Choose a depth where your heels stay heavy.',
    ],
    donts: const [
      'Do not force your thighs below parallel if your back starts to curl.',
      'Do not rise onto your toes; that sends you forward instead of up.',
      'Do not let one knee fall inward while the other stays straight.',
    ],
  ),
  _exercise(
    id: 'bodyweight-reverse-lunge',
    name: 'Reverse Lunge',
    slug: 'bodyweight-reverse-lunge',
    role: BlockRole.lowerSquat,
    movement: MovementClass.compoundLower,
    metric: MetricType.repsOnly,
    equipment: ResistanceEquipment.bodyweight,
    laterality: Laterality.perSide,
    bw: 0.75,
    primary: const [MuscleGroup.quads, MuscleGroup.glutes],
    secondary: const [MuscleGroup.core],
    actions: const [JointAction.kneeExtension, JointAction.hipExtension],
    secondaryActions: const [JointAction.trunkBrace],
    rom: 4,
    stability: 4,
    setupSteps: const [
      'Stand with feet hip-width apart and leave a clear step of space behind you.',
      'Step one foot straight back and land softly on the ball of that foot.',
      'Lower the back knee toward the floor while the front foot stays flat.',
      'Press through the front foot to return, then finish the side before switching.',
    ],
    shouldFeel:
        'Your front thigh and glute working, with the front foot grounded and your torso quiet.',
    stopIf:
        'If the front knee pinches or you cannot return without a hard wobble, shorten the step or tap Swaps.',
    findIt:
        'Use the turf or stretching area near a rail or wall; this version needs no weights.',
    dos: const [
      'Step back far enough that your front heel stays down.',
      'Aim the front knee toward the middle toes.',
      'Drive the front foot into the floor to come home.',
    ],
    donts: const [
      'Do not step directly behind your front foot; keep a hip-width base.',
      'Do not bounce the back knee off the floor.',
      'Do not shove off the back toes; the front leg should bring you up.',
    ],
  ),

  // Lower — hinge pattern.
  _exercise(
    id: 'barbell-romanian-deadlift',
    name: 'Barbell Romanian Deadlift',
    slug: 'barbell-romanian-deadlift',
    role: BlockRole.lowerHinge,
    movement: MovementClass.compoundLower,
    equipment: ResistanceEquipment.barbell,
    bw: 0.55,
    primary: const [MuscleGroup.hamstrings, MuscleGroup.glutes],
    secondary: const [MuscleGroup.lowerBack, MuscleGroup.forearms],
    actions: const [JointAction.hipExtension],
    secondaryActions: const [JointAction.trunkBrace, JointAction.grip],
    rom: 4,
    stability: 4,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Set rack hooks just below hip height, grip the bar outside your legs, and stand with it against your thighs.',
      'Soften your knees, tighten your middle, and keep the bar close to your body.',
      'Push your hips back as the bar slides down your thighs toward your shins.',
      'Stop at a strong back-of-thigh stretch, then push your hips forward to stand.',
    ],
    shouldFeel:
        'Your hamstrings and glutes working, with the bar close and your weight centered over both feet.',
    stopIf:
        'If your lower back takes over or you feel a sharp pull behind a knee, rack the bar and tap Swaps.',
    findIt:
        'Use a squat rack in the weights area; set the empty 15-20 kg bar on hooks just below hip height.',
    dos: const [
      'Keep the bar brushing your legs so it cannot pull your back forward.',
      'Send your hips toward the wall behind you.',
      'Stand tall by squeezing your glutes.',
    ],
    donts: const [
      'Do not bend your knees into a squat; keep only a soft bend.',
      'Do not reach the bar toward the floor after your back starts to round.',
      'Do not lean backward at the top; finish stacked over your feet.',
    ],
  ),
  _exercise(
    id: 'dumbbell-romanian-deadlift',
    name: 'Dumbbell Romanian Deadlift',
    slug: 'dumbbell-romanian-deadlift',
    role: BlockRole.lowerHinge,
    movement: MovementClass.compoundLower,
    equipment: ResistanceEquipment.dumbbell,
    bw: 0.55,
    primary: const [MuscleGroup.hamstrings, MuscleGroup.glutes],
    secondary: const [MuscleGroup.lowerBack, MuscleGroup.forearms],
    actions: const [JointAction.hipExtension],
    secondaryActions: const [JointAction.trunkBrace, JointAction.grip],
    rom: 4,
    stability: 3,
    setupSteps: const [
      'Choose two dumbbells and hold them in front of your thighs with palms facing you.',
      'Set your feet hip-width apart, soften your knees, and make your torso firm.',
      'Push your backside toward the wall as the dumbbells travel down beside your legs.',
      'Stop around mid-shin or at a strong hamstring stretch, then stand tall.',
    ],
    shouldFeel:
        'The backs of your thighs and your glutes working while your trunk moves as one piece.',
    stopIf:
        'If your lower back aches or the stretch turns sharp near your sitting bones, set the weights down and tap Swaps.',
    findIt:
        'Pick a pair of 6-10 kg dumbbells from the rack and use a clear patch in front of it.',
    dos: const [
      'Keep the dumbbells directly below your shoulders.',
      'Think of closing a car door with your hips.',
      'End the descent when the hamstring stretch is strongest.',
    ],
    donts: const [
      'Do not squat the dumbbells toward the floor.',
      'Do not round your shoulders just to make the weights travel lower.',
      'Do not let the dumbbells drift out in front of your toes.',
    ],
  ),
  _exercise(
    id: 'barbell-deadlift',
    name: 'Barbell Deadlift',
    slug: 'barbell-deadlift',
    role: BlockRole.lowerHinge,
    movement: MovementClass.compoundLower,
    equipment: ResistanceEquipment.barbell,
    support: SupportEquipment.platform,
    bw: 0.80,
    primary: const [MuscleGroup.glutes, MuscleGroup.hamstrings],
    secondary: const [
      MuscleGroup.quads,
      MuscleGroup.lowerBack,
      MuscleGroup.forearms,
    ],
    actions: const [JointAction.hipExtension, JointAction.kneeExtension],
    secondaryActions: const [JointAction.trunkBrace, JointAction.grip],
    rom: 5,
    stability: 5,
    intimidation: IntimidationTier.high,
    setupSteps: const [
      'Stand with the bar over the middle of your feet, about a thumb-width from your shins.',
      'Push your hips back, bend your knees, and grip the bar just outside your legs.',
      'Lift your chest enough to make your back firm, then push the floor away and stand.',
      'Send your hips back, bend your knees after the bar passes them, and set it down.',
    ],
    shouldFeel:
        'Your legs, glutes, and hamstrings working, with full-foot pressure and the bar close to you.',
    stopIf:
        'If your back rounds before the bar moves or you feel a sharp groin or back tug, lower it and tap Swaps.',
    findIt:
        'Find the rubber lifting platforms by the racks; start around 20-30 kg with full-size light plates.',
    dos: const [
      'Pull gently on the bar before lifting to remove any loose clank.',
      'Push the floor away instead of yanking with your arms.',
      'Reset your feet and grip before each clean rep.',
    ],
    donts: const [
      'Do not jerk the bar from the floor; it should leave smoothly.',
      'Do not let your hips shoot up before your chest.',
      'Do not swing the bar around your knees; keep it close to your legs.',
    ],
  ),
  _exercise(
    id: 'cable-pull-through',
    name: 'Cable Pull-Through',
    slug: 'cable-pull-through',
    role: BlockRole.lowerHinge,
    movement: MovementClass.compoundLower,
    equipment: ResistanceEquipment.cable,
    bw: 0.45,
    primary: const [MuscleGroup.glutes, MuscleGroup.hamstrings],
    secondary: const [MuscleGroup.core],
    actions: const [JointAction.hipExtension],
    secondaryActions: const [JointAction.trunkBrace],
    rom: 4,
    stability: 2,
    machineLean: true,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Clip a rope to the lowest cable setting and choose a light pin, around 10-20 kg.',
      'Face away, straddle the rope, and hold one rope end in each hand.',
      'Walk forward until the cable stays taut, then soften your knees and push your hips back.',
      'Let the rope pass between your legs, then squeeze your glutes to stand tall.',
    ],
    shouldFeel:
        'Your glutes and hamstrings working, with both feet planted and the cable pulling from behind.',
    stopIf:
        'If the rope rubs your groin or your lower back arches at the top, stop and tap Swaps.',
    findIt:
        'Find a cable tower by the upper-body machines and a rope on its attachment rack; start around 10-20 kg.',
    dos: const [
      'Step far enough forward that the stack never goes slack.',
      'Reach your hips back toward the machine.',
      'Finish tall by squeezing your glutes, not by leaning back.',
    ],
    donts: const [
      'Do not squat straight down; the movement comes from your hips.',
      'Do not pull the rope forward with your arms.',
      'Do not throw your shoulders behind your feet at the finish.',
    ],
  ),
  _exercise(
    id: 'machine-back-extension',
    name: 'Back Extension',
    slug: 'machine-back-extension',
    role: BlockRole.lowerHinge,
    movement: MovementClass.compoundLower,
    equipment: ResistanceEquipment.machine,
    bw: 0.45,
    primary: const [MuscleGroup.glutes, MuscleGroup.hamstrings],
    secondary: const [MuscleGroup.lowerBack],
    actions: const [JointAction.hipExtension],
    secondaryActions: const [JointAction.spinalExtension],
    rom: 3,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Adjust the foot brace so your knees stay softly bent and your hips sit firmly against the seat.',
      'Set the rolling pad across your upper back, lower the lap pad snugly, and choose 10-20 kg.',
      'Sit tall with your ribs down, then let your torso tip forward a small amount.',
      'Press your upper back into the roller until you are upright, then return slowly.',
    ],
    shouldFeel:
        'Your glutes and the muscles beside your lower back working while your hips stay fixed in the seat.',
    stopIf:
        'If your lower spine feels pinched or the roller presses your neck, stop, readjust, and tap Swaps.',
    findIt:
        'Look for a chair with a curved back roller and foot brace in the core or leg area; start around 10-20 kg.',
    dos: const [
      'Keep the movement small enough that your hips stay planted.',
      'Press both feet into the brace for a steady base.',
      'Finish upright with your ribs over your hips.',
    ],
    donts: const [
      'Do not throw your head back to move the roller.',
      'Do not arch past upright; that squeezes the lower spine.',
      'Do not let your hips slide forward under the lap pad.',
    ],
  ),

  // Glutes.
  _exercise(
    id: 'barbell-hip-thrust',
    name: 'Barbell Hip Thrust',
    slug: 'barbell-hip-thrust',
    role: BlockRole.gluteIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.barbell,
    support: SupportEquipment.hipThrustPad,
    bw: 0.40,
    primary: const [MuscleGroup.glutes],
    secondary: const [MuscleGroup.hamstrings],
    actions: const [JointAction.hipExtension],
    rom: 3,
    stability: 3,
    intimidation: IntimidationTier.high,
    setupSteps: const [
      'Brace a flat bench against a rack or wall and sit with your shoulder blades at its long edge.',
      'Roll a padded bar over your legs and settle it into the crease at the front of your hips.',
      'Plant your feet hip-width apart, with heels close enough that your shins finish nearly upright.',
      'Drive through both feet until hips reach knee height, pause, then lower under control.',
    ],
    shouldFeel:
        'Your glutes working hard at the top, with your feet and upper back steady and no lower-back squeeze.',
    stopIf:
        'If the bar hurts your hip bones despite the pad or your lower back pinches, unload it and tap Swaps.',
    findIt:
        'Use a rack or platform, a flat bench, and a thick bar pad; start around 20-30 kg total.',
    dos: const [
      'Anchor the bench so it cannot slide behind you.',
      'Keep your shins close to upright at the top.',
      'Pause and squeeze your glutes before lowering.',
    ],
    donts: const [
      'Do not put the bar on your stomach; keep it in the hip crease.',
      'Do not rest only your neck on the bench; use the bottom of your shoulder blades.',
      'Do not fling your ribs upward to chase extra height.',
    ],
  ),
  _exercise(
    id: 'dumbbell-glute-bridge',
    name: 'Dumbbell Glute Bridge',
    slug: 'dumbbell-glute-bridge',
    role: BlockRole.gluteIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.dumbbell,
    support: SupportEquipment.mat,
    bw: 0.40,
    primary: const [MuscleGroup.glutes],
    secondary: const [MuscleGroup.hamstrings],
    actions: const [JointAction.hipExtension],
    rom: 3,
    stability: 1,
    machineLean: true,
    setupSteps: const [
      'Lie on a mat with knees bent, feet flat, and heels a comfortable distance from your hips.',
      'Place one dumbbell across your hip creases and hold both ends so it stays centered.',
      'Let your ribs settle down, then press through both feet to lift your hips.',
      'Stop when knees, hips, and shoulders form a line, squeeze, then lower softly.',
    ],
    shouldFeel:
        'Your glutes working with both heels grounded and your lower back staying comfortable.',
    stopIf:
        'If your hamstrings cramp or your lower back pinches, move your feet slightly and tap Swaps if it continues.',
    findIt:
        'Take a mat and one 8-14 kg dumbbell to the stretching area, away from the busy rack.',
    dos: const [
      'Hold both ends of the dumbbell so it cannot roll.',
      'Set your ribs before your hips leave the floor.',
      'Pause when your glutes feel strongest.',
    ],
    donts: const [
      'Do not push from your toes; keep your heels heavy.',
      'Do not lift your ribs higher than your hips.',
      'Do not bounce the dumbbell off your body between reps.',
    ],
  ),
  _exercise(
    id: 'dumbbell-hip-thrust',
    name: 'Dumbbell Hip Thrust',
    slug: 'dumbbell-hip-thrust',
    role: BlockRole.gluteIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.dumbbell,
    support: SupportEquipment.bench,
    bw: 0.40,
    primary: const [MuscleGroup.glutes],
    secondary: const [MuscleGroup.hamstrings],
    actions: const [JointAction.hipExtension],
    rom: 3,
    stability: 2,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Set a flat bench against a wall and sit with the bottom of your shoulder blades on its edge.',
      'Place one dumbbell lengthwise across your hip creases and hold it at both ends.',
      'Plant your feet hip-width apart and tuck your chin so you look toward your knees.',
      'Push the floor away, lift your hips to knee height, pause, then lower.',
    ],
    shouldFeel:
        'Your glutes doing the lift, with your whole feet down and your shoulder blades anchored to the bench.',
    stopIf:
        'If the bench presses into your neck or your lower back pinches, reposition and tap Swaps.',
    findIt:
        'Pair a flat bench with one 8-16 kg dumbbell near the rack, ideally where the bench can meet a wall.',
    dos: const [
      'Check that the bench cannot slide before you start.',
      'Keep your gaze forward so your ribs stay down.',
      'Finish with your shins close to upright.',
    ],
    donts: const [
      'Do not balance on your neck; keep your shoulder blades on the edge.',
      'Do not let the dumbbell roll up onto your stomach.',
      'Do not arch beyond a level hip position.',
    ],
  ),
  _exercise(
    id: 'machine-hip-abduction',
    name: 'Hip Abduction Machine',
    slug: 'machine-hip-abduction',
    role: BlockRole.gluteIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.machine,
    bw: 0,
    primary: const [MuscleGroup.abductors, MuscleGroup.glutes],
    actions: const [JointAction.hipAbduction],
    rom: 2,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Sit back in the seat and use the start lever to bring the leg pads to a comfortable narrow position.',
      'Place the pads against the outside of your knees or lower thighs and set both feet on the rests.',
      'Choose a light pin, around 15-30 kg, and hold the side handles.',
      'Press your knees apart, pause before your hips shift, then return slowly.',
    ],
    shouldFeel:
        'The outer sides of your glutes working, with your hips level and your back still against the seat.',
    stopIf:
        'If the front or inside of a hip pinches or a knee twists, narrow the start position and tap Swaps.',
    findIt:
        'Look in the leg-machine row for a chair with two pads outside the knees; start around 15-30 kg.',
    dos: const [
      'Keep both sides of your hips heavy on the seat.',
      'Lead the press with your knees.',
      'Pause open before easing the pads inward.',
    ],
    donts: const [
      'Do not bounce the stack to force the pads wider.',
      'Do not swing your whole torso forward and back.',
      'Do not let the plates fully rest between reps.',
    ],
  ),
  _exercise(
    id: 'cable-standing-glute-kickback',
    name: 'Cable Glute Kickback',
    slug: 'cable-standing-glute-kickback',
    role: BlockRole.gluteIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.cable,
    bw: 0.10,
    primary: const [MuscleGroup.glutes],
    actions: const [JointAction.hipExtension],
    rom: 3,
    stability: 3,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Clip an ankle strap to the lowest cable setting and choose 2.5-7.5 kg on the pin.',
      'Face the tower, secure the strap around one ankle, and hold the frame with both hands.',
      'Step back until the cable is taut, soften the standing knee, and lean forward slightly.',
      'Sweep the strapped leg behind you without turning your hips, then return slowly.',
    ],
    shouldFeel:
        'One glute working while your standing foot stays steady and your waist stays quiet.',
    stopIf:
        'If the strap pulls at your ankle or your lower back tightens, unclip it and tap Swaps.',
    findIt:
        'Find a cable tower and the nearby basket of ankle straps; start with 2.5-7.5 kg on the lowest pulley.',
    dos: const [
      'Hold the frame so balance does not steal the rep.',
      'Squeeze the working glute before the leg travels high.',
      'Keep the return smooth and quiet.',
    ],
    donts: const [
      'Do not kick so high that your lower back arches.',
      'Do not turn your toes and hips open to gain distance.',
      'Do not let the stack slam at the front.',
    ],
  ),
  _exercise(
    id: 'machine-glute-kickback',
    name: 'Machine Glute Kickback',
    slug: 'machine-glute-kickback',
    role: BlockRole.gluteIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.machine,
    bw: 0.10,
    primary: const [MuscleGroup.glutes],
    actions: const [JointAction.hipExtension],
    rom: 3,
    stability: 1,
    machineLean: true,
    setupSteps: const [
      'Choose 10-20 kg on the pin and adjust the knee pad, if it moves, so your hips meet the machine pivot.',
      'Set up on all fours on the machine: one knee on the pad, hands on the handles, and your working foot resting on the plate behind you.',
      'Start with the working knee under your hip, then press the footplate back with your heel.',
      'Stop before your back arches and return without resting the stack, then switch sides.',
    ],
    shouldFeel:
        'The working-side glute pushing the plate while your supported knee and hips stay comfortable.',
    stopIf:
        'If the support pad hurts your knee or your lower back pinches, add padding, readjust, and tap Swaps.',
    findIt:
        'Look by the leg machines for a kneeling pad and one moving footplate; start around 10-20 kg.',
    dos: const [
      'Drive the footplate back through your heel.',
      'Keep both hip bones facing the floor.',
      'Bring the knee forward slowly without resting the plates.',
    ],
    donts: const [
      'Do not snap the working knee straight.',
      'Do not turn your hips open as the plate moves.',
      'Do not drop the stack at the end of the return.',
    ],
  ),

  // Legs — isolation.
  _exercise(
    id: 'machine-leg-extension',
    name: 'Leg Extension',
    slug: 'machine-leg-extension',
    role: BlockRole.legIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.machine,
    bw: 0,
    primary: const [MuscleGroup.quads],
    actions: const [JointAction.kneeExtension],
    rom: 3,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Adjust the backrest so your knees line up with the machine hinge beside them.',
      'Move the shin roller to sit above your ankles, not on your feet.',
      'Choose 10-20 kg on the pin, sit back, and hold the side handles.',
      'Lift the roller until your legs are almost straight, then lower it without dropping the stack.',
    ],
    shouldFeel:
        'The fronts of your thighs working while your hips and back stay planted in the seat.',
    stopIf:
        'If you feel pressure behind the kneecap or the roller digs into your ankles, stop, readjust, and tap Swaps.',
    findIt:
        'Find the chair with a padded roller in front of the shins in the leg-machine row; start around 10-20 kg.',
    dos: const [
      'Match your knees to the machine hinge before moving the pin.',
      'Lift smoothly so the thigh muscles do the work.',
      'Lower until the stack nearly touches, then start the next rep.',
    ],
    donts: const [
      'Do not place the roller across your feet; it should sit above the ankles.',
      'Do not kick your hips off the seat to finish a rep.',
      'Do not snap your knees into a hard lock at the top.',
    ],
  ),
  _exercise(
    id: 'machine-seated-hamstring-curl',
    name: 'Seated Hamstring Curl',
    slug: 'machine-seated-hamstring-curl',
    role: BlockRole.legIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.machine,
    bw: 0,
    primary: const [MuscleGroup.hamstrings],
    actions: const [JointAction.kneeFlexion],
    rom: 3,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Slide the backrest until the machine hinge at the side sits level with your knees.',
      'Set the lower roller just above your heels and lower the thigh pad snugly above your knees.',
      'Choose 10-20 kg on the pin, sit fully back, and hold the handles.',
      'Pull your heels under the seat, pause, then let the roller travel forward slowly.',
    ],
    shouldFeel:
        'The backs of your thighs working, with your hips down and the thigh pad holding you steady.',
    stopIf:
        'If you cramp behind a knee or your calf does most of the work, stop, adjust the roller, and tap Swaps.',
    findIt:
        'Look for a seated leg machine with a thigh clamp and roller behind the legs; start around 10-20 kg.',
    dos: const [
      'Pull the roller back with your heels.',
      'Keep your hips heavy against the seat.',
      'Control the forward return until your legs are long.',
    ],
    donts: const [
      'Do not leave the thigh pad loose enough for your legs to lift.',
      'Do not raise your hips as your heels pull back.',
      'Do not let the stack yank your legs straight.',
    ],
  ),
  _exercise(
    id: 'machine-standing-calf-raises',
    name: 'Standing Calf Raise',
    slug: 'machine-standing-calf-raises',
    role: BlockRole.legIsolation,
    movement: MovementClass.isolationLower,
    equipment: ResistanceEquipment.machine,
    bw: 0.90,
    primary: const [MuscleGroup.calves],
    actions: const [JointAction.anklePlantarflexion],
    rom: 3,
    stability: 2,
    machineLean: true,
    setupSteps: const [
      'Set the shoulder pads so you need only a tiny squat to get underneath them.',
      'Choose 10-20 kg on the pin and place the balls of both feet on the edge of the step.',
      'Stand tall into the pads with knees softly straight and heels hanging free.',
      'Rise onto your toes, pause, then lower your heels below the step under control.',
    ],
    shouldFeel:
        'Both calves working, with even pressure through the balls of your feet and the pads steady overhead.',
    stopIf:
        'If the back of your ankle pulls sharply or a foot slips on the edge, re-rack the weight and tap Swaps.',
    findIt:
        'Look in the leg area for a tall machine with shoulder pads and a raised foot step; start around 10-20 kg.',
    dos: const [
      'Hold the handles before lifting the shoulder pads.',
      'Travel all the way up and down through a smooth ankle range.',
      'Keep both big toes pressing into the step.',
    ],
    donts: const [
      'Do not bounce out of the bottom stretch.',
      'Do not roll your ankles toward the outer edges of your feet.',
      'Do not bend and straighten your knees to move the weight.',
    ],
  ),

  // Upper — push.
  _exercise(
    id: 'dumbbell-bench-press',
    name: 'Dumbbell Bench Press',
    slug: 'dumbbell-bench-press',
    role: BlockRole.upperPush,
    movement: MovementClass.compoundUpperPush,
    equipment: ResistanceEquipment.dumbbell,
    support: SupportEquipment.bench,
    bw: 0,
    primary: const [MuscleGroup.chest, MuscleGroup.triceps],
    secondary: const [MuscleGroup.shoulders],
    actions: const [JointAction.horizontalPush],
    secondaryActions: const [JointAction.elbowExtension],
    rom: 4,
    stability: 3,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Sit on a flat bench with one dumbbell on each thigh and both feet planted.',
      'Lie back while guiding the dumbbells to the sides of your chest.',
      'Turn your palms forward and stack each wrist above its elbow.',
      'Press the weights over your chest, then lower until your elbows are just below the bench top.',
    ],
    shouldFeel:
        'Your chest and triceps working, with your upper back, feet, and wrists staying steady.',
    stopIf:
        'If the front of a shoulder pinches or a wrist buckles, bring the weights to your thighs and tap Swaps.',
    findIt:
        'Take a flat bench beside the dumbbell rack and start with 4-8 kg in each hand.',
    dos: const [
      'Plant your feet before the first press.',
      'Keep each wrist directly above its elbow.',
      'Lower both dumbbells at the same speed.',
    ],
    donts: const [
      'Do not point your elbows straight sideways; use a gentle diagonal.',
      'Do not lower farther once the front of your shoulders rolls forward.',
      'Do not bang the dumbbells together over your face.',
    ],
  ),
  _exercise(
    id: 'barbell-bench-press',
    name: 'Barbell Bench Press',
    slug: 'barbell-bench-press',
    role: BlockRole.upperPush,
    movement: MovementClass.compoundUpperPush,
    equipment: ResistanceEquipment.barbell,
    support: SupportEquipment.bench,
    bw: 0,
    primary: const [MuscleGroup.chest, MuscleGroup.triceps],
    secondary: const [MuscleGroup.shoulders],
    actions: const [JointAction.horizontalPush],
    secondaryActions: const [JointAction.elbowExtension],
    rom: 4,
    stability: 4,
    intimidation: IntimidationTier.high,
    setupSteps: const [
      'Set the bench so your eyes sit just behind the bar and place the safety arms just below chest height.',
      'Lie down with feet flat and grip the bar evenly, a little wider than your shoulders.',
      'Lift the bar clear of the hooks and hold it over the middle of your chest.',
      'Lower it to mid-chest with elbows on a diagonal, then press it back above you.',
    ],
    shouldFeel:
        'Your chest and triceps working while your upper back and both feet stay firmly planted.',
    stopIf:
        'If a shoulder pinches or the bar drifts toward your neck, set it on the safeties and tap Swaps.',
    findIt:
        'Find a bench station inside a rack; use the empty 15-20 kg bar first and ask for a spotter before plates.',
    dos: const [
      'Set the safety arms before you lie down.',
      'Wrap your thumbs around the bar for a secure grip.',
      'Touch the same mid-chest spot each rep.',
    ],
    donts: const [
      'Do not set the hooks so high that you must reach your shoulders off the bench.',
      'Do not bounce the bar off your chest.',
      'Do not press with open thumbs; the bar can roll out of your hands.',
    ],
  ),
  _exercise(
    id: 'machine-chest-press',
    name: 'Machine Chest Press',
    slug: 'machine-chest-press',
    role: BlockRole.upperPush,
    movement: MovementClass.compoundUpperPush,
    equipment: ResistanceEquipment.machine,
    bw: 0,
    primary: const [MuscleGroup.chest, MuscleGroup.triceps],
    secondary: const [MuscleGroup.shoulders],
    actions: const [JointAction.horizontalPush],
    secondaryActions: const [JointAction.elbowExtension],
    rom: 3,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Adjust the seat so the handles line up with the middle of your chest.',
      'Choose 5-15 kg on the pin and set the start position so elbows sit a little behind your hands.',
      'Sit with your back on the pad, feet flat, and wrists straight on the handles.',
      'Press forward until your arms are long, then return before your shoulders roll forward.',
    ],
    shouldFeel:
        'Your chest and triceps working, with your back supported and both hands pressing evenly.',
    stopIf:
        'If the handles pull your elbows far behind you or a shoulder pinches, adjust the seat or tap Swaps.',
    findIt:
        'Look for a padded chair with two handles that press forward in the upper-body row; start around 5-15 kg.',
    dos: const [
      'Center your palms on the handles so your wrists stay straight.',
      'Press both sides at the same pace.',
      'End the return while your chest still feels open.',
    ],
    donts: const [
      'Do not sit so low that the handles start near your face.',
      'Do not shrug your shoulders toward your ears as you press.',
      'Do not let the stack crash at the back of the rep.',
    ],
  ),
  _exercise(
    id: 'dumbbell-incline-bench-press',
    name: 'Incline Dumbbell Press',
    slug: 'dumbbell-incline-bench-press',
    role: BlockRole.upperPush,
    movement: MovementClass.compoundUpperPush,
    equipment: ResistanceEquipment.dumbbell,
    support: SupportEquipment.inclineBench,
    bw: 0,
    primary: const [MuscleGroup.chest, MuscleGroup.shoulders],
    secondary: const [MuscleGroup.triceps],
    actions: const [JointAction.horizontalPush, JointAction.shoulderFlexion],
    secondaryActions: const [JointAction.elbowExtension],
    rom: 4,
    stability: 3,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Raise an adjustable bench one or two notches above flat, about a 30-degree angle.',
      'Sit with one dumbbell on each thigh, then lie back and guide them beside your upper chest.',
      'Plant your feet and turn your palms forward with wrists above elbows.',
      'Press up and slightly inward, then lower until your elbows reach just below your body.',
    ],
    shouldFeel:
        'Your upper chest, shoulders, and triceps working while your feet and back stay settled.',
    stopIf:
        'If a shoulder catches at the bottom or your neck strains, bring the weights down and tap Swaps.',
    findIt:
        'Use an adjustable bench by the dumbbells, set low, and start with 4-8 kg in each hand.',
    dos: const [
      'Use a low incline so your upper chest stays involved.',
      'Keep your wrists stacked over your elbows.',
      'Lower the dumbbells toward the top of your chest.',
    ],
    donts: const [
      'Do not set the bench almost upright; that turns this into a shoulder press.',
      'Do not flare your elbows straight out from your body.',
      'Do not drop the weights faster than you can guide them.',
    ],
  ),
  _exercise(
    id: 'dumbbell-seated-overhead-press',
    name: 'Seated Dumbbell Shoulder Press',
    slug: 'dumbbell-seated-overhead-press',
    role: BlockRole.upperPush,
    movement: MovementClass.compoundUpperPush,
    equipment: ResistanceEquipment.dumbbell,
    support: SupportEquipment.bench,
    bw: 0,
    primary: const [MuscleGroup.shoulders, MuscleGroup.triceps],
    actions: const [JointAction.verticalPush],
    secondaryActions: const [JointAction.elbowExtension],
    rom: 4,
    stability: 2,
    seated: true,
    setupSteps: const [
      'Set the bench back almost upright, then sit with feet flat and dumbbells on your thighs.',
      'Bring the dumbbells up beside your shoulders, palms turned forward or a little toward each other.',
      'Keep your back on the pad and press both weights overhead without knocking them together.',
      'Lower until the dumbbells return beside your shoulders, then repeat.',
    ],
    shouldFeel:
        'Your shoulders and triceps working, with your back supported and your feet steady.',
    stopIf:
        'If the top or front of a shoulder pinches or your back lifts from the pad, set the weights down and tap Swaps.',
    findIt:
        'Take an adjustable bench near the dumbbell rack, set it near upright, and start with 3-6 kg each.',
    dos: const [
      'Keep your ribs over your hips so the bench supports you.',
      'Press the dumbbells slightly toward each other.',
      'Guide the weights down to a comfortable shoulder height.',
    ],
    donts: const [
      'Do not bounce the weights up with your legs.',
      'Do not arch your lower back away from the pad.',
      'Do not lower the dumbbells behind your shoulders.',
    ],
  ),
  _exercise(
    id: 'bodyweight-push-up',
    name: 'Push-Up',
    slug: 'bodyweight-push-up',
    role: BlockRole.upperPush,
    movement: MovementClass.compoundUpperPush,
    metric: MetricType.repsOnly,
    equipment: ResistanceEquipment.bodyweight,
    bw: 0.65,
    primary: const [MuscleGroup.chest, MuscleGroup.triceps],
    secondary: const [MuscleGroup.shoulders, MuscleGroup.core],
    actions: const [JointAction.horizontalPush],
    secondaryActions: const [
      JointAction.elbowExtension,
      JointAction.trunkBrace,
    ],
    rom: 4,
    stability: 3,
    machineLean: true,
    setupSteps: const [
      'Choose a firm bench, rail, or wall height that lets you hold a straight body line.',
      'Place your hands a little wider than your shoulders and step your feet back.',
      'Tighten your glutes and middle, then lower your chest between your hands.',
      'Keep elbows on a gentle diagonal and push the surface away to return.',
    ],
    shouldFeel:
        'Your chest, triceps, and middle working while your body moves as one straight piece.',
    stopIf:
        'If a wrist or shoulder pinches or your hips keep sagging, raise your hands to a higher surface or tap Swaps.',
    findIt:
        'Use a wall, sturdy rail, or flat bench in the stretching area; no weight is needed.',
    dos: const [
      'Choose a higher surface until every rep stays tidy.',
      'Grip the edge or spread your fingers for stable hands.',
      'Push the surface away at the bottom.',
    ],
    donts: const [
      'Do not lead with your chin; bring your chest toward the surface.',
      'Do not point your elbows straight out to the sides.',
      'Do not let your hips sag or arrive after your chest.',
    ],
  ),
  _exercise(
    id: 'assisted-dip',
    name: 'Assisted Dip',
    slug: 'assisted-dip',
    role: BlockRole.upperPush,
    movement: MovementClass.compoundUpperPush,
    equipment: ResistanceEquipment.assistedStack,
    // DRAFT: approximately 85% of body mass contributes to the movement.
    bw: 0.85,
    primary: const [MuscleGroup.chest, MuscleGroup.triceps],
    secondary: const [MuscleGroup.shoulders],
    actions: const [JointAction.verticalPush],
    secondaryActions: const [JointAction.elbowExtension],
    rom: 4,
    stability: 2,
    machineLean: true,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Set the assistance pin around 30-45 kg; more stack weight means more help and an easier rep.',
      'Climb the steps, grip the parallel handles, and place one knee at a time on the moving pad.',
      'Let your shoulders stay down and lean your chest forward a little.',
      'Bend your elbows to lower comfortably, then press the handles down until your arms are long.',
    ],
    shouldFeel:
        'Your triceps and lower chest working, with your shoulders away from your ears and the pad steady.',
    stopIf:
        'If the front of a shoulder pinches or your hands go numb, let the pad rise, step off, and tap Swaps.',
    findIt:
        'Find the tall assisted machine by the cable towers, with steps and a knee pad; start with 30-45 kg of help.',
    dos: const [
      'Choose more assistance when you need an easier starting point.',
      'Keep your forearms close to upright as you lower.',
      'Let the moving pad settle before stepping off.',
    ],
    donts: const [
      'Do not jump off the knee pad while it is still low.',
      'Do not let your shoulders creep toward your ears.',
      'Do not lower past the point where your shoulders stay comfortable.',
    ],
  ),

  // Upper — pull.
  _exercise(
    id: 'machine-pulldown',
    name: 'Lat Pulldown',
    slug: 'machine-pulldown',
    role: BlockRole.upperPull,
    movement: MovementClass.compoundUpperPull,
    equipment: ResistanceEquipment.machine,
    bw: 0,
    primary: const [MuscleGroup.lats, MuscleGroup.biceps],
    secondary: const [MuscleGroup.upperBack],
    actions: const [JointAction.verticalPull],
    secondaryActions: const [JointAction.elbowFlexion],
    rom: 4,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Choose 10-20 kg on the pin and adjust the thigh pad so it holds you down with feet flat.',
      'Grip the wide bar a little beyond shoulder-width and sit with your chest gently lifted.',
      'Pull the bar toward your collarbone by bringing your elbows down beside your ribs.',
      'Pause near your upper chest, then let your arms reach long overhead without losing the seat.',
    ],
    shouldFeel:
        'The sides of your back and your biceps working, with your thighs held down and your torso tall.',
    stopIf:
        'If a shoulder pinches overhead or your neck works harder than your back, reduce the weight or tap Swaps.',
    findIt:
        'Look for a tall cable machine with a wide bar and thigh pad in the upper-body row; start around 10-20 kg.',
    dos: const [
      'Bring the bar toward your collarbone.',
      'Lead the pull by driving your elbows down.',
      'Let your arms reach long before the next rep.',
    ],
    donts: const [
      'Do not pull toward your stomach; that turns it into a row and takes work away from your back.',
      'Do not swing your torso backward to start the bar.',
      'Do not pull the bar behind your neck; your shoulders lose their comfortable path.',
    ],
  ),
  _exercise(
    id: 'machine-seated-cable-row',
    name: 'Seated Cable Row',
    slug: 'machine-seated-cable-row',
    role: BlockRole.upperPull,
    movement: MovementClass.compoundUpperPull,
    equipment: ResistanceEquipment.machine,
    bw: 0,
    primary: const [MuscleGroup.upperBack, MuscleGroup.lats],
    secondary: const [MuscleGroup.biceps],
    actions: const [JointAction.horizontalPull, JointAction.scapularRetraction],
    secondaryActions: const [JointAction.elbowFlexion],
    rom: 4,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Clip on the close-grip handle and choose 10-20 kg on the pin.',
      'Sit on the bench, place both feet on the plates, and keep your knees softly bent.',
      'Hold the handle with long arms and sit tall before the stack leaves its rest.',
      'Pull toward your lower ribs, keeping elbows close, then reach forward without rocking your torso.',
    ],
    shouldFeel:
        'Your middle and upper back working with your biceps, while your feet stay braced and chest stays quiet.',
    stopIf:
        'If your lower back starts doing the pulling or a shoulder pinches forward, release the handle and tap Swaps.',
    findIt:
        'Find the low cable station facing two footplates, often at the end of a tower; start around 10-20 kg.',
    dos: const [
      'Sit tall before you move the handle.',
      'Drive your elbows behind you toward your back pockets.',
      'Pause when the handle reaches your lower ribs.',
    ],
    donts: const [
      'Do not lean far back to finish; that turns the rep into a body swing.',
      'Do not shrug as the handle comes in.',
      'Do not let the stack yank your shoulders forward.',
    ],
  ),
  _exercise(
    id: 'dumbbell-row-unilateral',
    name: 'Single-Arm Dumbbell Row',
    slug: 'dumbbell-row-unilateral',
    role: BlockRole.upperPull,
    movement: MovementClass.compoundUpperPull,
    equipment: ResistanceEquipment.dumbbell,
    support: SupportEquipment.bench,
    laterality: Laterality.perSide,
    bw: 0,
    primary: const [MuscleGroup.lats, MuscleGroup.upperBack],
    secondary: const [MuscleGroup.biceps],
    actions: const [JointAction.horizontalPull],
    secondaryActions: const [JointAction.elbowFlexion, JointAction.grip],
    rom: 4,
    stability: 3,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Place one knee and the same-side hand on a flat bench, with the other foot firm on the floor.',
      'Hold a dumbbell in the free hand and let that arm hang straight below your shoulder.',
      'Make your back long and keep both hip bones facing the floor.',
      'Pull your elbow toward your back pocket, pause, then lower until the arm is long.',
    ],
    shouldFeel:
        'The side and upper back of the working arm doing the pull, with your hips steady on the bench.',
    stopIf:
        'If your support shoulder collapses or your lower back twists or aches, set the dumbbell down and tap Swaps.',
    findIt:
        'Use a flat bench beside the dumbbell rack and start with one 6-10 kg dumbbell.',
    dos: const [
      'Press the support hand into the bench.',
      'Pull your elbow toward the hip, not straight toward the ceiling.',
      'Let the working arm lengthen fully at the bottom.',
    ],
    donts: const [
      'Do not roll your chest open to lift the dumbbell higher.',
      'Do not curl the weight toward your armpit.',
      'Do not shrug the working shoulder toward your ear.',
    ],
  ),
  _exercise(
    id: 'bodyweight-assisted-chin-up',
    name: 'Assisted Pull-Up',
    slug: 'bodyweight-assisted-chin-up',
    role: BlockRole.upperPull,
    movement: MovementClass.compoundUpperPull,
    equipment: ResistanceEquipment.assistedStack,
    // DRAFT: approximately 85% of body mass contributes to the movement.
    bw: 0.85,
    primary: const [MuscleGroup.lats, MuscleGroup.biceps],
    secondary: const [MuscleGroup.upperBack],
    actions: const [JointAction.verticalPull],
    secondaryActions: const [JointAction.elbowFlexion],
    rom: 5,
    stability: 2,
    machineLean: true,
    seated: true,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Set the assistance pin around 30-50 kg; more stack weight means more help and an easier pull-up.',
      'Climb the steps, take an overhand grip, and place one knee at a time on the moving pad.',
      'Start with long arms and a quiet body, keeping your shoulders away from your ears.',
      'Pull your chest toward the handles until your chin reaches hand height, then lower slowly.',
    ],
    shouldFeel:
        'The sides of your back and your biceps working while your body stays quiet over the moving pad.',
    stopIf:
        'If a shoulder pinches in the hang or an elbow feels sharply strained, let the pad rise and tap Swaps.',
    findIt:
        'Find the tall Gravitron by the cable towers, with steps and a moving knee pad; start with 30-50 kg of help.',
    dos: const [
      'Add more assistance whenever you need the rep to feel easier.',
      'Bring your elbows down toward your ribs.',
      'Control the knee pad instead of letting it bounce.',
    ],
    donts: const [
      'Do not jump off while the pad is still below you.',
      'Do not kick or swing to get your chin higher.',
      'Do not crane your neck over the handles.',
    ],
  ),
  _exercise(
    id: 'machine-rear-deltoid-row',
    name: 'Machine Rear-Delt Row',
    slug: 'machine-rear-deltoid-row',
    role: BlockRole.upperPull,
    movement: MovementClass.compoundUpperPull,
    equipment: ResistanceEquipment.machine,
    bw: 0,
    primary: const [MuscleGroup.rearDelts, MuscleGroup.upperBack],
    secondary: const [MuscleGroup.biceps],
    actions: const [JointAction.horizontalPull, JointAction.scapularRetraction],
    secondaryActions: const [JointAction.elbowFlexion],
    rom: 3,
    stability: 1,
    machineLean: true,
    seated: true,
    setupSteps: const [
      'Adjust the seat so the handles sit near shoulder height and your chest rests fully on the pad.',
      'Choose 5-15 kg on the pin and take the handles with palms facing the floor.',
      'Keep your chest on the pad and begin with arms reaching forward.',
      'Pull your elbows wide until your hands reach your ribs, then return without dropping the stack.',
    ],
    shouldFeel:
        'The backs of your shoulders and upper back working, with your chest supported and neck relaxed.',
    stopIf:
        'If the front of a shoulder pinches or your hands tingle, stop, change the seat or grip, and tap Swaps.',
    findIt:
        'Look near the chest and back machines for a chest pad with handles that sweep back; start around 5-15 kg.',
    dos: const [
      'Keep your chest touching the pad throughout the pull.',
      'Drive your elbows wide and back.',
      'Pause just before the plates touch down.',
    ],
    donts: const [
      'Do not tuck your elbows close; that turns it into a different row.',
      'Do not push your head toward the handles.',
      'Do not lean away from the chest pad to gain distance.',
    ],
  ),

  // Shoulders and arms.
  _exercise(
    id: 'dumbbell-lateral-raise',
    name: 'Dumbbell Lateral Raise',
    slug: 'dumbbell-lateral-raise',
    role: BlockRole.armShoulderIsolation,
    movement: MovementClass.isolationUpper,
    equipment: ResistanceEquipment.dumbbell,
    bw: 0,
    primary: const [MuscleGroup.shoulders],
    actions: const [JointAction.shoulderAbduction],
    rom: 3,
    stability: 2,
    setupSteps: const [
      'Choose two light dumbbells and stand with feet hip-width apart.',
      'Hold the weights beside your thighs with palms facing in and elbows softly bent.',
      'Lift your arms out to the sides, leading with the elbows.',
      'Stop around shoulder height, then lower the dumbbells slowly to your sides.',
    ],
    shouldFeel:
        'The outer part of your shoulders working, with your ribs, feet, and neck staying quiet.',
    stopIf:
        'If the top of a shoulder pinches or your neck takes over, lower the weights and tap Swaps.',
    findIt:
        'Pick 2-5 kg dumbbells from the light end of the rack, often the top shelf by the mirrors.',
    dos: const [
      'Lead with your elbows so your hands stay relaxed.',
      'Use a weight that lets your torso stay still.',
      'Stop when your hands reach about shoulder height.',
    ],
    donts: const [
      'Do not swing your knees and hips to launch the weights.',
      'Do not shrug your shoulders toward your ears.',
      'Do not tip your thumbs toward the floor; that can crowd the shoulder.',
    ],
  ),
  _exercise(
    id: 'dumbbell-curl',
    name: 'Dumbbell Curl',
    slug: 'dumbbell-curl',
    role: BlockRole.armShoulderIsolation,
    movement: MovementClass.isolationUpper,
    equipment: ResistanceEquipment.dumbbell,
    bw: 0,
    primary: const [MuscleGroup.biceps],
    secondary: const [MuscleGroup.forearms],
    actions: const [JointAction.elbowFlexion],
    secondaryActions: const [JointAction.grip],
    rom: 3,
    stability: 2,
    setupSteps: const [
      'Choose two dumbbells and stand tall with feet hip-width apart.',
      'Let your arms hang by your sides, palms forward, and elbows close to your ribs.',
      'Curl the dumbbells toward your shoulders without moving your upper arms.',
      'Pause before your elbows drift forward, then lower until your arms are long.',
    ],
    shouldFeel:
        'The fronts of your upper arms working, with your torso still and your wrists straight.',
    stopIf:
        'If the crease of an elbow feels sharp or a wrist bends back under the load, set the weights down and tap Swaps.',
    findIt:
        'Choose 3-7 kg dumbbells from the lighter half of the rack and stand clear of the bench aisle.',
    dos: const [
      'Keep your elbows beside your ribs.',
      'Turn your palms fully forward as you curl.',
      'Lower until the elbows open without snapping straight.',
    ],
    donts: const [
      'Do not swing your hips to start the dumbbells.',
      'Do not carry your elbows forward as the weights rise.',
      'Do not fold your wrists toward your shoulders.',
    ],
  ),
  _exercise(
    id: 'cable-rope-pushdown',
    name: 'Cable Rope Pushdown',
    slug: 'cable-rope-pushdown',
    role: BlockRole.armShoulderIsolation,
    movement: MovementClass.isolationUpper,
    equipment: ResistanceEquipment.cable,
    bw: 0,
    primary: const [MuscleGroup.triceps],
    actions: const [JointAction.elbowExtension],
    rom: 3,
    stability: 1,
    machineLean: true,
    setupSteps: const [
      'Clip a rope to the highest cable setting and choose 5-12.5 kg on the pin.',
      'Face the tower, hold one rope end in each hand, and tuck your elbows beside your ribs.',
      'Take a small step back and keep your knees soft with your chest tall.',
      'Press the rope down, separate its ends by your thighs, then return using only your forearms.',
    ],
    shouldFeel:
        'The backs of your upper arms working, with your shoulders down and your torso still.',
    stopIf:
        'If an elbow or wrist pinches or a shoulder gets pulled forward, release the rope and tap Swaps.',
    findIt:
        'Use a cable tower and the rope from its attachment rack; set the pulley high and start around 5-12.5 kg.',
    dos: const [
      'Pin your elbows beside your body.',
      'Split the rope ends at the bottom.',
      'Let your forearms return without moving your upper arms.',
    ],
    donts: const [
      'Do not lean your body weight onto the rope.',
      'Do not flare your elbows away from your ribs.',
      'Do not let the pin stack slam on the return.',
    ],
  ),

  // Core.
  _exercise(
    id: 'plank',
    name: 'Plank',
    slug: 'plank',
    role: BlockRole.core,
    movement: MovementClass.core,
    metric: MetricType.timed,
    equipment: ResistanceEquipment.bodyweight,
    support: SupportEquipment.mat,
    bw: 1,
    primary: const [MuscleGroup.core],
    secondary: const [MuscleGroup.glutes, MuscleGroup.shoulders],
    actions: const [JointAction.trunkBrace],
    rom: 1,
    stability: 3,
    machineLean: true,
    setupSteps: const [
      'Place a mat down and set your forearms parallel, with elbows directly below your shoulders.',
      'Step both feet back onto your toes, about hip-width apart.',
      'Squeeze your glutes and tighten your middle until head, hips, and heels form one line.',
      'Hold that position for the timer while taking small, steady breaths.',
    ],
    shouldFeel:
        'Your abs, glutes, and shoulders holding you still, with weight even between forearms and toes.',
    stopIf:
        'If your lower back sags or pinches or your shoulders fail before your abs, lower your knees and tap Swaps.',
    findIt:
        'Take a mat to the stretching or core area and leave enough room to lie full length.',
    dos: const [
      'Push your forearms firmly into the floor.',
      'Tuck your tail slightly so your lower back stays level.',
      'Keep breathing while the timer runs.',
    ],
    donts: const [
      'Do not hold your breath to survive the last seconds.',
      'Do not let your hips sag below your shoulders.',
      'Do not lift your hips high to take the work off your abs.',
    ],
  ),
  _exercise(
    id: 'cable-rope-kneeling-crunch',
    name: 'Cable Kneeling Crunch',
    slug: 'cable-rope-kneeling-crunch',
    role: BlockRole.core,
    movement: MovementClass.core,
    equipment: ResistanceEquipment.cable,
    bw: 0.15,
    primary: const [MuscleGroup.core],
    actions: const [JointAction.trunkFlexion],
    rom: 3,
    stability: 2,
    intimidation: IntimidationTier.moderate,
    setupSteps: const [
      'Clip a rope to the highest cable setting, place a mat down, and choose 10-20 kg.',
      'Kneel facing the tower about one long step away and hold the rope ends beside your temples.',
      'Keep your hips over your knees and your hands still as you curl your ribs toward your hips.',
      'Pause low, then uncurl slowly until your abs lengthen without letting the stack rest.',
    ],
    shouldFeel:
        'The front of your abs doing the curl, with your hips steady and your arms only holding the rope.',
    stopIf:
        'If your lower back pinches or the rope pulls on your neck, lighten the pin or tap Swaps.',
    findIt:
        'Find a cable tower, a rope, and a mat; use the high pulley and start around 10-20 kg.',
    dos: const [
      'Keep the rope beside your head.',
      'Curl your ribs toward your hips.',
      'Open slowly until your abs feel long again.',
    ],
    donts: const [
      'Do not pull the rope down with your arms.',
      'Do not sit your hips back onto your heels.',
      'Do not drop only your head while the rest of your torso stays still.',
    ],
  ),
  _exercise(
    id: 'crunches',
    name: 'Crunches',
    slug: 'crunches',
    role: BlockRole.core,
    movement: MovementClass.core,
    metric: MetricType.repsOnly,
    equipment: ResistanceEquipment.bodyweight,
    support: SupportEquipment.mat,
    bw: 0.20,
    primary: const [MuscleGroup.core],
    actions: const [JointAction.trunkFlexion],
    rom: 2,
    stability: 1,
    machineLean: true,
    setupSteps: const [
      'Lie on a mat with knees bent, feet flat, and lower back resting comfortably.',
      'Place your fingertips lightly behind your ears or cross your hands over your chest.',
      'Look at the ceiling and curl your ribs toward your hips until your shoulder blades lift.',
      'Pause, then lower your upper back slowly without letting your head drop.',
    ],
    shouldFeel:
        'The front of your abs working, with your lower back heavy and your neck relaxed.',
    stopIf:
        'If your neck strains, your head aches, or your lower back lifts and hurts, lower down and tap Swaps.',
    findIt:
        'Use any mat in the stretching area; you need only enough floor space to lie down.',
    dos: const [
      'Keep your eyes on one spot above you.',
      'Lift your shoulder blades, not your whole back.',
      'Breathe out as your ribs curl up.',
    ],
    donts: const [
      'Do not pull your head forward with your hands.',
      'Do not sit all the way up; that shifts the work away from your abs.',
      'Do not hook your feet under a bench to force extra reps.',
    ],
  ),
  _exercise(
    id: 'elbow-side-plank',
    name: 'Side Plank',
    slug: 'elbow-side-plank',
    role: BlockRole.core,
    movement: MovementClass.core,
    metric: MetricType.timed,
    equipment: ResistanceEquipment.bodyweight,
    support: SupportEquipment.mat,
    laterality: Laterality.perSide,
    bw: 1,
    primary: const [MuscleGroup.obliques, MuscleGroup.core],
    secondary: const [MuscleGroup.shoulders],
    actions: const [JointAction.trunkBrace],
    rom: 1,
    stability: 4,
    setupSteps: const [
      'Lie on one side on a mat and place your lower elbow directly below your shoulder.',
      'Straighten both legs and stack your feet, or place the top foot slightly in front for balance.',
      'Press your forearm down and lift your hips until your head, hips, and feet form one line.',
      'Hold for the timer with your top hand on your hip, then lower and switch sides.',
    ],
    shouldFeel:
        'Your lower-side waist, side glute, and support shoulder working while your body stays stacked.',
    stopIf:
        'If the support shoulder pinches or you cannot keep your hips lifted, lower the bottom knee and tap Swaps.',
    findIt:
        'Take a mat to the edge of the stretching area so you have room to switch sides.',
    dos: const [
      'Press the full forearm into the mat.',
      'Stack your top hip directly above the lower one.',
      'Stagger your feet if stacked feet make you wobble.',
    ],
    donts: const [
      'Do not sink the support shoulder toward your ear.',
      'Do not roll your chest toward the floor.',
      'Do not let your hips drift behind your body.',
    ],
  ),
  _exercise(
    id: 'dead-bug',
    name: 'Dead Bug',
    slug: 'dead-bug',
    role: BlockRole.core,
    movement: MovementClass.core,
    metric: MetricType.repsOnly,
    equipment: ResistanceEquipment.bodyweight,
    support: SupportEquipment.mat,
    bw: 0.35,
    primary: const [MuscleGroup.core],
    actions: const [JointAction.trunkBrace],
    secondaryActions: const [JointAction.hipFlexion],
    rom: 2,
    stability: 2,
    machineLean: true,
    setupSteps: const [
      'Lie on your back with both arms reaching up and knees bent above your hips.',
      'Set your shins parallel to the floor and gently press your lower back into the mat.',
      'Slowly reach one arm overhead as the opposite leg extends away from you.',
      'Stop before your back lifts, return to the start, and change sides.',
    ],
    shouldFeel:
        'Your deep abs working around your waist, with your lower back staying quietly against the mat.',
    stopIf:
        'If your lower back lifts or the front of a hip pinches as the leg lowers, shorten the reach or tap Swaps.',
    findIt:
        'Use a mat in the stretching area with clear space above your head and beyond your feet.',
    dos: const [
      'Move opposite arm and leg together.',
      'Breathe out as your limbs reach away.',
      'Make the reach smaller if your back wants to lift.',
    ],
    donts: const [
      'Do not lower both legs together.',
      'Do not rush through the side change.',
      'Do not reach so far that your lower back arches off the mat.',
    ],
  ),
];

final List<SwapEdge> _swapEdges = <SwapEdge>[
  ..._edgesFor(
    'dumbbell-goblet-squat',
    busy: const ['machine-leg-press', 'bodyweight-squat'],
    intimidating: const ['bodyweight-squat', 'machine-leg-press'],
    uncomfortable: const ['machine-leg-press', 'bodyweight-squat'],
    unavailable: const ['bodyweight-squat', 'machine-leg-press'],
  ),
  ..._edgesFor(
    'barbell-squat',
    busy: const ['dumbbell-goblet-squat', 'machine-leg-press'],
    intimidating: const ['dumbbell-goblet-squat', 'bodyweight-squat'],
    uncomfortable: const ['machine-leg-press', 'dumbbell-goblet-squat'],
    unavailable: const ['dumbbell-goblet-squat', 'machine-leg-press'],
  ),
  ..._edgesFor(
    'machine-leg-press',
    busy: const ['dumbbell-goblet-squat', 'bodyweight-squat'],
    intimidating: const ['bodyweight-squat', 'dumbbell-goblet-squat'],
    uncomfortable: const ['bodyweight-squat', 'dumbbell-goblet-squat'],
    unavailable: const ['dumbbell-goblet-squat', 'bodyweight-squat'],
  ),
  const SwapEdge(
    fromId: 'machine-leg-press',
    toId: 'dumbbell-bulgarian-split-squat',
    tier: 2,
    rank: 0,
  ),
  ..._edgesFor(
    'dumbbell-bulgarian-split-squat',
    busy: const ['bodyweight-reverse-lunge'],
    intimidating: const ['bodyweight-reverse-lunge'],
    uncomfortable: const ['bodyweight-reverse-lunge'],
    unavailable: const ['bodyweight-reverse-lunge'],
  ),
  ..._edgesFor(
    'bodyweight-squat',
    busy: const ['dumbbell-goblet-squat', 'machine-leg-press'],
    intimidating: const ['machine-leg-press', 'dumbbell-goblet-squat'],
    uncomfortable: const ['machine-leg-press', 'dumbbell-goblet-squat'],
    unavailable: const ['dumbbell-goblet-squat', 'machine-leg-press'],
  ),
  ..._edgesFor(
    'bodyweight-reverse-lunge',
    busy: const ['dumbbell-bulgarian-split-squat'],
    intimidating: const ['dumbbell-bulgarian-split-squat'],
    uncomfortable: const ['dumbbell-bulgarian-split-squat'],
    unavailable: const ['dumbbell-bulgarian-split-squat'],
  ),
  ..._edgesFor(
    'barbell-romanian-deadlift',
    busy: const ['dumbbell-romanian-deadlift', 'machine-back-extension'],
    intimidating: const [
      'dumbbell-romanian-deadlift',
      'machine-back-extension',
    ],
    uncomfortable: const ['machine-back-extension', 'cable-pull-through'],
    unavailable: const ['dumbbell-romanian-deadlift', 'cable-pull-through'],
  ),
  ..._edgesFor(
    'dumbbell-romanian-deadlift',
    busy: const ['cable-pull-through', 'machine-back-extension'],
    intimidating: const ['machine-back-extension', 'cable-pull-through'],
    uncomfortable: const ['machine-back-extension', 'cable-pull-through'],
    unavailable: const ['cable-pull-through', 'machine-back-extension'],
  ),
  ..._edgesFor(
    'barbell-deadlift',
    busy: const ['barbell-romanian-deadlift', 'dumbbell-romanian-deadlift'],
    intimidating: const [
      'dumbbell-romanian-deadlift',
      'machine-back-extension',
    ],
    uncomfortable: const ['machine-back-extension', 'cable-pull-through'],
    unavailable: const ['dumbbell-romanian-deadlift', 'machine-back-extension'],
  ),
  const SwapEdge(
    fromId: 'barbell-deadlift',
    toId: 'machine-leg-press',
    tier: 2,
    rank: 0,
  ),
  ..._edgesFor(
    'cable-pull-through',
    busy: const ['dumbbell-romanian-deadlift', 'machine-back-extension'],
    intimidating: const [
      'machine-back-extension',
      'dumbbell-romanian-deadlift',
    ],
    uncomfortable: const [
      'machine-back-extension',
      'dumbbell-romanian-deadlift',
    ],
    unavailable: const ['dumbbell-romanian-deadlift', 'machine-back-extension'],
  ),
  ..._edgesFor(
    'machine-back-extension',
    busy: const ['cable-pull-through', 'dumbbell-romanian-deadlift'],
    intimidating: const ['dumbbell-romanian-deadlift', 'cable-pull-through'],
    uncomfortable: const ['cable-pull-through', 'dumbbell-romanian-deadlift'],
    unavailable: const ['cable-pull-through', 'dumbbell-romanian-deadlift'],
  ),
  const SwapEdge(
    fromId: 'machine-back-extension',
    toId: 'dumbbell-glute-bridge',
    tier: 2,
    rank: 0,
  ),
  ..._denseRoleEdges(const [
    'barbell-hip-thrust',
    'dumbbell-glute-bridge',
    'dumbbell-hip-thrust',
    'machine-hip-abduction',
    'cable-standing-glute-kickback',
    'machine-glute-kickback',
  ]),
  const SwapEdge(
    fromId: 'machine-leg-extension',
    toId: 'machine-seated-hamstring-curl',
    tier: 2,
    rank: 0,
  ),
  const SwapEdge(
    fromId: 'machine-leg-extension',
    toId: 'machine-standing-calf-raises',
    tier: 2,
    rank: 1,
  ),
  const SwapEdge(
    fromId: 'machine-leg-extension',
    toId: 'machine-leg-press',
    tier: 3,
    rank: 0,
  ),
  const SwapEdge(
    fromId: 'machine-seated-hamstring-curl',
    toId: 'machine-leg-extension',
    tier: 2,
    rank: 0,
  ),
  const SwapEdge(
    fromId: 'machine-standing-calf-raises',
    toId: 'machine-leg-extension',
    tier: 2,
    rank: 0,
  ),
  ..._edgesFor(
    'dumbbell-bench-press',
    busy: const ['machine-chest-press', 'assisted-dip', 'bodyweight-push-up'],
    intimidating: const [
      'machine-chest-press',
      'assisted-dip',
      'bodyweight-push-up',
    ],
    uncomfortable: const [
      'dumbbell-incline-bench-press',
      'machine-chest-press',
    ],
    unavailable: const [
      'bodyweight-push-up',
      'machine-chest-press',
      'assisted-dip',
    ],
  ),
  ..._edgesFor(
    'barbell-bench-press',
    busy: const ['dumbbell-bench-press', 'machine-chest-press', 'assisted-dip'],
    intimidating: const [
      'machine-chest-press',
      'assisted-dip',
      'bodyweight-push-up',
    ],
    uncomfortable: const [
      'dumbbell-incline-bench-press',
      'machine-chest-press',
    ],
    unavailable: const [
      'dumbbell-bench-press',
      'machine-chest-press',
      'assisted-dip',
    ],
  ),
  ..._edgesFor(
    'machine-chest-press',
    busy: const ['dumbbell-bench-press', 'assisted-dip', 'bodyweight-push-up'],
    intimidating: const [
      'bodyweight-push-up',
      'dumbbell-seated-overhead-press',
    ],
    uncomfortable: const ['dumbbell-incline-bench-press', 'bodyweight-push-up'],
    unavailable: const [
      'dumbbell-bench-press',
      'bodyweight-push-up',
      'assisted-dip',
    ],
  ),
  ..._edgesFor(
    'dumbbell-incline-bench-press',
    busy: const ['dumbbell-bench-press', 'machine-chest-press', 'assisted-dip'],
    intimidating: const [
      'machine-chest-press',
      'assisted-dip',
      'bodyweight-push-up',
    ],
    uncomfortable: const ['dumbbell-bench-press', 'machine-chest-press'],
    unavailable: const [
      'dumbbell-bench-press',
      'machine-chest-press',
      'assisted-dip',
    ],
  ),
  ..._edgesFor(
    'dumbbell-seated-overhead-press',
    busy: const ['machine-chest-press', 'assisted-dip', 'bodyweight-push-up'],
    intimidating: const [
      'machine-chest-press',
      'assisted-dip',
      'bodyweight-push-up',
    ],
    uncomfortable: const [
      'dumbbell-incline-bench-press',
      'machine-chest-press',
    ],
    unavailable: const [
      'machine-chest-press',
      'bodyweight-push-up',
      'assisted-dip',
    ],
  ),
  const SwapEdge(
    fromId: 'dumbbell-seated-overhead-press',
    toId: 'dumbbell-lateral-raise',
    tier: 3,
    rank: 0,
  ),
  ..._edgesFor(
    'bodyweight-push-up',
    busy: const ['machine-chest-press', 'assisted-dip', 'dumbbell-bench-press'],
    intimidating: const [
      'machine-chest-press',
      'dumbbell-seated-overhead-press',
    ],
    uncomfortable: const [
      'machine-chest-press',
      'dumbbell-incline-bench-press',
    ],
    unavailable: const [
      'machine-chest-press',
      'dumbbell-bench-press',
      'assisted-dip',
    ],
  ),
  ..._edgesFor(
    'assisted-dip',
    busy: const ['machine-chest-press', 'dumbbell-bench-press'],
    intimidating: const ['machine-chest-press', 'bodyweight-push-up'],
    uncomfortable: const [
      'dumbbell-incline-bench-press',
      'machine-chest-press',
    ],
    unavailable: const ['machine-chest-press', 'bodyweight-push-up'],
  ),
  ..._edgesFor(
    'machine-pulldown',
    busy: const ['bodyweight-assisted-chin-up', 'machine-seated-cable-row'],
    intimidating: const [
      'machine-seated-cable-row',
      'machine-rear-deltoid-row',
    ],
    uncomfortable: const [
      'machine-seated-cable-row',
      'machine-rear-deltoid-row',
    ],
    unavailable: const [
      'machine-seated-cable-row',
      'bodyweight-assisted-chin-up',
    ],
  ),
  ..._edgesFor(
    'machine-seated-cable-row',
    busy: const ['machine-pulldown', 'machine-rear-deltoid-row'],
    intimidating: const ['machine-pulldown', 'machine-rear-deltoid-row'],
    uncomfortable: const ['machine-pulldown', 'machine-rear-deltoid-row'],
    unavailable: const ['machine-pulldown', 'machine-rear-deltoid-row'],
  ),
  const SwapEdge(
    fromId: 'dumbbell-row-unilateral',
    toId: 'machine-rear-deltoid-row',
    tier: 1,
    rank: 0,
  ),
  const SwapEdge(
    fromId: 'dumbbell-row-unilateral',
    toId: 'machine-seated-cable-row',
    tier: 2,
    rank: 0,
  ),
  const SwapEdge(
    fromId: 'dumbbell-lateral-raise',
    toId: 'dumbbell-curl',
    tier: 2,
    rank: 0,
  ),
  const SwapEdge(
    fromId: 'dumbbell-curl',
    toId: 'dumbbell-lateral-raise',
    tier: 2,
    rank: 0,
  ),
  const SwapEdge(
    fromId: 'cable-rope-pushdown',
    toId: 'dumbbell-lateral-raise',
    tier: 2,
    rank: 0,
  ),
  ..._edgesFor(
    'bodyweight-assisted-chin-up',
    busy: const ['machine-pulldown', 'machine-seated-cable-row'],
    intimidating: const ['machine-pulldown', 'machine-seated-cable-row'],
    uncomfortable: const ['machine-pulldown', 'machine-seated-cable-row'],
    unavailable: const ['machine-pulldown', 'machine-seated-cable-row'],
  ),
  ..._edgesFor(
    'machine-rear-deltoid-row',
    busy: const ['machine-seated-cable-row', 'machine-pulldown'],
    intimidating: const ['machine-seated-cable-row', 'machine-pulldown'],
    uncomfortable: const ['machine-seated-cable-row', 'machine-pulldown'],
    unavailable: const ['machine-seated-cable-row', 'machine-pulldown'],
  ),
  ..._edgesFor(
    'plank',
    busy: const ['elbow-side-plank'],
    intimidating: const ['elbow-side-plank'],
    uncomfortable: const ['elbow-side-plank'],
    unavailable: const ['elbow-side-plank'],
  ),
  ..._edgesFor(
    'elbow-side-plank',
    busy: const ['plank'],
    intimidating: const ['plank'],
    uncomfortable: const ['plank'],
    unavailable: const ['plank'],
  ),
  ..._edgesFor(
    'cable-rope-kneeling-crunch',
    busy: const ['crunches', 'dead-bug'],
    intimidating: const ['dead-bug', 'crunches'],
    uncomfortable: const ['dead-bug', 'crunches'],
    unavailable: const ['crunches', 'dead-bug'],
  ),
  ..._edgesFor(
    'crunches',
    busy: const ['dead-bug', 'cable-rope-kneeling-crunch'],
    intimidating: const ['dead-bug', 'cable-rope-kneeling-crunch'],
    uncomfortable: const ['dead-bug', 'cable-rope-kneeling-crunch'],
    unavailable: const ['dead-bug', 'cable-rope-kneeling-crunch'],
  ),
  ..._edgesFor(
    'dead-bug',
    busy: const ['crunches', 'cable-rope-kneeling-crunch'],
    intimidating: const ['crunches', 'cable-rope-kneeling-crunch'],
    uncomfortable: const ['crunches', 'cable-rope-kneeling-crunch'],
    unavailable: const ['crunches', 'cable-rope-kneeling-crunch'],
  ),
];

ExerciseData _exercise({
  required String id,
  required String name,
  required String slug,
  required BlockRole role,
  required MovementClass movement,
  required ResistanceEquipment equipment,
  required double bw,
  required List<MuscleGroup> primary,
  required List<JointAction> actions,
  MetricType metric = MetricType.loadReps,
  SupportEquipment support = SupportEquipment.none,
  Laterality laterality = Laterality.bilateral,
  List<MuscleGroup> secondary = const <MuscleGroup>[],
  List<JointAction> secondaryActions = const <JointAction>[],
  int rom = 3,
  int stability = 3,
  IntimidationTier intimidation = IntimidationTier.low,
  bool machineLean = false,
  bool seated = false,
  required List<String> setupSteps,
  required String shouldFeel,
  required String stopIf,
  required String findIt,
  required List<String> dos,
  required List<String> donts,
}) => ExerciseData(
  id: id,
  name: name,
  slug: slug,
  blockRole: role,
  movementClass: movement,
  metricType: metric,
  resistanceEquipment: equipment,
  supportEquipment: support,
  laterality: laterality,
  bwContribution: bw,
  targetMuscles: <MuscleTarget>[
    for (final muscle in primary) MuscleTarget.primary(muscle),
    for (final muscle in secondary) MuscleTarget.secondary(muscle),
  ],
  primaryJointActions: actions,
  secondaryJointActions: secondaryActions,
  romRank: rom,
  stabilityRank: stability,
  intimidationTier: intimidation,
  machineLeanOk: machineLean,
  seatedVariant: seated,
  setupSteps: setupSteps,
  shouldFeel: shouldFeel,
  stopIf: stopIf,
  findIt: findIt,
  dos: dos,
  donts: donts,
);

List<SwapEdge> _edgesFor(
  String fromId, {
  required List<String> busy,
  required List<String> intimidating,
  required List<String> uncomfortable,
  required List<String> unavailable,
}) {
  // The four authored lists predate §9's reason-agnostic graph. Preserve their
  // union and authorial order while emitting one universal tiered edge per
  // target. Any SwapReason can traverse every resulting edge.
  final orderedIds = <String>[];
  final included = <String>{};
  for (final ids in <List<String>>[
    busy,
    intimidating,
    uncomfortable,
    unavailable,
  ]) {
    for (final id in ids) {
      if (included.add(id)) orderedIds.add(id);
    }
  }
  final rankByTier = <int, int>{1: 0, 2: 0, 3: 0};
  final result = <SwapEdge>[];
  for (final toId in orderedIds) {
    final tier = _authoredTier(fromId, toId);
    final rank = rankByTier[tier]!;
    result.add(SwapEdge(fromId: fromId, toId: toId, tier: tier, rank: rank));
    rankByTier[tier] = rank + 1;
  }
  return result;
}

int _authoredTier(String fromId, String toId) {
  final from = _exercises.where((exercise) => exercise.id == fromId).first;
  final to = _exercises.where((exercise) => exercise.id == toId).first;
  final similarPattern = from.primaryJointActions.any(
    to.primaryJointActions.contains,
  );
  return similarPattern ? 1 : 2;
}

List<SwapEdge> _denseRoleEdges(List<String> exerciseIds) {
  final result = <SwapEdge>[];
  for (var fromIndex = 0; fromIndex < exerciseIds.length; fromIndex++) {
    final alternatives = <String>[
      for (var offset = 1; offset < exerciseIds.length; offset++)
        exerciseIds[(fromIndex + offset) % exerciseIds.length],
    ];
    result.addAll(
      _edgesFor(
        exerciseIds[fromIndex],
        busy: alternatives,
        intimidating: alternatives.reversed.toList(growable: false),
        uncomfortable: <String>[...alternatives.skip(1), alternatives.first],
        unavailable: alternatives,
      ),
    );
  }
  return result;
}
