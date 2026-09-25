import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
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
    final firstExercise = index == 1 && entry.setLogs.isEmpty;
    return SafeArea(
      child: Column(
        children: [
          _ExerciseProgress(
            current: index,
            total: SessionPresentation.exerciseCount(runtime.state),
            onTap: onOverview,
            notice: adjustmentNotice,
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
                      Text(
                        'FIRST TIME · FINDING YOUR WEIGHT',
                        style: AppText.label,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        entry.planExercise.name,
                        key: const ValueKey('calibration-heading'),
                        style: AppText.title,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ExerciseVisualCard(entry: entry, onWatch: onSetup),
                      const SizedBox(height: AppSpacing.md),
                      _CalibrationTryCard(
                        reps: probe.probeReps,
                        load: load,
                        unitSystem: runtime.displayUnitSystem,
                        cue: SessionPresentation.cue(entry),
                        showUnits: firstExercise && !runtime.unitPromptSeen,
                        onSwitchUnits: onSwitchUnits,
                        onDismissUnits: onDismissUnits,
                      ),
                      if (firstExercise) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Starting light is part of the plan.',
                          style: AppText.meta,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          _ExerciseActionZone(
            primaryKey: const ValueKey('calibration-done'),
            primaryLabel: "I've done my ${probe.probeReps} reps",
            onDone: onDone,
            onLifeHappened: onLifeHappened,
            onPain: onPain,
            onOverview: onOverview,
            nextExercise: SessionPresentation.nextExercise(
              runtime.state,
              entry,
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
            notice: adjustmentNotice,
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
                      if (savedSwapWork case final savedWork?) ...[
                        _SavedSwapWorkCard(text: savedWork),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(entry.planExercise.name, style: AppText.title),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(SessionPresentation.cue(entry), style: AppText.meta),
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
                      ),
                      if (entry.prescription.bridge case final bridge?)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: _BridgeCard(
                            bridge: bridge,
                            unitSystem: runtime.displayUnitSystem,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _ExerciseActionZone(
            primaryKey: const ValueKey('set-done'),
            primaryLabel: 'Done',
            onDone: onDone,
            onLifeHappened: onLifeHappened,
            onPain: onPain,
            onOverview: onOverview,
            nextExercise: SessionPresentation.nextExercise(
              runtime.state,
              entry,
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
    required this.showUnits,
    required this.onSwitchUnits,
    required this.onDismissUnits,
  });

  final int reps;
  final engine.Kg load;
  final engine.UnitSystem unitSystem;
  final String cue;
  final bool showUnits;
  final VoidCallback onSwitchUnits;
  final VoidCallback onDismissUnits;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('calibration-card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.line),
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('TRY THIS', style: AppText.label)),
              if (showUnits)
                _UnitToggle(
                  unitSystem: unitSystem,
                  onSwitch: onSwitchUnits,
                  onConfirm: onDismissUnits,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$reps reps · ${SessionPresentation.formatLoad(load, unitSystem)}',
            style: AppText.hero,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(cue, style: AppText.meta),
        ],
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.unitSystem,
    required this.onSwitch,
    required this.onConfirm,
  });

  final engine.UnitSystem unitSystem;
  final VoidCallback onSwitch;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('unit-prompt'),
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final metric in [true, false])
        SizedBox(
          height: AppSizes.tapTarget,
          child: OutlinedButton(
            key: ValueKey(metric ? 'unit-kg' : 'unit-lb'),
            onPressed: unitSystem.isMetric == metric ? onConfirm : onSwitch,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              backgroundColor: unitSystem.isMetric == metric
                  ? AppColors.rose
                  : AppColors.paper,
              foregroundColor: unitSystem.isMetric == metric
                  ? AppColors.paper
                  : AppColors.inkSoft,
              side: BorderSide(
                color: unitSystem.isMetric == metric
                    ? AppColors.rose
                    : AppColors.line,
              ),
              minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
            ),
            child: Text(
              metric ? 'kg' : 'lb',
              style: AppText.meta.copyWith(
                color: unitSystem.isMetric == metric
                    ? AppColors.paper
                    : AppColors.inkSoft,
              ),
            ),
          ),
        ),
    ],
  );
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
          const Icon(
            Icons.check_rounded,
            color: AppColors.sage,
            size: AppSizes.iconMedium,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppText.meta)),
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
    this.notice,
  });

  final int current;
  final int total;
  final VoidCallback onTap;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : current / total,
                  borderRadius: AppRadii.smallBorder,
                  color: AppColors.rose,
                  backgroundColor: AppColors.blushSoft,
                  minHeight: AppSizes.progressBar,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.largeBorder,
                  side: const BorderSide(color: AppColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('exercise-progress'),
                  onTap: onTap,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.tapTarget,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$current of $total', style: AppText.meta),
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
          // The confirmation of a change gets its own full line, eased in,
          // rather than an ellipsis squeezed beside the progress bar.
          AnimatedSize(
            duration: AppMotion.duration(context, AppMotion.state),
            curve: AppMotion.standardCurve,
            alignment: Alignment.topCenter,
            child: notice == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      notice!,
                      key: const ValueKey('session-adjustment-card'),
                      style: AppText.meta.copyWith(color: AppColors.roseDeep),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The move at a glance: both positions in one full-width card. The whole
/// card opens the full-size movement view. Its label sits in a row below the
/// pictures rather than over them, where it covered her feet or head.
class _ExerciseVisualCard extends StatelessWidget {
  const _ExerciseVisualCard({required this.entry, required this.onWatch});

  final engine.SessionExerciseEntry entry;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'See the movement, ${entry.planExercise.name}',
      onTap: onWatch,
      excludeSemantics: true,
      child: AppPressScale(
        child: Material(
          color: AppColors.paper,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mediumBorder,
            side: const BorderSide(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('watch-movement'),
            onTap: onWatch,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExerciseDiptych(
                  exerciseId: entry.exerciseId,
                  exerciseName: entry.planExercise.name,
                  blockRoleLabel: SessionPresentation.blockRole(
                    entry.planExercise.blockRole,
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
                      const Icon(
                        Icons.visibility_outlined,
                        color: AppColors.roseDeep,
                        size: AppSizes.iconMedium,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'See the movement',
                          style: AppText.bodyStrong,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.inkFaint,
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      side: const BorderSide(color: AppColors.line),
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
          SizedBox.square(
            dimension: AppSizes.thumbnailMd,
            child: _LearnVisual(entry: entry),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Show me how', style: AppText.bodyStrong),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Movement, setup and where to find it',
                  style: AppText.meta,
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
        Stack(
          children: [
            ExerciseDiptych(
              exerciseId: entry.exerciseId,
              exerciseName: entry.planExercise.name,
              blockRoleLabel: SessionPresentation.blockRole(
                entry.planExercise.blockRole,
              ),
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
                  'NEW MOVE',
                  style: AppText.label.copyWith(color: AppColors.roseDeep),
                ),
              ),
            ),
          ],
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
                      TextSpan(text: 'Show me how', style: AppText.bodyStrong),
                      TextSpan(
                        text: ' · movement, setup and where to find it',
                        style: AppText.meta,
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
            color: index == entry.setLogs.length
                ? AppColors.rose
                : AppColors.paper,
            textColor: index < entry.setLogs.length
                ? AppColors.sage
                : index == entry.setLogs.length
                ? AppColors.paper
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
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        duration: AppMotion.duration(context, AppMotion.state),
        curve: AppMotion.standardCurve,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: AppRadii.largeBorder,
          border: Border.all(
            color: widget.completed
                ? AppColors.sage
                : widget.color == AppColors.rose
                ? AppColors.rose
                : AppColors.line,
          ),
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
                            size: AppSizes.iconSmall,
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
                        style: AppText.meta.copyWith(color: widget.textColor),
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

class _ExerciseActionZone extends StatelessWidget {
  const _ExerciseActionZone({
    required this.primaryKey,
    required this.primaryLabel,
    required this.onDone,
    required this.onLifeHappened,
    required this.onPain,
    required this.onOverview,
    required this.nextExercise,
  });

  final Key primaryKey;
  final String primaryLabel;
  final VoidCallback onDone;
  final VoidCallback onLifeHappened;
  final VoidCallback onPain;
  final VoidCallback onOverview;
  final engine.SessionExerciseEntry? nextExercise;

  @override
  Widget build(BuildContext context) {
    final nextName = nextExercise?.planExercise.name;
    return Container(
      key: const ValueKey('exercise-action-zone'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                key: const ValueKey('ambient-session-overview'),
                onTap: onOverview,
                child: SizedBox(
                  height: AppSizes.secondaryButton,
                  child: Center(
                    child: Text(
                      nextName == null
                          ? "Last one · then you're done"
                          : 'Up next · $nextName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta,
                    ),
                  ),
                ),
              ),
              AppPressScale(
                child: FilledButton(
                  key: primaryKey,
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                    textStyle: AppText.bodyStrong,
                  ),
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('life-happened-link'),
                      onPressed: onLifeHappened,
                      icon: const Icon(
                        Icons.umbrella_outlined,
                        size: AppSizes.iconSmall,
                      ),
                      label: const Text('Life happened?'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkSoft,
                        minimumSize: const Size.fromHeight(AppSizes.tapTarget),
                        textStyle: AppText.meta,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('pain-affordance'),
                      onPressed: onPain,
                      icon: const Icon(
                        Icons.healing_rounded,
                        size: AppSizes.iconSmall,
                      ),
                      label: const Text('That hurt'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkSoft,
                        minimumSize: const Size.fromHeight(AppSizes.tapTarget),
                        textStyle: AppText.meta,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
  });

  final engine.SessionExerciseEntry entry;
  final engine.Kg load;
  final int reps;
  final engine.UnitSystem unitSystem;
  final VoidCallback onEdit;

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
        constraints: const BoxConstraints(minHeight: AppSizes.thumbnailLg),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: AppRadii.mediumBorder,
          border: Border.all(color: AppColors.line),
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
                    child: Text(main, key: ValueKey(main), style: AppText.hero),
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
                const Text('A gentler bridge', style: AppText.bodyStrong),
                const SizedBox(height: AppSpacing.xxs),
                Text(text, style: AppText.meta),
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
