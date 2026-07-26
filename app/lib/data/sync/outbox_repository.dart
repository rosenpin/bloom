import 'dart:convert';

import '../../core/ulid.dart';
import '../db/app_database.dart';
import '../db/schema.dart';

abstract interface class OutboxSink {
  Future<void> enqueue({
    required String targetTable,
    required String rowId,
    required Map<String, Object?> payload,
    OutboxOperation operation = OutboxOperation.update,
  });
}

final class OutboxRepository implements OutboxSink {
  OutboxRepository(this._database, this._ulid, this._clock);

  final AppDatabase _database;
  final UlidGenerator _ulid;
  final DateTime Function() _clock;
  DateTime? _lastCreatedAt;

  @override
  Future<void> enqueue({
    required String targetTable,
    required String rowId,
    required Map<String, Object?> payload,
    OutboxOperation operation = OutboxOperation.update,
  }) async {
    var createdAt = _clock().toUtc();
    final previous = _lastCreatedAt;
    if (previous != null && !createdAt.isAfter(previous)) {
      createdAt = previous.add(const Duration(milliseconds: 1));
    }
    _lastCreatedAt = createdAt;
    await _database
        .into(_database.outbox)
        .insert(
          OutboxCompanion.insert(
            id: _ulid.generate(timestamp: createdAt),
            targetTable: targetTable,
            rowId: rowId,
            op: operation,
            payloadJson: jsonEncode(payload),
            createdAt: createdAt,
          ),
        );
  }
}
