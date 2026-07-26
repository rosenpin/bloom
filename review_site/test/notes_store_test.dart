import 'package:flutter_test/flutter_test.dart';
import 'package:review_site/models/notes_store.dart';
import 'package:review_site/models/review_notes.dart';

void main() {
  test('LocalStorageNotesStore persists structured review notes', () {
    final memory = _MemoryStore();
    final store = LocalStorageNotesStore(memory);
    final notes = ReviewNotes(
      reviewerName: 'Tomer',
      reviewerRole: ReviewerRole.owner,
      exerciseReviews: const <String, ExerciseReview>{
        'day-1:machine-leg-press': ExerciseReview(
          sentiment: ReviewSentiment.thumbsDown,
          note: 'Move this after the hinge.',
        ),
      },
      dayNotes: const <int, String>{1: 'Too much quad volume.'},
      tags: const <FeedbackTag>{FeedbackTag.wrongOrder, FeedbackTag.tooMuch},
      overallNote: 'Keep the split.',
    );

    store.save('stamped-plan', notes);

    expect(store.load('stamped-plan'), notes);
    expect(store.load('other-plan'), ReviewNotes());
  });
}

final class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;
}
