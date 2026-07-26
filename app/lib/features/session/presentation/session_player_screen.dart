import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../plan/domain/plan_presentation.dart';
import '../application/rest_timer_foundation.dart';
import '../application/session_controller.dart';
import '../application/session_lifecycle_service.dart';
import '../data/exercise_content_repository.dart';
import '../domain/session_presentation.dart';

class SessionPlayerScreen extends ConsumerStatefulWidget {
  const SessionPlayerScreen({super.key});

  @override
  ConsumerState<SessionPlayerScreen> createState() =>
      _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends ConsumerState<SessionPlayerScreen> {
  bool _begun = false;
  bool _showComplete = false;
  bool _keepSwapShown = false;
  _RestPhase? _rest;
  final Map<String, int> _repOverrides = <String, int>{};
  bool _loggingSet = false;

  @override
  Widget build(BuildContext context) {
    final runtimeValue = ref.watch(sessionControllerProvider);
    return PopScope(
      canPop: _rest == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _rest != null) {
          setState(() => _rest = null);
        }
      },
      child: Scaffold(
        key: const ValueKey('session-player'),
        body: runtimeValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _SessionError(onBack: () => context.go('/today')),
          data: (runtime) {
            if (runtime == null) {
              return _SessionError(onBack: () => context.go('/today'));
            }
            if (_rest case final rest?) {
              return _RestTakeover(
                runtime: runtime,
                phase: rest,
                onEffort: (level) => _reportEffort(rest, level),
                onFinished: _finishRest,
              );
            }
            if (_showComplete || runtime.isComplete) {
              _queueKeepSwap(runtime);
              return _SessionComplete(
                runtime: runtime,
                recap: ref.read(sessionControllerProvider.notifier).recap(),
                onDone: () {
                  ref.read(sessionControllerProvider.notifier).clear();
                  context.go('/today');
                },
              );
            }
            if (!_begun && runtime.state.events.isEmpty) {
              return _SessionStart(
                runtime: runtime,
                onStart: () => setState(() => _begun = true),
                onUsualWeights: () {
                  ref
                      .read(sessionControllerProvider.notifier)
                      .useUsualWeights();
                  setState(() => _begun = true);
                },
              );
            }
            final entry = runtime.activeEntry;
            if (entry == null) {
              return _SessionError(onBack: () => context.go('/today'));
            }
            if (entry.calibration.phase ==
                engine.CalibrationPhase.awaitingEffort) {
              return _CalibrationEffort(
                entry: entry,
                onEffort: (level) async {
                  await ref
                      .read(sessionControllerProvider.notifier)
                      .advance(
                        engine.EffortReported(
                          exerciseId: entry.exerciseId,
                          level: level,
                        ),
                      );
                  if (mounted) setState(() {});
                },
              );
            }
            return _ActiveExercise(
              runtime: runtime,
              entry: entry,
              reps:
                  _repOverrides[entry.exerciseId] ??
                  SessionPresentation.targetReps(entry),
              onDone: () => _completeSet(runtime, entry),
              onEdit: () => _editSet(runtime, entry),
              onSetup: () => _openSetup(entry),
              onLifeHappened: () => _openLifeSheet(runtime, entry),
              onPain: () => _openPainPicker(entry),
              onSwitchUnits: () => _switchUnits(runtime),
              onDismissUnits: () => ref
                  .read(sessionControllerProvider.notifier)
                  .dismissUnitPrompt(),
            );
          },
        ),
      ),
    );
  }

  Future<void> _completeSet(
    SessionRuntime runtime,
    engine.SessionExerciseEntry entry,
  ) async {
    if (_loggingSet) return;
    _loggingSet = true;
    final setIndex = entry.setLogs.length;
    final dose = entry.prescription.dose;
    final reps =
        _repOverrides[entry.exerciseId] ??
        SessionPresentation.targetReps(entry);
    final prescribedLoad = SessionPresentation.suggestionLoad(entry);
    final load = SessionPresentation.suggestionLoad(
      entry,
      override: runtime.loadOverrides[entry.exerciseId],
    );
    final wasCalibration = entry.calibration.isCalibrating;
    final isFinalSet = setIndex + 1 >= dose.sets;

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .advance(
            engine.SetCompleted(
              exerciseId: entry.exerciseId,
              setIndex: setIndex,
              load: load,
              reps: reps,
              unitSystem: runtime.displayUnitSystem,
              targetReps: dose is engine.RepsDose ? dose.targetReps : 1,
              targetRpe: dose is engine.RepsDose ? dose.effort.rpe : null,
              prescribedLoad: prescribedLoad,
            ),
          );
      if (!mounted) return;
      final latest = ref.read(sessionControllerProvider).value;
      if (latest == null) return;
      final next = latest.activeEntry;
      setState(() {
        _rest = _RestPhase(
          exerciseId: entry.exerciseId,
          exerciseName: entry.planExercise.name,
          completedSet: setIndex + 1,
          totalSets: dose.sets,
          askForEffort: wasCalibration || isFinalSet,
          calibration: wasCalibration,
          nextExerciseName: next?.planExercise.name,
          nextSet: next == null
              ? 1
              : next.exerciseId == entry.exerciseId
              ? next.setLogs.length + 1
              : 1,
        );
      });
    } finally {
      _loggingSet = false;
    }
  }

  Future<void> _reportEffort(_RestPhase phase, engine.EffortLevel level) async {
    await ref
        .read(sessionControllerProvider.notifier)
        .advance(
          engine.EffortReported(exerciseId: phase.exerciseId, level: level),
        );
    if (phase.calibration) await _finishRest();
  }

  Future<void> _finishRest() async {
    if (!mounted) return;
    final runtime = ref.read(sessionControllerProvider).value;
    setState(() {
      _rest = null;
      if (runtime?.isComplete ?? false) _showComplete = true;
    });
  }

  Future<void> _editSet(
    SessionRuntime runtime,
    engine.SessionExerciseEntry entry,
  ) async {
    final currentLoad = SessionPresentation.suggestionLoad(
      entry,
      override: runtime.loadOverrides[entry.exerciseId],
    );
    final currentReps =
        _repOverrides[entry.exerciseId] ??
        SessionPresentation.targetReps(entry);
    final result = await showModalBottomSheet<({engine.Kg load, int reps})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (context) => _SetStepperSheet(
        entry: entry,
        unitSystem: runtime.displayUnitSystem,
        config: runtime.state.config,
        initialLoad: currentLoad,
        initialReps: currentReps,
      ),
    );
    if (result == null || !mounted) return;
    ref
        .read(sessionControllerProvider.notifier)
        .overrideLoad(entry.exerciseId, result.load);
    setState(() => _repOverrides[entry.exerciseId] = result.reps);
  }

  Future<void> _openSetup(engine.SessionExerciseEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ExerciseSetupScreen(entry: entry),
      ),
    );
  }

  Future<void> _openLifeSheet(
    SessionRuntime runtime,
    engine.SessionExerciseEntry entry,
  ) async {
    final action = await showModalBottomSheet<_LifeAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (context) => const _LifeHappenedSheet(),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _Busy():
        await _openSwapSheet(entry, engine.SwapReason.busy);
      case _Shorten(:final minutes):
        await ref
            .read(sessionControllerProvider.notifier)
            .advance(engine.Shorten(minutes));
      case _LowEnergy():
        await ref
            .read(sessionControllerProvider.notifier)
            .advance(const engine.LowEnergy());
      case _Abandon():
        await ref
            .read(sessionControllerProvider.notifier)
            .advance(const engine.SessionAbandoned());
        if (mounted) {
          ref.read(sessionControllerProvider.notifier).clear();
          context.go('/today');
        }
    }
  }

  Future<void> _openSwapSheet(
    engine.SessionExerciseEntry entry,
    engine.SwapReason reason, {
    engine.PlanSwapCandidate? recommended,
  }) async {
    final candidate = await showModalBottomSheet<engine.PlanSwapCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (context) => _SwapSheet(entry: entry, recommended: recommended),
    );
    if (candidate == null || !mounted) return;
    await ref
        .read(sessionControllerProvider.notifier)
        .swapToCandidate(candidate, reason: reason);
  }

  Future<void> _openPainPicker(engine.SessionExerciseEntry entry) async {
    final site = await showModalBottomSheet<engine.PainSite>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (context) => const _PainSitePicker(),
    );
    if (site == null || !mounted) return;
    await ref
        .read(sessionControllerProvider.notifier)
        .advance(engine.PainReported(exerciseId: entry.exerciseId, site: site));
    if (!mounted) return;
    final latest = ref.read(sessionControllerProvider).value;
    final recommendation = latest?.state.pendingSwapSuggestions
        .where((item) => item.sourceExerciseId == entry.exerciseId)
        .firstOrNull;
    if (recommendation != null) {
      await _openSwapSheet(
        entry,
        engine.SwapReason.uncomfortable,
        recommended: recommendation.candidate,
      );
    }
  }

  Future<void> _switchUnits(SessionRuntime runtime) async {
    final next = runtime.displayUnitSystem.isMetric
        ? engine.UnitSystem.imperial
        : engine.UnitSystem.metric;
    await ref.read(sessionControllerProvider.notifier).changeUnitSystem(next);
  }

  void _queueKeepSwap(SessionRuntime runtime) {
    if (_keepSwapShown || runtime.state.pendingPlanEditSuggestions.isEmpty) {
      return;
    }
    _keepSwapShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final suggestion = runtime.state.pendingPlanEditSuggestions.first;
      final keep = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: AppColors.paper,
        builder: (context) =>
            _KeepSwapSheet(runtime: runtime, suggestion: suggestion),
      );
      if (keep == true) {
        await ref.read(sessionControllerProvider.notifier).keepSwap(suggestion);
      }
    });
  }
}

