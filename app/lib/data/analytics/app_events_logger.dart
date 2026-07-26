import 'dart:async';
import 'dart:math';

import 'package:programming_engine/programming_engine.dart' as engine;

import '../sync/outbox_repository.dart';

typedef AppEventIdGenerator = String Function();

final class AppEventsLogger {
  const AppEventsLogger(this._outbox, this._clock, this._newId);

  static const allowedPropsByEvent = <String, Set<String>>{
    'onboarding_step_completed': {'step'},
    'plan_generated': {'days', 'minutes', 'goal', 'emphasis'},
    'session_started': {},
    'set_logged': {},
    'effort_reported': {'level'},
    'swap_used': {'reason', 'tier'},
    'session_completed': {'duration_min', 'exercises'},
    'session_abandoned': {},
    'comeback_shown': {'tier'},
  };

  final OutboxSink _outbox;
  final DateTime Function() _clock;
  final AppEventIdGenerator _newId;

  void onboardingStepCompleted(int step) =>
      _log('onboarding_step_completed', {'step': step});

  void planGenerated({
    required int days,
    required int minutes,
    required engine.Goal goal,
    required engine.Emphasis emphasis,
  }) => _log('plan_generated', {
    'days': days,
    'minutes': minutes,
    'goal': goal.name,
    'emphasis': emphasis.name,
  });

  void sessionStarted() => _log('session_started');

  void setLogged() => _log('set_logged');

  void effortReported(engine.EffortLevel level) =>
      _log('effort_reported', {'level': level.name});

  void swapUsed({required engine.SwapReason reason, required int tier}) =>
      _log('swap_used', {'reason': reason.name, 'tier': tier});

  void sessionCompleted({
    required int durationMinutes,
    required int exercises,
  }) => _log('session_completed', {
    'duration_min': durationMinutes,
    'exercises': exercises,
  });

  void sessionAbandoned() => _log('session_abandoned');

  void comebackShown(int tier) => _log('comeback_shown', {'tier': tier});

  void _log(String name, [Map<String, Object?> props = const {}]) {
    _validate(name, props);
    final id = _newId();
    unawaited(
      _outbox.enqueue(
        targetTable: 'app_events',
        rowId: id,
        payload: {
          'id': id,
          'name': name,
          'props': props,
          'client_ts': _clock().toUtc().toIso8601String(),
        },
      ),
    );
  }

  static void _validate(String name, Map<String, Object?> props) {
    final allowed = allowedPropsByEvent[name];
    if (allowed == null) {
      throw ArgumentError.value(name, 'name', 'Unknown app event');
    }
    final forbidden = props.keys.where((key) => !allowed.contains(key));
    if (forbidden.isNotEmpty) {
      throw ArgumentError(
        'Forbidden properties for $name: ${forbidden.join(', ')}',
      );
    }
  }
}

String randomUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
