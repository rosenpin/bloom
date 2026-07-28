import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/theme/app_colors.dart';
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
                      FilledButton(
                        key: const ValueKey('calibration-done'),
                        onPressed: onDone,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(60),
                        ),
                        child: Text("I've done my ${probe.probeReps} reps"),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ExerciseSupportLinks(
                        onSetup: onSetup,
                        onLifeHappened: onLifeHappened,
                        onPain: onPain,
                      ),
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
    return SafeArea(
      child: Column(
        children: [
          _ExerciseProgress(
            current: index,
            total: SessionPresentation.exerciseCount(runtime.state),
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
                      _ExerciseVisualCard(
                        entry: entry,
                        aspectRatio: 5 / 6,
                        onWatch: onSetup,
                      ),
                      const SizedBox(height: AppSpacing.md),
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
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        key: const ValueKey('set-done'),
                        onPressed: onDone,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(64),
                          textStyle: Theme.of(context).textTheme.titleLarge,
                        ),
                        child: const Text('Done'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ExerciseSupportLinks(
                        onSetup: onSetup,
                        onLifeHappened: onLifeHappened,
                        onPain: onPain,
                      ),
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
  const _ExerciseProgress({required this.current, required this.total});

  final int current;
  final int total;

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
          Text(
            '$current of $total',
            key: const ValueKey('exercise-progress'),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.inkSoft),
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
                      Icons.play_arrow_rounded,
                      color: AppColors.roseDeep,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Watch the movement',
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
            key: ValueKey(
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

class _SetPill extends StatelessWidget {
  const _SetPill({
    required this.text,
    required this.color,
    required this.textColor,
    required this.completed,
    required this.onTap,
    super.key,
  });

  final String text;
  final Color color;
  final Color textColor;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: AppRadii.largeBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (completed) ...[
                Icon(Icons.check_rounded, color: textColor, size: 15),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseSupportLinks extends StatelessWidget {
  const _ExerciseSupportLinks({
    required this.onSetup,
    required this.onLifeHappened,
    required this.onPain,
  });

  final VoidCallback onSetup;
  final VoidCallback onLifeHappened;
  final VoidCallback onPain;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            TextButton(
              key: const ValueKey('exercise-setup-link'),
              onPressed: onSetup,
              child: const Text('How do I set up?'),
            ),
            TextButton(
              key: const ValueKey('life-happened-link'),
              onPressed: onLifeHappened,
              child: const Text('Life happened?'),
            ),
          ],
        ),
        TextButton.icon(
          key: const ValueKey('pain-affordance'),
          onPressed: onPain,
          icon: const Icon(Icons.healing_rounded, size: 17),
          label: const Text('That hurt'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.inkFaint,
            textStyle: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: AppRadii.mediumBorder,
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(main, style: Theme.of(context).textTheme.titleLarge),
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
            const Icon(Icons.edit_outlined, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

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
