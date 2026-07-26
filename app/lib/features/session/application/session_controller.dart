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

  Future<SessionRuntime?> start() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.startOrResume);
    return state.value;
  }

  Future<void> advance(engine.SessionEvent event) async {
    final current = state.value;
    if (current == null) return;
    state = await AsyncValue.guard(() => _service.advance(current, event));
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
    ref.invalidate(sessionPreviewProvider);
  }
}
