import 'dart:convert';

import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../data/db/app_database.dart';
import '../../../data/db/schema.dart';

typedef EncodedSessionEvent = ({
  StoredSessionEventType type,
  String payloadJson,
});

/// The app-owned boundary between Drift rows and the engine event vocabulary.
///
/// Keep this mapping exhaustive. The stored log is the source of truth for
/// session replay and progression.
abstract final class SessionEventCodec {
  static EncodedSessionEvent encode(engine.SessionEvent event) =>
      switch (event) {
        engine.SetCompleted(
          :final exerciseId,
          :final setIndex,
          :final load,
          :final reps,
          :final targetReps,
          :final targetRpe,
          :final prescribedLoad,
        ) =>
          (
            type: StoredSessionEventType.setCompleted,
            payloadJson: jsonEncode(<String, Object?>{
              'exerciseId': exerciseId,
              'setIndex': setIndex,
              'loadKg': load.value,
              'reps': reps,
              'targetReps': targetReps,
              'targetRpe': targetRpe,
              'prescribedLoadKg': prescribedLoad?.value,
            }),
          ),
        engine.EffortReported(:final exerciseId, :final level) => (
          type: StoredSessionEventType.effortReported,
          payloadJson: jsonEncode(<String, Object?>{
            'exerciseId': exerciseId,
            'level': level.value,
          }),
        ),
        engine.SwapRequested(:final exerciseId, :final reason) => (
          type: StoredSessionEventType.swapRequested,
          payloadJson: jsonEncode(<String, Object?>{
            'exerciseId': exerciseId,
            'reason': reason.name,
          }),
        ),
        engine.Shorten(:final minutes) => (
          type: StoredSessionEventType.shorten,
          payloadJson: jsonEncode(<String, Object?>{'minutes': minutes}),
        ),
        engine.LowEnergy() => (
          type: StoredSessionEventType.lowEnergy,
          payloadJson: '{}',
        ),
        engine.PainReported(:final exerciseId, :final site) => (
          type: StoredSessionEventType.painReported,
          payloadJson: jsonEncode(<String, Object?>{
            'exerciseId': exerciseId,
            'site': site.name,
          }),
        ),
        engine.SessionAbandoned() => (
          type: StoredSessionEventType.sessionAbandoned,
          payloadJson: '{}',
        ),
      };

  static engine.SessionEvent decode(SessionEventRow row) => decodePayload(
    type: row.type,
    payloadJson: row.payloadJson,
    unitSystemAtEntry: row.unitSystemAtEntry,
  );

  static engine.SessionEvent decodePayload({
    required StoredSessionEventType type,
    required String payloadJson,
    required engine.UnitSystem unitSystemAtEntry,
  }) {
    final payload = jsonDecode(payloadJson) as Map<String, Object?>;
    return switch (type) {
      StoredSessionEventType.setCompleted => engine.SetCompleted(
        exerciseId: _string(payload, 'exerciseId'),
        setIndex: _integer(payload, 'setIndex'),
        load: engine.Kg(_number(payload, 'loadKg')),
        reps: _integer(payload, 'reps'),
        unitSystem: unitSystemAtEntry,
        targetReps: _optionalInteger(payload['targetReps']),
        targetRpe: _optionalInteger(payload['targetRpe']),
        prescribedLoad: _optionalKg(payload['prescribedLoadKg']),
      ),
      StoredSessionEventType.effortReported => engine.EffortReported(
        exerciseId: _string(payload, 'exerciseId'),
        level: engine.EffortLevel.clampFromValue(_integer(payload, 'level')),
      ),
      StoredSessionEventType.swapRequested => engine.SwapRequested(
        exerciseId: _string(payload, 'exerciseId'),
        reason: _enum(engine.SwapReason.values, _string(payload, 'reason')),
      ),
      StoredSessionEventType.shorten => engine.Shorten(
        _integer(payload, 'minutes'),
      ),
      StoredSessionEventType.lowEnergy => const engine.LowEnergy(),
      StoredSessionEventType.painReported => engine.PainReported(
        exerciseId: _string(payload, 'exerciseId'),
        site: _enum(engine.PainSite.values, _string(payload, 'site')),
      ),
      StoredSessionEventType.sessionAbandoned =>
        const engine.SessionAbandoned(),
    };
  }

  static String _string(Map<String, Object?> payload, String key) =>
      payload[key]! as String;

  static int _integer(Map<String, Object?> payload, String key) =>
      (payload[key]! as num).toInt();

  static double _number(Map<String, Object?> payload, String key) =>
      (payload[key]! as num).toDouble();

  static int? _optionalInteger(Object? value) =>
      value == null ? null : (value as num).toInt();

  static double? _optionalNumber(Object? value) =>
      value == null ? null : (value as num).toDouble();

  static engine.Kg? _optionalKg(Object? value) {
    final number = _optionalNumber(value);
    return number == null ? null : engine.Kg(number);
  }

  static T _enum<T extends Enum>(List<T> values, String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown ${T.toString()} value: $name');
  }
}
