import 'dart:convert';

import 'review_notes.dart';

abstract interface class KeyValueStore {
  String? read(String key);
  void write(String key, String value);
}

/// Persistence seam for a future Supabase-backed implementation.
abstract interface class NotesStore {
  ReviewNotes load(String planReference);
  void save(String planReference, ReviewNotes notes);
}

// TODO(review-site): Add SupabaseNotesStore when project keys and write policy exist.
final class LocalStorageNotesStore implements NotesStore {
  LocalStorageNotesStore(this._storage);

  static const keyPrefix = 'womens-gym-review-notes-v1:';

  final KeyValueStore _storage;

  @override
  ReviewNotes load(String planReference) {
    final value = _storage.read('$keyPrefix$planReference');
    if (value == null) return ReviewNotes();
    try {
      final decoded = jsonDecode(value);
      return decoded is Map
          ? ReviewNotes.fromJson(Map<String, Object?>.from(decoded))
          : ReviewNotes();
    } on FormatException {
      return ReviewNotes();
    }
  }

  @override
  void save(String planReference, ReviewNotes notes) {
    _storage.write('$keyPrefix$planReference', jsonEncode(notes.toJson()));
  }
}