class _SessionStart extends StatelessWidget {
  const _SessionStart({
    required this.runtime,
    required this.onStart,
    required this.onUsualWeights,
  });

  final SessionRuntime runtime;
  final VoidCallback onStart;
  final VoidCallback onUsualWeights;

  @override
  Widget build(BuildContext context) {
    final dayName = PlanPresentation.dayName(runtime.day, runtime.answers);
    final isComeback = runtime.isComeback;
    final hasComebackReduction =
        runtime.state.reasonCodes.contains(engine.ReasonCode.layoffTier2) ||
        runtime.state.reasonCodes.contains(engine.ReasonCode.layoffTier3);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                minHeight: constraints.maxHeight - AppSpacing.xxl,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Today'),
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${PlanPresentation.weekdayLabel(runtime.day.dayIndex, runtime.document.plan.days.length)} · $dayName'
                          .toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.coral,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      isComeback ? 'Where were we?' : 'Your session is ready.',
                      key: ValueKey(
                        isComeback
                            ? 'comeback-heading'
                            : 'session-start-heading',
                      ),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      isComeback
                          ? _comebackLine(runtime)
                          : '${runtime.state.exercises.length} exercises. One thing at a time.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _InfoCard(
                      color: AppColors.sageSoft,
                      icon: Icons.directions_bike_outlined,
                      title: '${runtime.day.warmUpMinutes} minute warm-up',
                      body:
                          'Bike or incline walk. Add one light practice set if you want it.',
                    ),
                    if (isComeback) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _InfoCard(
                        color: AppColors.blushSoft,
                        icon: Icons.tune_rounded,
                        title: _comebackAdjustment(runtime),
                        body: hasComebackReduction
                            ? 'The rest of your session stays the same.'
                            : 'Nothing reset while you were away.',
                      ),
                    ],
                    if (runtime.previousMemory case final memory?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _InfoCard(
                        color: AppColors.paper,
                        icon: Icons.history_rounded,
                        title: 'Last session remembered',
                        body:
                            '${memory.completedSets} sets in ${memory.minutes} minutes${memory.lastEffort == null ? '.' : '. You called the final set "${SessionPresentation.effortLabel(memory.lastEffort!).toLowerCase()}".'}',
                      ),
                    ],
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('session-lets-go'),
                      onPressed: onStart,
                      child: Text(isComeback ? 'Start $dayName' : "Let's go"),
                    ),
                    if (hasComebackReduction) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        key: const ValueKey('use-usual-weights'),
                        onPressed: onUsualWeights,
                        child: const Text('Use my usual weights'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _comebackLine(SessionRuntime runtime) {
    final days = runtime.state.daysSinceLastSession ?? 0;
    if (runtime.state.reasonCodes.contains(engine.ReasonCode.layoffTier1)) {
      return '$days days away. Your usual weights are ready.';
    }
    return '$days days away, so today sits a little lighter. That is the only change.';
  }

  static String _comebackAdjustment(SessionRuntime runtime) =>
      runtime.state.reasonCodes.contains(engine.ReasonCode.layoffTier3)
      ? 'Weights are down about 20%.'
      : runtime.state.reasonCodes.contains(engine.ReasonCode.layoffTier2)
      ? 'Weights are down about 10%.'
      : 'Your usual weights are ready.';
}

