import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/session_lifecycle_service.dart';
import '../domain/session_presentation.dart';
import 'exercise_visual.dart';

class CalibrationExerciseView extends StatelessWidget {
  const CalibrationExerciseView({
    required this.runtime,
    required this.entry,
    required this.onDone,
    required this.onSetup,
    required this.onLifeHappened,
    required this.onOverview,
    required this.onPain,
    required this.onSwitchUnits,
    required this.onDismissUnits,
    this.adjustmentNotice,
    super.key,
  });

  final SessionRuntime runtime;
  final engine.SessionExerciseEntry entry;
  final VoidCallback onDone;
  final VoidCallback onSetup;
  final VoidCallback onLifeHappened;
  final VoidCallback onOverview;
  final VoidCallback onPain;
  final VoidCallback onSwitchUnits;
  final VoidCallback onDismissUnits;
  final String? adjustmentNotice;

  @override
  Widget build(BuildContext context) {
    final index = SessionPresentation.exercisePosition(runtime.state, entry);
    final load = SessionPresentation.suggestionLoad(
      entry,
      override: runtime.loadOverrides[entry.exerciseId],
    );
    final probe = entry.prescription.suggestion as engine.NeedsCalibration;
    return SafeArea(
      child: Column(
        children: [
          _ExerciseProgress(
            current: index,
            total: SessionPresentation.exerciseCount(runtime.state),
            onTap: onOverview,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!runtime.unitPromptSeen)
                        _UnitPrompt(
                          unitSystem: runtime.displayUnitSystem,
                          onSwitch: onSwitchUnits,
                          onDismiss: onDismissUnits,
                        ),
                      if (adjustmentNotice case final notice?) ...[
                        _SessionAdjustmentCard(text: notice),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _Eyebrow(
                          text: 'First time · ${entry.planExercise.name}',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        "Let's find your weight together.",
                        key: const ValueKey('calibration-heading'),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'We start deliberately light and let your body tell us.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: _ExerciseVisualCard(
                            entry: entry,
                            aspectRatio: 16 / 9,
                            onWatch: onSetup,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CalibrationTryCard(
                        reps: probe.probeReps,
                        load: load,
                        unitSystem: runtime.displayUnitSystem,
                        cue: SessionPresentation.cue(entry),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _ReassuranceCard(),
                      const SizedBox(height: AppSpacing.md),
                      AppPressScale(
                        child: FilledButton(
                          key: const ValueKey('calibration-done'),
                          onPressed: onDone,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                          ),
                          child: Text("I've done my ${probe.probeReps} reps"),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _AmbientSessionStrip(
                        nextExercise: SessionPresentation.nextExercise(
                          runtime.state,
                          entry,
                        ),
                        onLifeHappened: onLifeHappened,
                        onOverview: onOverview,
                      ),
                      _PainLink(onPressed: onPain),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveExerciseView extends StatelessWidget {
  const ActiveExerciseView({
    required this.runtime,
    required this.entry,
    required this.reps,
    required this.onDone,
    required this.onEdit,
    required this.onReviewSet,
    required this.onSetup,
    required this.onLifeHappened,
    required this.onOverview,
    required this.onPain,
    required this.onSwitchUnits,
    required this.onDismissUnits,
    this.adjustmentNotice,
    super.key,
  });

  final SessionRuntime runtime;
  final engine.SessionExerciseEntry entry;
  final int reps;
  final VoidCallback onDone;
  final VoidCallback onEdit;
  final ValueChanged<int> onReviewSet;
  final VoidCallback onSetup;
  final VoidCallback onLifeHappened;
  final VoidCallback onOverview;
  final VoidCallback onPain;
  final VoidCallback onSwitchUnits;
  final VoidCallback onDismissUnits;
  final String? adjustmentNotice;

  @override
  Widget build(BuildContext context) {
    final index = SessionPresentation.exercisePosition(runtime.state, entry);
    final savedSwapWork = SessionPresentation.savedSwapWork(
      runtime.state,
      entry,
    );
    final load = SessionPresentation.suggestionLoad(
      entry,
      override: runtime.loadOverrides[entry.exerciseId],
    );
    final isFirstExposure = !SessionPresentation.hasLoggedExercise(
      runtime.history,
      runtime.state,
      entry,
    );
    return SafeArea(
      child: Column(
        children: [
          _ExerciseProgress(
            current: index,
            total: SessionPresentation.exerciseCount(runtime.state),
            onTap: onOverview,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!runtime.unitPromptSeen)
                        _UnitPrompt(
                          unitSystem: runtime.displayUnitSystem,
                          onSwitch: onSwitchUnits,
                          onDismiss: onDismissUnits,
                        ),
                      if (adjustmentNotice case final notice?) ...[
                        _SessionAdjustmentCard(text: notice),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (savedSwapWork case final savedWork?) ...[
                        _SavedSwapWorkCard(text: savedWork),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        entry.planExercise.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        SessionPresentation.cue(entry),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _LearnEntry(
                        entry: entry,
                        expanded: isFirstExposure,
                        onTap: onSetup,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SetPills(
                        entry: entry,
                        unitSystem: runtime.displayUnitSystem,
                        onCompletedSetTap: onReviewSet,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PrescriptionCard(
                        entry: entry,
                        load: load,
                        reps: reps,
                        unitSystem: runtime.displayUnitSystem,
                        onEdit: onEdit,
                        compact: isFirstExposure,
                      ),
                      if (entry.prescription.bridge case final bridge?)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: _BridgeCard(
                            bridge: bridge,
                            unitSystem: runtime.displayUnitSystem,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      AppPressScale(
                        child: FilledButton(
                          key: const ValueKey('set-done'),
                          onPressed: onDone,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(64),
                            textStyle: Theme.of(context).textTheme.titleLarge,
                          ),
                          child: const Text('Done'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _AmbientSessionStrip(
                        nextExercise: SessionPresentation.nextExercise(
                          runtime.state,
                          entry,
                        ),
                        onLifeHappened: onLifeHappened,
                        onOverview: onOverview,
                      ),
                      _PainLink(onPressed: onPain),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationTryCard extends StatelessWidget {
  const _CalibrationTryCard({
    required this.reps,
    required this.load,
    required this.unitSystem,
    required this.cue,
  });

  final int reps;
  final engine.Kg load;
  final engine.UnitSystem unitSystem;
  final String cue;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('calibration-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.blushSoft,
        border: Border.all(color: AppColors.rose, width: 1.5),
        borderRadius: AppRadii.largeBorder,
      ),
      child: Column(
        children: [
          Text(
            'TRY THIS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.roseDeep,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('$reps reps', style: Theme.of(context).textTheme.displaySmall),
          Text(
            'with ${SessionPresentation.formatLoad(load, unitSystem)}',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppColors.roseDeep),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            cue,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ReassuranceCard extends StatelessWidget {
  const _ReassuranceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.sageSoft,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.favorite_outline_rounded,
            color: AppColors.sage,
            size: 21,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starting light is part of the plan',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Nobody is watching your number. This is how the movement becomes yours. The weight follows quickly.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionAdjustmentCard extends StatelessWidget {
  const _SessionAdjustmentCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('session-adjustment-card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.lavenderSoft,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.favorite_outline_rounded,
            color: AppColors.lavender,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedSwapWorkCard extends StatelessWidget {
  const _SavedSwapWorkCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('saved-swap-work'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.sageSoft,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, color: AppColors.sage, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseProgress extends StatelessWidget {
  const _ExerciseProgress({
    required this.current,
    required this.total,
    required this.onTap,
  });

  final int current;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : current / total,
              borderRadius: AppRadii.smallBorder,
              color: AppColors.rose,
              backgroundColor: AppColors.blushSoft,
              minHeight: 6,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: AppColors.blushSoft,
            borderRadius: AppRadii.largeBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('exercise-progress'),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$current of $total',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: AppColors.roseDeep,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseVisualCard extends StatelessWidget {
  const _ExerciseVisualCard({
    required this.entry,
    required this.aspectRatio,
    required this.onWatch,
  });

  final engine.SessionExerciseEntry entry;
  final double aspectRatio;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ExerciseVisual(
          exerciseId: entry.exerciseId,
          exerciseName: entry.planExercise.name,
          blockRoleLabel: SessionPresentation.blockRole(
            entry.planExercise.blockRole,
          ),
          aspectRatio: aspectRatio,
        ),
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: Material(
            color: AppColors.paper.withValues(alpha: 0.92),
            borderRadius: AppRadii.largeBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('watch-movement'),
              onTap: onWatch,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      color: AppColors.roseDeep,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'See the movement',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LearnEntry extends StatelessWidget {
  const _LearnEntry({
    required this.entry,
    required this.expanded,
    required this.onTap,
  });

  final engine.SessionExerciseEntry entry;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadii.mediumBorder,
      side: const BorderSide(color: AppColors.line, width: 1.5),
    );
    return Material(
      key: ValueKey(expanded ? 'new-move-card' : 'learn-strip'),
      color: expanded ? AppColors.blushSoft : AppColors.paper,
      elevation: 2,
      shadowColor: AppColors.ink.withValues(alpha: 0.12),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('show-me-how'),
        onTap: onTap,
        child: expanded ? _expanded(context) : _compact(context),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: [
          SizedBox.square(dimension: 64, child: _LearnVisual(entry: entry)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Show me how',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Movement, setup and where to find it',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.inkFaint,
            size: 21,
          ),
        ],
      ),
    );
  }

  Widget _expanded(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExerciseVisual(
                exerciseId: entry.exerciseId,
                exerciseName: entry.planExercise.name,
                blockRoleLabel: SessionPresentation.blockRole(
                  entry.planExercise.blockRole,
                ),
                compact: true,
              ),
              Positioned(
                left: AppSpacing.sm,
                top: AppSpacing.sm,
                child: Container(
                  key: const ValueKey('new-move-chip'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.94),
                    borderRadius: AppRadii.largeBorder,
                  ),
                  child: Text(
                    'New move',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.roseDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Show me how',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' · movement, setup and where to find it',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkFaint,
                size: 21,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LearnVisual extends StatelessWidget {
  const _LearnVisual({required this.entry});

  final engine.SessionExerciseEntry entry;

  @override
  Widget build(BuildContext context) {
    return ExerciseVisual(
      exerciseId: entry.exerciseId,
      exerciseName: entry.planExercise.name,
      blockRoleLabel: SessionPresentation.blockRole(
        entry.planExercise.blockRole,
      ),
      compact: true,
    );
  }
}

class _SetPills extends StatelessWidget {
  const _SetPills({
    required this.entry,
    required this.unitSystem,
    required this.onCompletedSetTap,
  });

  final engine.SessionExerciseEntry entry;
  final engine.UnitSystem unitSystem;
  final ValueChanged<int> onCompletedSetTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var index = 0; index < entry.prescription.dose.sets; index++)
          _SetPill(
            key: ValueKey('set-pill-${entry.exerciseId}-${index + 1}'),
            stateKey: ValueKey(
              index < entry.setLogs.length
                  ? 'completed-set-${index + 1}'
                  : 'set-${index + 1}',
            ),
            text: index < entry.setLogs.length
                ? _completedSetLabel(entry.setLogs[index])
                : index == entry.setLogs.length
                ? 'Set ${index + 1} of ${entry.prescription.dose.sets}'
                : 'Set ${index + 1}',
            color: index < entry.setLogs.length
                ? AppColors.sageSoft
                : index == entry.setLogs.length
                ? AppColors.blush
                : AppColors.paper,
            textColor: index < entry.setLogs.length
                ? AppColors.sage
                : AppColors.inkSoft,
            completed: index < entry.setLogs.length,
            onTap: index < entry.setLogs.length
                ? () => onCompletedSetTap(index)
                : null,
          ),
      ],
    );
  }

  String _completedSetLabel(engine.SetCompleted set) => set.load.isZero
      ? '${set.reps} reps'
      : '${set.reps} × ${SessionPresentation.formatLoad(set.load, unitSystem)}';
}

class _SetPill extends StatefulWidget {
  const _SetPill({
    required this.text,
    required this.color,
    required this.textColor,
    required this.completed,
    required this.onTap,
    required this.stateKey,
    super.key,
  });

  final String text;
  final Color color;
  final Color textColor;
  final bool completed;
  final VoidCallback? onTap;
  final Key stateKey;

  @override
  State<_SetPill> createState() => _SetPillState();
}

class _SetPillState extends State<_SetPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    value: 1,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.06,
      ).chain(CurveTween(curve: AppMotion.standardCurve)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.06,
        end: 1.0,
      ).chain(CurveTween(curve: AppMotion.standardCurve)),
      weight: 55,
    ),
  ]).animate(_pop);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pop.duration = AppMotion.duration(context, AppMotion.setPop);
  }

  @override
  void didUpdateWidget(covariant _SetPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.completed && widget.completed) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedContainer(
        key: widget.stateKey,
        duration: AppMotion.duration(context, AppMotion.state),
        curve: AppMotion.standardCurve,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: AppRadii.largeBorder,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadii.largeBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.feedback),
                    switchInCurve: AppMotion.entranceCurve,
                    switchOutCurve: AppMotion.standardCurve,
                    child: widget.completed
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('set-check'),
                            color: widget.textColor,
                            size: 15,
                          )
                        : const SizedBox(key: ValueKey('set-check-empty')),
                  ),
                  if (widget.completed) const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: AppMotion.duration(context, AppMotion.state),
                      switchInCurve: AppMotion.entranceCurve,
                      switchOutCurve: AppMotion.standardCurve,
                      child: Text(
                        widget.text,
                        key: ValueKey(widget.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: widget.textColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientSessionStrip extends StatelessWidget {
  const _AmbientSessionStrip({
    required this.nextExercise,
    required this.onLifeHappened,
    required this.onOverview,
  });

  final engine.SessionExerciseEntry? nextExercise;
  final VoidCallback onLifeHappened;
  final VoidCallback onOverview;

  @override
  Widget build(BuildContext context) {
    final nextName = nextExercise?.planExercise.name;
    return Container(
      key: const ValueKey('ambient-session-strip'),
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: AppRadii.smallBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('life-happened-link'),
              onTap: onLifeHappened,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.umbrella_outlined,
                      color: AppColors.inkSoft,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Life happened?',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(
            width: 1,
            indent: AppSpacing.sm,
            endIndent: AppSpacing.sm,
            color: AppColors.line,
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('ambient-session-overview'),
                onTap: onOverview,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    right: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          nextName == null
                              ? "Last one · then you're done"
                              : 'Up next · $nextName',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.inkSoft,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                        ),
                      ),
                      if (nextName != null) ...[
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.inkFaint,
                          size: 17,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PainLink extends StatelessWidget {
  const _PainLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: TextButton.icon(
        key: const ValueKey('pain-affordance'),
        onPressed: onPressed,
        icon: const Icon(Icons.healing_rounded, size: 17),
        label: const Text('That hurt'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.inkFaint,
          textStyle: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.entry,
    required this.load,
    required this.reps,
    required this.unitSystem,
    required this.onEdit,
    required this.compact,
  });

  final engine.SessionExerciseEntry entry;
  final engine.Kg load;
  final int reps;
  final engine.UnitSystem unitSystem;
  final VoidCallback onEdit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final main = switch (entry.prescription.suggestion) {
      engine.SuggestedLoad() =>
        '${SessionPresentation.formatLoad(load, unitSystem)} · $reps reps',
      engine.BodyweightOnly(:final added) =>
        added.isZero
            ? 'Bodyweight · $reps reps'
            : 'Bodyweight + ${SessionPresentation.formatLoad(load, unitSystem)} · $reps reps',
      engine.NeedsCalibration() =>
        '${SessionPresentation.formatLoad(load, unitSystem)} · $reps reps',
      engine.RepOrDurationTarget(:final hold) when hold != null =>
        '${hold.inSeconds} second hold',
      engine.RepOrDurationTarget(:final reps) => '$reps reps',
    };
    return InkWell(
      key: const ValueKey('prescription-card'),
      onTap: onEdit,
      borderRadius: AppRadii.mediumBorder,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 80 : 108),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : 18,
          vertical: compact ? AppSpacing.sm : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: compact
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.paper, AppColors.blushSoft],
                ),
          color: compact ? AppColors.paper : null,
          borderRadius: AppRadii.mediumBorder,
          border: Border.all(
            color: compact ? AppColors.line : AppColors.blush,
            width: 1.5,
          ),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.state),
                    reverseDuration: AppMotion.exitDuration(
                      context,
                      AppMotion.state,
                    ),
                    switchInCurve: AppMotion.entranceCurve,
                    switchOutCurve: AppMotion.standardCurve,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      main,
                      key: ValueKey(main),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: compact ? 24 : 31,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    SessionPresentation.prescriptionNote(entry),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.edit_outlined, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

/*
 * Kept below the set hero so adjustment guidance still appears in the same
 * place without competing with the primary prescription.
 */
class _BridgeCard extends StatelessWidget {
  const _BridgeCard({required this.bridge, required this.unitSystem});

  final engine.DropBridge bridge;
  final engine.UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final text = switch (bridge) {
      engine.DropSetBridge(
        :final backOffLoad,
        :final backOffRepsMin,
        :final backOffRepsMax,
      ) =>
        'If the jump feels big, do what you can, then use ${SessionPresentation.formatLoad(backOffLoad, unitSystem)} for $backOffRepsMin to $backOffRepsMax reps.',
      engine.EasierVariationBridge() =>
        'There is an easier variation ready if this jump feels too large.',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.lavenderSoft,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.call_split_rounded,
            color: AppColors.lavender,
            size: 21,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A gentler bridge',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/*
 * The remaining helpers are shared by both exercise modes.
 */
class _UnitPrompt extends StatelessWidget {
  const _UnitPrompt({
    required this.unitSystem,
    required this.onSwitch,
    required this.onDismiss,
  });

  final engine.UnitSystem unitSystem;
  final VoidCallback onSwitch;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final current = unitSystem.isMetric ? 'kg' : 'lb';
    final other = unitSystem.isMetric ? 'lb' : 'kg';
    return Container(
      key: const ValueKey('unit-prompt'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.blushSoft,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing weights in $current. Switch to $other?',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          TextButton(
            key: const ValueKey('switch-units'),
            onPressed: onSwitch,
            child: const Text('Switch'),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.blushSoft,
        borderRadius: AppRadii.largeBorder,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.roseDeep),
      ),
    );
  }
}
