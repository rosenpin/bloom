import 'dart:convert';

import 'package:programming_engine/programming_engine.dart';

import 'journey_simulator.dart';
import 'review_form_state.dart';

const _notesUnset = Object();

enum ReviewSentiment { thumbsUp, thumbsDown }

enum ReviewerRole { trainer, trainee, owner }

enum FeedbackTag {
  wrongExercise,
  wrongOrder,
  tooMuch,
  tooLittle,
  wrongProgression,
}

final class ExerciseReview {
  const ExerciseReview({this.sentiment, this.note = ''});

  final ReviewSentiment? sentiment;
  final String note;

  bool get isEmpty => sentiment == null && note.trim().isEmpty;

  ExerciseReview copyWith({Object? sentiment = _notesUnset, String? note}) =>
      ExerciseReview(
        sentiment: identical(sentiment, _notesUnset)
            ? this.sentiment
            : sentiment as ReviewSentiment?,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'sentiment': sentiment?.name,
    'note': note,
  };

  static ExerciseReview fromJson(Map<String, Object?> json) => ExerciseReview(
    sentiment: ReviewSentiment.values
        .where((value) => value.name == json['sentiment'])
        .firstOrNull,
    note: json['note'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is ExerciseReview &&
      other.sentiment == sentiment &&
      other.note == note;

  @override
  int get hashCode => Object.hash(sentiment, note);
}

final class ReviewNotes {
  ReviewNotes({
    this.reviewerName = '',
    this.reviewerRole = ReviewerRole.trainer,
    Map<String, ExerciseReview> exerciseReviews =
        const <String, ExerciseReview>{},
    Map<int, String> dayNotes = const <int, String>{},
    Set<FeedbackTag> tags = const <FeedbackTag>{},
    this.overallNote = '',
  }) : exerciseReviews = Map<String, ExerciseReview>.unmodifiable(
         exerciseReviews,
       ),
       dayNotes = Map<int, String>.unmodifiable(dayNotes),
       tags = Set<FeedbackTag>.unmodifiable(tags);

  final String reviewerName;
  final ReviewerRole reviewerRole;
  final Map<String, ExerciseReview> exerciseReviews;
  final Map<int, String> dayNotes;
  final Set<FeedbackTag> tags;
  final String overallNote;

  ReviewNotes copyWith({
    String? reviewerName,
    ReviewerRole? reviewerRole,
    Map<String, ExerciseReview>? exerciseReviews,
    Map<int, String>? dayNotes,
    Set<FeedbackTag>? tags,
    String? overallNote,
  }) => ReviewNotes(
    reviewerName: reviewerName ?? this.reviewerName,
    reviewerRole: reviewerRole ?? this.reviewerRole,
    exerciseReviews: exerciseReviews ?? this.exerciseReviews,
    dayNotes: dayNotes ?? this.dayNotes,
    tags: tags ?? this.tags,
    overallNote: overallNote ?? this.overallNote,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'reviewer': <String, Object>{
      'name': reviewerName,
      'role': reviewerRole.name,
    },
    'tags': tags.map((tag) => tag.name).toList(growable: false),
    'exerciseReviews': <String, Object?>{
      for (final entry in exerciseReviews.entries)
        if (!entry.value.isEmpty) entry.key: entry.value.toJson(),
    },
    'dayNotes': <String, String>{
      for (final entry in dayNotes.entries)
        if (entry.value.trim().isNotEmpty) entry.key.toString(): entry.value,
    },
    'overallNote': overallNote,
  };

  static ReviewNotes fromJson(Map<String, Object?> json) {
    final reviewer = json['reviewer'];
    final reviewerMap = reviewer is Map
        ? Map<String, Object?>.from(reviewer)
        : const <String, Object?>{};
    final rawExerciseReviews = json['exerciseReviews'];
    final exerciseReviews = <String, ExerciseReview>{};
    if (rawExerciseReviews is Map) {
      for (final entry in rawExerciseReviews.entries) {
        if (entry.key is String && entry.value is Map) {
          exerciseReviews[entry.key as String] = ExerciseReview.fromJson(
            Map<String, Object?>.from(entry.value as Map),
          );
        }
      }
    }
    final rawDayNotes = json['dayNotes'];
    final dayNotes = <int, String>{};
    if (rawDayNotes is Map) {
      for (final entry in rawDayNotes.entries) {
        final day = int.tryParse(entry.key.toString());
        if (day != null && entry.value is String) {
          dayNotes[day] = entry.value as String;
        }
      }
    }
    final rawTags = json['tags'];
    final tags = <FeedbackTag>{};
    if (rawTags is List) {
      for (final name in rawTags.whereType<String>()) {
        final tag = FeedbackTag.values
            .where((value) => value.name == name)
            .firstOrNull;
        if (tag != null) tags.add(tag);
      }
    }
    return ReviewNotes(
      reviewerName: reviewerMap['name'] as String? ?? '',
      reviewerRole:
          ReviewerRole.values
              .where((value) => value.name == reviewerMap['role'])
              .firstOrNull ??
          ReviewerRole.trainer,
      exerciseReviews: exerciseReviews,
      dayNotes: dayNotes,
      tags: tags,
      overallNote: json['overallNote'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewNotes &&
      other.reviewerName == reviewerName &&
      other.reviewerRole == reviewerRole &&
      _mapsEqual(other.exerciseReviews, exerciseReviews) &&
      _mapsEqual(other.dayNotes, dayNotes) &&
      _setsEqual(other.tags, tags) &&
      other.overallNote == overallNote;

  @override
  int get hashCode => Object.hash(
    reviewerName,
    reviewerRole,
    Object.hashAllUnordered(
      exerciseReviews.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      dayNotes.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAllUnordered(tags),
    overallNote,
  );
}

String createNotesExportJson({
  required ReviewFormState form,
  required Plan plan,
  required ReviewNotes notes,
  required JourneyResult journey,
  required int journeyWeeks,
  required String journeyPattern,
  required String generatedAt,
}) {
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'generatedAt': generatedAt,
    'planReference': plan.reference,
    'profile': form.toJson(),
    'journeySimulation': <String, Object>{
      'weeks': journeyWeeks,
      'effortPattern': journeyPattern,
      'series': _journeySeriesJson(journey, form.unitSystem),
    },
    'stamps': <String, String>{
      'engineVersion': plan.stamps.engineVersion,
      'configHash': plan.stamps.configHash,
      'contentHash': plan.stamps.contentHash,
      'profileHash': plan.stamps.profileHash,
    },
    'notes': notes.toJson(),
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

List<Map<String, Object>> _journeySeriesJson(
  JourneyResult journey,
  UnitSystem unitSystem,
) {
  final series = journey.series.values.toList(growable: false)
    ..sort(
      (left, right) =>
          left.first.exerciseName.compareTo(right.first.exerciseName),
    );
  final loadUnit = unitSystem.isMetric ? 'kg' : 'lb';
  return <Map<String, Object>>[
    for (final points in series)
      <String, Object>{
        'exerciseId': points.first.exerciseId,
        'exerciseName': points.first.exerciseName,
        'hasExternalLoad': points.first.hasExternalLoad,
        'loadUnit': loadUnit,
        'targetKind': points.first.targetKind.name,
        'sessions': <int>[for (final point in points) point.session],
        'absoluteWeeks': <int>[for (final point in points) point.absoluteWeek],
        'weekKinds': <String>[for (final point in points) point.weekKind.name],
        'sets': <int>[for (final point in points) point.sets],
        'externalLoad': <num>[
          for (final point in points)
            _journeyNumber(
              unitSystem.isMetric ? point.load.value : point.load.inLb,
            ),
        ],
        'target': <int>[for (final point in points) point.target],
        'volume': <num>[
          for (final point in points) _journeyNumber(point.volume(unitSystem)),
        ],
      },
  ];
}

num _journeyNumber(double value) {
  final whole = value.round();
  if ((value - whole).abs() < 0.000001) return whole;
  return double.parse(value.toStringAsFixed(3));
}

bool _mapsEqual<K, V>(Map<K, V> left, Map<K, V> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

bool _setsEqual<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