class _ActiveExercise extends StatelessWidget {
  const _ActiveExercise({
    required this.runtime,
    required this.entry,
    required this.reps,
    required this.onDone,
    required this.onEdit,
    required this.onSetup,
    required this.onLifeHappened,
    required this.onPain,
    required this.onSwitchUnits,
    required this.onDismissUnits,
  });

  final SessionRuntime runtime;
  final engine.SessionExerciseEntry entry;
  final int reps;
  final VoidCallback onDone;
  final VoidCallback onEdit;
  final VoidCallback onSetup;
  final VoidCallback onLifeHappened;
  final VoidCallback onPain;
  final VoidCallback onSwitchUnits;
  final VoidCallback onDismissUnits;

  @override
  Widget build(BuildContext context) {
    final index = runtime.state.exercises.indexOf(entry) + 1;
    final load = SessionPresentation.suggestionLoad(
      entry,
      override: runtime.loadOverrides[entry.exerciseId],
    );
    final isCalibration =
        entry.calibration.phase == engine.CalibrationPhase.awaitingProbe;
    return SafeArea(
      child: Column(
        children: [
          _ExerciseProgress(
            current: index,
            total: runtime.state.exercises.length,
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
                      _ExerciseVisual(entry: entry),
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
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (isCalibration)
                        _CalibrationCard(
                          entry: entry,
                          load: load,
                          unitSystem: runtime.displayUnitSystem,
                          onDone: onDone,
                        )
                      else ...[
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
                      ],
                      const SizedBox(height: AppSpacing.sm),
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
                      Center(
                        child: TextButton.icon(
                          key: const ValueKey('pain-affordance'),
                          onPressed: onPain,
                          icon: const Icon(Icons.healing_rounded, size: 17),
                          label: const Text('That hurt'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.inkFaint,
                            textStyle: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
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

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({
    required this.entry,
    required this.load,
    required this.unitSystem,
    required this.onDone,
  });

  final engine.SessionExerciseEntry entry;
  final engine.Kg load;
  final engine.UnitSystem unitSystem;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final probe = entry.prescription.suggestion as engine.NeedsCalibration;
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
            "Let's find your weight",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'We start deliberately light and let your body tell us.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${SessionPresentation.formatLoad(load, unitSystem)} × ${probe.probeReps} easy reps',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.roseDeep),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('calibration-done'),
            onPressed: onDone,
            child: Text('I did ${probe.probeReps} reps'),
          ),
        ],
      ),
    );
  }
}

class _CalibrationEffort extends StatelessWidget {
  const _CalibrationEffort({required this.entry, required this.onEffort});

  final engine.SessionExerciseEntry entry;
  final Future<void> Function(engine.EffortLevel) onEffort;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'That gives us a starting point.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'How did those reps feel?',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: AppSpacing.lg),
                _EffortOptions(onSelected: onEffort),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestTakeover extends ConsumerStatefulWidget {
  const _RestTakeover({
    required this.runtime,
    required this.phase,
    required this.onEffort,
    required this.onFinished,
  });

  final SessionRuntime runtime;
  final _RestPhase phase;
  final Future<void> Function(engine.EffortLevel) onEffort;
  final Future<void> Function() onFinished;

  @override
  ConsumerState<_RestTakeover> createState() => _RestTakeoverState();
}

class _RestTakeoverState extends ConsumerState<_RestTakeover>
    with WidgetsBindingObserver {
  Timer? _timer;
  late final RestTimerFoundation _foundation;
  late DateTime _endsAt;
  late int _totalSeconds;
  late int _remainingSeconds;
  engine.EffortLevel? _selected;
  bool _finishing = false;

  int get _notificationId =>
      Object.hash(
        widget.runtime.sessionId,
        widget.phase.exerciseId,
        widget.phase.completedSet,
      ) &
      0x7fffffff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foundation = ref.read(restTimerFoundationProvider);
    _totalSeconds = widget.runtime.restDuration.inSeconds;
    _remainingSeconds = _totalSeconds;
    _endsAt = ref.read(clockProvider)().add(widget.runtime.restDuration);
    unawaited(_schedule());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_foundation.cancel(_notificationId));
      _tick();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_schedule());
    }
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _endsAt.difference(ref.read(clockProvider)()).inSeconds;
    if (remaining <= 0) {
      unawaited(_finish());
    } else {
      setState(() => _remainingSeconds = remaining);
    }
  }

  Future<void> _schedule() => _foundation.schedule(
    notificationId: _notificationId,
    endsAt: _endsAt,
    nextSet: widget.phase.nextSet,
    exerciseName: widget.phase.nextExerciseName ?? widget.phase.exerciseName,
  );

  Future<void> _extend() async {
    setState(() {
      _endsAt = _endsAt.add(const Duration(seconds: 30));
      _totalSeconds += 30;
      _remainingSeconds += 30;
    });
    await _schedule();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    await _foundation.cancel(_notificationId);
    await widget.onFinished();
  }

  Future<void> _selectEffort(engine.EffortLevel level) async {
    if (_selected != null) return;
    setState(() => _selected = level);
    await widget.onEffort(level);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_foundation.cancel(_notificationId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = _totalSeconds == 0
        ? 0.0
        : _remainingSeconds / _totalSeconds;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blushSoft, AppColors.blush, AppColors.cream],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  _Pill(
                    text: 'Set ${widget.phase.completedSet} done',
                    color: AppColors.paper.withValues(alpha: 0.75),
                    textColor: AppColors.roseDeep,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: 230,
                    height: 230,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 11,
                            strokeCap: StrokeCap.round,
                            color: AppColors.rose,
                            backgroundColor: AppColors.paper.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$minutes:${seconds.toString().padLeft(2, '0')}',
                              key: const ValueKey('rest-countdown'),
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            Text(
                              'breathe',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.phase.askForEffort) ...[
                    Text(
                      SessionPresentation.feelQuestion(
                        widget.runtime.state.exercises.firstWhere(
                          (entry) =>
                              entry.exerciseId == widget.phase.exerciseId,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(letterSpacing: 0.4),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _EffortOptions(
                      selected: _selected,
                      compact: true,
                      onSelected: _selected == null
                          ? (level) => unawaited(_selectEffort(level))
                          : null,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    children: [
                      OutlinedButton(
                        key: const ValueKey('rest-plus-30'),
                        onPressed: _extend,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(96, 48),
                        ),
                        child: const Text('+30s'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('rest-skip'),
                        onPressed: _finish,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(112, 48),
                        ),
                        child: const Text('Skip rest'),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.paper.withValues(alpha: 0.78),
                      borderRadius: AppRadii.mediumBorder,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UP NEXT',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.coral,
                                letterSpacing: 1.1,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          widget.phase.nextExerciseName == null
                              ? 'Session recap'
                              : 'Set ${widget.phase.nextSet} · ${widget.phase.nextExerciseName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
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

class ExerciseSetupScreen extends ConsumerStatefulWidget {
  const ExerciseSetupScreen({required this.entry, super.key});

  final engine.SessionExerciseEntry entry;

  @override
  ConsumerState<ExerciseSetupScreen> createState() =>
      _ExerciseSetupScreenState();
}

class _ExerciseSetupScreenState extends ConsumerState<ExerciseSetupScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('exercise-setup-screen'),
      appBar: AppBar(title: Text(widget.entry.planExercise.name)),
      body: FutureBuilder<ExerciseGuidance?>(
        future: ref
            .read(exerciseContentRepositoryProvider)
            .loadGuidance(widget.entry.exerciseId),
        builder: (context, snapshot) {
          final guidance = snapshot.data;
          if (guidance == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ExerciseVisual(entry: widget.entry, height: 225),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Set up')),
                        ButtonSegment(value: 1, label: Text('How it feels')),
                        ButtonSegment(value: 2, label: Text('Swaps')),
                      ],
                      selected: {_tab},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) =>
                          setState(() => _tab = value.first),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_tab == 0) ...[
                      for (
                        var index = 0;
                        index < guidance.setupSteps.length;
                        index++
                      )
                        _NumberedStep(
                          number: index + 1,
                          text: guidance.setupSteps[index],
                        ),
                      _InfoCard(
                        color: AppColors.blushSoft,
                        icon: Icons.location_on_outlined,
                        title: 'Find it',
                        body: guidance.findIt,
                      ),
                    ] else if (_tab == 1) ...[
                      _InfoCard(
                        color: AppColors.sageSoft,
                        icon: Icons.check_rounded,
                        title: 'Should feel',
                        body: guidance.shouldFeel,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoCard(
                        color: AppColors.blushSoft,
                        icon: Icons.pan_tool_outlined,
                        title: 'Stop if',
                        body: guidance.stopIf,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Helpful cues',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final item in guidance.dos)
                        ListTile(
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.sage,
                          ),
                          title: Text(item),
                          contentPadding: EdgeInsets.zero,
                        ),
                      for (final item in guidance.donts)
                        ListTile(
                          leading: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.coral,
                          ),
                          title: Text(item),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ] else ...[
                      Text(
                        'These keep the same job in your session.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final candidate in guidance.swaps)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(candidate.name),
                          subtitle: Text(
                            candidate.tier <= 2 ? 'Good match' : 'Looser match',
                          ),
                          trailing: Text('Tier ${candidate.tier}'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LifeHappenedSheet extends StatefulWidget {
  const _LifeHappenedSheet();

  @override
  State<_LifeHappenedSheet> createState() => _LifeHappenedSheetState();
}

class _LifeHappenedSheetState extends State<_LifeHappenedSheet> {
  bool _showTimes = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              "What's going on?",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tell us and we will rearrange the rest. Your plan stays on track.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.md),
            _SheetOption(
              key: const ValueKey('life-busy'),
              icon: Icons.swap_horiz_rounded,
              title: "Someone's on the equipment",
              subtitle: 'We will find the closest match.',
              onTap: () => Navigator.pop(context, const _Busy()),
            ),
            _SheetOption(
              key: const ValueKey('life-shorten'),
              icon: Icons.schedule_rounded,
              title: 'I only have a few minutes',
              subtitle: 'Keep the moves that matter most.',
              onTap: () => setState(() => _showTimes = !_showTimes),
            ),
            if (_showTimes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final minutes in const [15, 20, 30])
                      ActionChip(
                        key: ValueKey('shorten-$minutes'),
                        label: Text('$minutes min'),
                        onPressed: () =>
                            Navigator.pop(context, _Shorten(minutes)),
                      ),
                  ],
                ),
              ),
            _SheetOption(
              key: const ValueKey('life-low-energy'),
              icon: Icons.bedtime_outlined,
              title: 'My energy is low today',
              subtitle: 'Same session shape, lighter from here.',
              onTap: () => Navigator.pop(context, const _LowEnergy()),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const ValueKey('life-abandon'),
              onPressed: () => Navigator.pop(context, const _Abandon()),
              child: const Text('I need to stop for today'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({required this.entry, this.recommended});

  final engine.SessionExerciseEntry entry;
  final engine.PlanSwapCandidate? recommended;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final candidates =
        widget.entry.planExercise.orderedSwapCandidates.toList(growable: false)
          ..sort((left, right) {
            if (left.tier != right.tier) {
              return left.tier.compareTo(right.tier);
            }
            return left.rank.compareTo(right.rank);
          });
    final preferred = [
      ?widget.recommended,
      for (final item in candidates)
        if (item.tier <= 2 && item.exerciseId != widget.recommended?.exerciseId)
          item,
    ];
    final other = candidates.where((item) => item.tier == 3);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Text(
                'Choose a swap',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Each option gets its own weight and rep target.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final candidate in preferred)
                _SwapOption(
                  candidate: candidate,
                  recommended:
                      candidate.exerciseId == widget.recommended?.exerciseId,
                ),
              if (other.isNotEmpty)
                TextButton(
                  key: const ValueKey('swap-something-else'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? 'Hide other options'
                        : 'Something else (not recommended)',
                  ),
                ),
              if (_expanded)
                for (final candidate in other)
                  _SwapOption(candidate: candidate, notRecommended: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _PainSitePicker extends StatelessWidget {
  const _PainSitePicker();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              'Leave that movement there.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Where did you feel it? We will offer a kinder option.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final site in engine.PainSite.values)
                  ActionChip(
                    key: ValueKey('pain-${site.name}'),
                    label: Text(_painLabel(site)),
                    onPressed: () => Navigator.pop(context, site),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _painLabel(engine.PainSite site) => switch (site) {
    engine.PainSite.knee => 'Knee',
    engine.PainSite.hip => 'Hip',
    engine.PainSite.lowBack => 'Lower back',
    engine.PainSite.midBack => 'Mid back',
    engine.PainSite.shoulder => 'Shoulder',
    engine.PainSite.elbow => 'Elbow',
    engine.PainSite.wrist => 'Wrist',
    engine.PainSite.neck => 'Neck',
    engine.PainSite.ankle => 'Ankle',
    engine.PainSite.other => 'Somewhere else',
  };
}

class _KeepSwapSheet extends StatelessWidget {
  const _KeepSwapSheet({required this.runtime, required this.suggestion});

  final SessionRuntime runtime;
  final engine.PendingPlanEditSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final source = _exerciseName(runtime, suggestion.sourceExerciseId);
    final replacement = _exerciseName(runtime, suggestion.replacementId);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              "Keep today's swap?",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You used $replacement instead of $source.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const ValueKey('keep-swap-yes'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, make it my usual'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const ValueKey('keep-swap-no'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, just for today'),
            ),
          ],
        ),
      ),
    );
  }

  static String _exerciseName(SessionRuntime runtime, String id) {
    for (final day in runtime.document.plan.days) {
      for (final exercise in day.exercises) {
        if (exercise.exerciseId == id) return exercise.name;
        for (final swap in exercise.orderedSwapCandidates) {
          if (swap.exerciseId == id) return swap.name;
        }
      }
    }
    return id;
  }
}

class _SessionComplete extends StatelessWidget {
  const _SessionComplete({
    required this.runtime,
    required this.recap,
    required this.onDone,
  });

  final SessionRuntime runtime;
  final Future<SessionRecap?> recap;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<SessionRecap?>(
        future: recap,
        builder: (context, snapshot) {
          final value = snapshot.data;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    const Icon(
                      Icons.local_florist_rounded,
                      color: AppColors.rose,
                      size: 44,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'That session is done.',
                      key: const ValueKey('session-complete-heading'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      PlanPresentation.dayName(runtime.day, runtime.answers),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (value == null)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      _AdherenceDots(
                        completed: value.completedThisWeek,
                        total: value.plannedThisWeek,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _StatCard(
                        value: SessionPresentation.formatLoad(
                          value.totalLoad,
                          runtime.displayUnitSystem,
                        ),
                        label:
                            'moved today, ${SessionPresentation.dayComparison(value.totalLoad)}',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: '${value.duration.inMinutes} min',
                              label: 'from start to finish',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              value: '${value.totalSessions}',
                              label: 'sessions together',
                            ),
                          ),
                        ],
                      ),
                      if (value.weekStreak case final streak?) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _StatCard(
                          value: '$streak weeks',
                          label: 'with training in each week',
                        ),
                      ],
                    ],
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('session-complete-done'),
                      onPressed: onDone,
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SetStepperSheet extends StatefulWidget {
  const _SetStepperSheet({
    required this.entry,
    required this.unitSystem,
    required this.config,
    required this.initialLoad,
    required this.initialReps,
  });

  final engine.SessionExerciseEntry entry;
  final engine.UnitSystem unitSystem;
  final engine.ProgrammingConfig config;
  final engine.Kg initialLoad;
  final int initialReps;

  @override
  State<_SetStepperSheet> createState() => _SetStepperSheetState();
}

class _SetStepperSheetState extends State<_SetStepperSheet> {
  late engine.Kg _load = widget.initialLoad;
  late int _reps = widget.initialReps;

  @override
  Widget build(BuildContext context) {
    final loads = widget.config.availableLoads(
      widget.entry.planExercise,
      widget.unitSystem,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              'Adjust this set',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            _StepperRow(
              label: 'Weight',
              value: SessionPresentation.formatLoad(_load, widget.unitSystem),
              onMinus: () => setState(() => _load = loads.shift(_load, -1)),
              onPlus: () => setState(() => _load = loads.shift(_load, 1)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _StepperRow(
              label: 'Reps',
              value: '$_reps',
              onMinus: () => setState(() => _reps = (_reps - 1).clamp(1, 99)),
              onPlus: () => setState(() => _reps = (_reps + 1).clamp(1, 99)),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const ValueKey('stepper-save'),
              onPressed: () =>
                  Navigator.pop(context, (load: _load, reps: _reps)),
              child: const Text('Use for this set'),
            ),
          ],
        ),
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

class _ExerciseVisual extends StatelessWidget {
  const _ExerciseVisual({required this.entry, this.height = 220});

  final engine.SessionExerciseEntry entry;
  final double height;

  @override
  Widget build(BuildContext context) {
    final asset = SessionPresentation.imageAsset(entry.exerciseId);
    return ClipRRect(
      borderRadius: AppRadii.largeBorder,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: asset == null
            ? DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.blushSoft, AppColors.lavenderSoft],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fitness_center_rounded,
                        color: AppColors.roseDeep,
                        size: 42,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        entry.planExercise.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        SessionPresentation.blockRole(
                          entry.planExercise.blockRole,
                        ),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              )
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
      ),
    );
  }
}

class _SetPills extends StatelessWidget {
  const _SetPills({required this.entry, required this.unitSystem});

  final engine.SessionExerciseEntry entry;
  final engine.UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var index = 0; index < entry.prescription.dose.sets; index++)
          _Pill(
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
          ),
      ],
    );
  }

  String _completedSetLabel(engine.SetCompleted set) => set.load.isZero
      ? '${set.reps} reps'
      : '${set.reps} × ${SessionPresentation.formatLoad(set.load, unitSystem)}';
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
                    'ready for you',
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
    return _InfoCard(
      color: AppColors.lavenderSoft,
      icon: Icons.call_split_rounded,
      title: 'A gentler bridge',
      body: text,
    );
  }
}

class _EffortOptions extends StatelessWidget {
  const _EffortOptions({
    required this.onSelected,
    this.selected,
    this.compact = false,
  });

  final ValueChanged<engine.EffortLevel>? onSelected;
  final engine.EffortLevel? selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: compact ? AppSpacing.xs : AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final level in engine.EffortLevel.values)
          ChoiceChip(
            key: ValueKey('effort-${level.name}'),
            label: Text(SessionPresentation.effortLabel(level)),
            selected: selected == level,
            onSelected: onSelected == null ? null : (_) => onSelected!(level),
          ),
      ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.roseDeep, size: 21),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  body,
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.largeBorder,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: textColor),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mediumBorder,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: AppRadii.mediumBorder,
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.blushSoft,
                  borderRadius: AppRadii.smallBorder,
                ),
                child: Icon(icon, color: AppColors.roseDeep),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapOption extends StatelessWidget {
  const _SwapOption({
    required this.candidate,
    this.recommended = false,
    this.notRecommended = false,
  });

  final engine.PlanSwapCandidate candidate;
  final bool recommended;
  final bool notRecommended;

  @override
  Widget build(BuildContext context) {
    return _SheetOption(
      key: ValueKey('swap-candidate-${candidate.exerciseId}'),
      icon: Icons.swap_horiz_rounded,
      title: candidate.name,
      subtitle: recommended
          ? 'Closest match'
          : notRecommended
          ? 'Not recommended'
          : 'Good match for this slot',
      onTap: () => Navigator.pop(context, candidate),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.blushSoft,
            foregroundColor: AppColors.roseDeep,
            child: Text('$number'),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 90,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
        ],
      ),
    );
  }
}

