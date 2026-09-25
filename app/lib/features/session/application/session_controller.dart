import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../core/providers.dart';
import 'session_lifecycle_service.dart';

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionRuntime?>(
      SessionController.new,
    );

final class SessionController extends AsyncNotifier<SessionRuntime?> {
  SessionLifecycleService get _service =>
      ref.read(sessionLifecycleServiceProvider);

  @override
  Future<SessionRuntime?> build() async => null;

  bool _starting = false;

  /// Returns null for a start requested while one is already underway, so a
  /// double tap on "Start workout" opens the player once.
  Future<SessionRuntime?> start() async {
    if (_starting) return null;
    _starting = true;
    try {
      state = const AsyncLoading();
      state = await AsyncValue.guard(_service.startOrResume);
      if (state.value != null) _invalidateSessionViews();
      return state.value;
    } finally {
      _starting = false;
    }
  }

  Future<void> advance(engine.SessionEvent event) async {
    final current = state.value;
    if (current == null) return;
    state = await AsyncValue.guard(() => _service.advance(current, event));
    final next = state.value;
    if ((!current.isComplete && (next?.isComplete ?? false)) ||
        event is engine.SessionAbandoned) {
      _invalidateSessionViews();
    }
  }

  Future<void> swapToCandidate(
    engine.PlanSwapCandidate candidate, {
    required engine.SwapReason reason,
  }) async {
    final current = state.value;
    if (current == null) return;
    state = await AsyncValue.guard(
      () => _service.swapToCandidate(current, candidate, reason: reason),
    );
  }

  Future<void> keepSwap(engine.PendingPlanEditSuggestion suggestion) async {
    final current = state.value;
    if (current == null) return;
    state = await AsyncValue.guard(
      () => _service.keepSwap(current, suggestion),
    );
    ref.invalidate(latestPlanProvider);
    _invalidateSessionViews();
  }

  Future<void> changeUnitSystem(engine.UnitSystem unitSystem) async {
    final current = state.value;
    if (current == null) return;
    state = await AsyncValue.guard(
      () => _service.changeUnitSystem(current, unitSystem),
    );
  }

  Future<void> dismissUnitPrompt() async {
    final current = state.value;
    if (current == null) return;
    state = await AsyncValue.guard(
      () => _service.markUnitPromptSeenForRuntime(current),
    );
  }

  void overrideLoad(String exerciseId, engine.Kg load) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(_service.overrideLoad(current, exerciseId, load));
  }

  Future<void> correctCompletedSet({
    required String exerciseId,
    required int setIndex,
    required engine.Kg load,
    required int reps,
  }) async {
    final current = state.value;
    if (current == null) return;
    state = await AsyncValue.guard(
      () => _service.correctCompletedSet(
        current,
        exerciseId: exerciseId,
        setIndex: setIndex,
        load: load,
        reps: reps,
      ),
    );
  }

  void useUsualWeights() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(_service.useUsualWeights(current));
  }

  Future<SessionRecap?> recap() async {
    final current = state.value;
    return current == null ? null : _service.recap(current);
  }

  void clear() {
    state = const AsyncData(null);
    _invalidateSessionViews();
  }

  void _invalidateSessionViews() {
    ref.invalidate(sessionPreviewProvider);
    ref.invalidate(completedSessionsProvider);
    ref.invalidate(completedSessionProvider);
  }
}
