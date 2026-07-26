import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

final class AnonymousAuthService {
  const AnonymousAuthService(
    this._client, {
    this.timeout = const Duration(seconds: 5),
  });

  final SupabaseClient Function() _client;
  final Duration timeout;

  Future<Session?> ensureSession() async {
    try {
      final auth = _client().auth;
      final persisted = auth.currentSession;
      if (persisted != null) return persisted;
      final response = await auth.signInAnonymously().timeout(timeout);
      return response.session;
    } on Object {
      return null;
    }
  }

  Stream<Session?> states() async* {
    try {
      final auth = _client().auth;
      yield auth.currentSession;
      yield* auth.onAuthStateChange.map((change) => change.session);
    } on Object {
      yield null;
    }
  }
}
