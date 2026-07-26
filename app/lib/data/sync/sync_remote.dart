import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SyncRemote {
  Future<String?> currentUserId();

  Future<void> upsert(
    String table,
    Map<String, Object?> row, {
    required String onConflict,
    bool ignoreDuplicates,
  });

  Future<List<Map<String, Object?>>> pullUpdated(
    String table, {
    DateTime? after,
  });

  Future<List<Map<String, Object?>>> pullOwned(
    String table, {
    required String userId,
  });
}

final class SupabaseSyncRemote implements SyncRemote {
  const SupabaseSyncRemote(
    this._client, {
    this.timeout = const Duration(seconds: 8),
  });

  final SupabaseClient Function() _client;
  final Duration timeout;

  @override
  Future<String?> currentUserId() async {
    try {
      return _client().auth.currentUser?.id;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> upsert(
    String table,
    Map<String, Object?> row, {
    required String onConflict,
    bool ignoreDuplicates = false,
  }) async {
    await _client()
        .from(table)
        .upsert(row, onConflict: onConflict, ignoreDuplicates: ignoreDuplicates)
        .timeout(timeout);
  }

  @override
  Future<List<Map<String, Object?>>> pullUpdated(
    String table, {
    DateTime? after,
  }) async {
    final List<dynamic> rows;
    if (after == null) {
      rows = await _client()
          .from(table)
          .select()
          .order('updated_at')
          .timeout(timeout);
    } else {
      rows = await _client()
          .from(table)
          .select()
          .gt('updated_at', after.toUtc().toIso8601String())
          .order('updated_at')
          .timeout(timeout);
    }
    return _maps(rows);
  }

  @override
  Future<List<Map<String, Object?>>> pullOwned(
    String table, {
    required String userId,
  }) async {
    final ownerColumn = table == 'profiles' ? 'id' : 'user_id';
    final rows = await _client()
        .from(table)
        .select()
        .eq(ownerColumn, userId)
        .timeout(timeout);
    return _maps(rows);
  }

  static List<Map<String, Object?>> _maps(List<dynamic> rows) => [
    for (final row in rows)
      (row as Map<Object?, Object?>).cast<String, Object?>(),
  ];
}
