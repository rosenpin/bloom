import 'dart:convert';

import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../data/db/app_database.dart';
import '../../../data/db/schema.dart';

typedef EncodedSessionEvent = ({
  StoredSessionEventType type,
  String payloadJson,
});

/// The one failure shape for malformed stored session events.
final class SessionEventDecodeError implements Exception {
  const SessionEventDecodeError({
    required this.type,
    required this.message,
    required this.cause,
  });

  final StoredSessionEventType type;
  final String message;
  final Object cause;

  @override
  String toString() => 'SessionEventDecodeError(${type.name}): $message';
}

/// The app-owned boundary between Drift rows and the engine event vocabulary.
///
/// Keep this mapping exhaustive. The stored log is the source of truth for
/// session replay and progression. Decode validates external values exactly
/// once; engine events are trusted after this point.
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
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('payload must be a JSON object');
      }
      return switch (type) {
        StoredSessionEventType.setCompleted => engine.SetCompleted(
          exerciseId: _string(decoded, 'exerciseId'),
          setIndex: _integer(decoded, 'setIndex', minimum: 0),
          load: engine.Kg(_number(decoded, 'loadKg')),
          reps: _integer(decoded, 'reps', minimum: 1),
          unitSystem: unitSystemAtEntry,
          targetReps: _optionalInteger(decoded, 'targetReps', minimum: 1),
          targetRpe: _optionalInteger(
            decoded,
            'targetRpe',
            minimum: 1,
            maximum: 10,
          ),
          prescribedLoad: _optionalKg(decoded, 'prescribedLoadKg'),
        ),
        StoredSessionEventType.effortReported => engine.EffortReported(
          exerciseId: _string(decoded, 'exerciseId'),
          level:
              engine.EffortLevel.fromValue(_integer(decoded, 'level')) ??
              (throw FormatException(
                'unknown EffortLevel value: ${decoded['level']}',
              )),
        ),
        StoredSessionEventType.swapRequested => engine.SwapRequested(
          exerciseId: _string(decoded, 'exerciseId'),
          reason: _enum(engine.SwapReason.values, _string(decoded, 'reason')),
        ),
        StoredSessionEventType.shorten => engine.Shorten(
          _integer(decoded, 'minutes', minimum: 1),
        ),
        StoredSessionEventType.lowEnergy => const engine.LowEnergy(),
        StoredSessionEventType.painReported => engine.PainReported(
          exerciseId: _string(decoded, 'exerciseId'),
          site: _enum(engine.PainSite.values, _string(decoded, 'site')),
        ),
        StoredSessionEventType.sessionAbandoned =>
          const engine.SessionAbandoned(),
      };
    } on SessionEventDecodeError {
      rethrow;
    } catch (error) {
      throw SessionEventDecodeError(
        type: type,
        message: 'invalid stored event payload',
        cause: error,
      );
    }
  }

  static String _string(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key must be a non-empty string');
    }
    return value;
  }

  static int _integer(
    Map<String, Object?> payload,
    String key, {
    int? minimum,
    int? maximum,
  }) {
    final value = payload[key];
    if (value is! num || !value.isFinite || value != value.truncateToDouble()) {
      throw FormatException('$key must be a finite integer');
    }
    final integer = value.toInt();
    if (minimum != null && integer < minimum) {
      throw FormatException('$key must be at least $minimum');
    }
    if (maximum != null && integer > maximum) {
      throw FormatException('$key must be at most $maximum');
    }
    return integer;
  }

  static double _number(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('$key must be finite');
    }
    return value.toDouble();
  }

  static int? _optionalInteger(
    Map<String, Object?> payload,
    String key, {
    int? minimum,
    int? maximum,
  }) {
    if (payload[key] == null) return null;
    return _integer(payload, key, minimum: minimum, maximum: maximum);
  }

  static engine.Kg? _optionalKg(Map<String, Object?> payload, String key) {
    if (payload[key] == null) return null;
    return engine.Kg(_number(payload, key));
  }

  static T _enum<T extends Enum>(List<T> values, String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown ${T.toString()} value: $name');
  }
}