class _AdherenceDots extends StatelessWidget {
  const _AdherenceDots({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < total; index++)
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < completed
                      ? AppColors.sage
                      : AppColors.blushSoft,
                ),
                child: index < completed
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: AppColors.paper,
                      )
                    : null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$completed of $total this week',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppRadii.mediumBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.line,
          borderRadius: AppRadii.largeBorder,
        ),
      ),
    );
  }
}

class _SessionError extends StatelessWidget {
  const _SessionError({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This session is not ready yet.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(onPressed: onBack, child: const Text('Back to Today')),
          ],
        ),
      ),
    );
  }
}

final class _RestPhase {
  const _RestPhase({
    required this.exerciseId,
    required this.exerciseName,
    required this.completedSet,
    required this.totalSets,
    required this.askForEffort,
    required this.calibration,
    required this.nextExerciseName,
    required this.nextSet,
  });

  final String exerciseId;
  final String exerciseName;
  final int completedSet;
  final int totalSets;
  final bool askForEffort;
  final bool calibration;
  final String? nextExerciseName;
  final int nextSet;
}

sealed class _LifeAction {
  const _LifeAction();
}

final class _Busy extends _LifeAction {
  const _Busy();
}

final class _Shorten extends _LifeAction {
  const _Shorten(this.minutes);

  final int minutes;
}

final class _LowEnergy extends _LifeAction {
  const _LowEnergy();
}

final class _Abandon extends _LifeAction {
  const _Abandon();
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
