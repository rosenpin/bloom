import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart';

import '../models/review_notes.dart';
import '../theme/app_colors.dart';
import 'ui_labels.dart';

String exerciseReviewKey(int dayIndex, String exerciseId) =>
    'day-$dayIndex:$exerciseId';

final class FeedbackTab extends StatelessWidget {
  const FeedbackTab({
    required this.plan,
    required this.notes,
    required this.onChanged,
    required this.onExport,
    required this.onCopy,
    super.key,
  });

  final Plan plan;
  final ReviewNotes notes;
  final ValueChanged<ReviewNotes> onChanged;
  final VoidCallback onExport;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'Review notes',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Chip(
              avatar: Icon(Icons.cloud_done_outlined, size: 17),
              label: Text('Saved locally'),
              backgroundColor: AppColors.sageSoft,
              side: BorderSide(color: AppColors.line),
            ),
            FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export notes'),
            ),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.content_copy_outlined),
              label: const Text('Copy JSON'),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Notes are stored per stamped plan in this browser. Export carries the profile, journey series, and all engine stamps.',
          style: TextStyle(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    key: ValueKey<String>('reviewer-${plan.reference}'),
                    initialValue: notes.reviewerName,
                    decoration: const InputDecoration(
                      labelText: 'Reviewer name',
                    ),
                    onChanged: (value) =>
                        onChanged(notes.copyWith(reviewerName: value)),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<ReviewerRole>(
                    key: ValueKey<String>(
                      'role-${plan.reference}-${notes.reviewerRole.name}',
                    ),
                    initialValue: notes.reviewerRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: <DropdownMenuItem<ReviewerRole>>[
                      for (final role in ReviewerRole.values)
                        DropdownMenuItem<ReviewerRole>(
                          value: role,
                          child: Text(reviewerRoleLabel(role)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(notes.copyWith(reviewerRole: value));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Structured tags',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final tag in FeedbackTag.values)
              FilterChip(
                label: Text(feedbackTagLabel(tag)),
                selected: notes.tags.contains(tag),
                onSelected: (selected) {
                  final tags = <FeedbackTag>{...notes.tags};
                  selected ? tags.add(tag) : tags.remove(tag);
                  onChanged(notes.copyWith(tags: tags));
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final day in plan.days) ...<Widget>[
          _DayFeedbackCard(
            planReference: plan.reference,
            day: day,
            notes: notes,
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              key: ValueKey<String>('overall-${plan.reference}'),
              initialValue: notes.overallNote,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Overall note',
                hintText:
                    'What should the engine keep, and what should change first?',
                alignLabelWithHint: true,
              ),
              onChanged: (value) =>
                  onChanged(notes.copyWith(overallNote: value)),
            ),
          ),
        ),
      ],
    );
  }
}

final class _DayFeedbackCard extends StatelessWidget {
  const _DayFeedbackCard({
    required this.planReference,
    required this.day,
    required this.notes,
    required this.onChanged,
  });

  final String planReference;
  final PlanDay day;
  final ReviewNotes notes;
  final ValueChanged<ReviewNotes> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Day ${day.dayIndex} · ${dayKindLabel(day.kind)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final exercise in day.exercises)
              _ExerciseFeedbackRow(
                planReference: planReference,
                dayIndex: day.dayIndex,
                exercise: exercise,
                notes: notes,
                onChanged: onChanged,
              ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey<String>('day-note-$planReference-${day.dayIndex}'),
              initialValue: notes.dayNotes[day.dayIndex] ?? '',
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Day ${day.dayIndex} note',
                hintText: 'Order, balance, length, missing work…',
                alignLabelWithHint: true,
              ),
              onChanged: (value) {
                final dayNotes = <int, String>{...notes.dayNotes};
                if (value.isEmpty) {
                  dayNotes.remove(day.dayIndex);
                } else {
                  dayNotes[day.dayIndex] = value;
                }
                onChanged(notes.copyWith(dayNotes: dayNotes));
              },
            ),
          ],
        ),
      ),
    );
  }
}

final class _ExerciseFeedbackRow extends StatelessWidget {
  const _ExerciseFeedbackRow({
    required this.planReference,
    required this.dayIndex,
    required this.exercise,
    required this.notes,
    required this.onChanged,
  });

  final String planReference;
  final int dayIndex;
  final PlanExercise exercise;
  final ReviewNotes notes;
  final ValueChanged<ReviewNotes> onChanged;

  @override
  Widget build(BuildContext context) {
    final reviewKey = exerciseReviewKey(dayIndex, exercise.exerciseId);
    final review = notes.exerciseReviews[reviewKey] ?? const ExerciseReview();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.55),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final identity = Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      exercise.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      blockRoleLabel(exercise.blockRole),
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _SentimentButton(
                tooltip: 'Good choice',
                icon: Icons.thumb_up_alt_outlined,
                selected: review.sentiment == ReviewSentiment.thumbsUp,
                selectedColor: AppColors.sage,
                onPressed: () => _setSentiment(
                  review.sentiment == ReviewSentiment.thumbsUp
                      ? null
                      : ReviewSentiment.thumbsUp,
                  reviewKey,
                  review,
                ),
              ),
              const SizedBox(width: 4),
              _SentimentButton(
                tooltip: 'Needs change',
                icon: Icons.thumb_down_alt_outlined,
                selected: review.sentiment == ReviewSentiment.thumbsDown,
                selectedColor: AppColors.roseDeep,
                onPressed: () => _setSentiment(
                  review.sentiment == ReviewSentiment.thumbsDown
                      ? null
                      : ReviewSentiment.thumbsDown,
                  reviewKey,
                  review,
                ),
              ),
            ],
          );
          final note = TextFormField(
            key: ValueKey<String>('exercise-note-$planReference-$reviewKey'),
            initialValue: review.note,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Exercise note',
              hintText: 'Why?',
            ),
            onChanged: (value) =>
                _setReview(reviewKey, review.copyWith(note: value)),
          );
          if (compact) {
            return Column(
              children: <Widget>[identity, const SizedBox(height: 10), note],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: 330, child: identity),
              const SizedBox(width: 12),
              Expanded(child: note),
            ],
          );
        },
      ),
    );
  }

  void _setSentiment(
    ReviewSentiment? sentiment,
    String reviewKey,
    ExerciseReview review,
  ) {
    _setReview(reviewKey, review.copyWith(sentiment: sentiment));
  }

  void _setReview(String reviewKey, ExerciseReview review) {
    final reviews = <String, ExerciseReview>{...notes.exerciseReviews};
    review.isEmpty ? reviews.remove(reviewKey) : reviews[reviewKey] = review;
    onChanged(notes.copyWith(exerciseReviews: reviews));
  }
}

final class _SentimentButton extends StatelessWidget {
  const _SentimentButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? selectedColor.withValues(alpha: 0.16)
            : AppColors.paper,
        foregroundColor: selected ? selectedColor : AppColors.inkSoft,
        side: BorderSide(color: selected ? selectedColor : AppColors.line),
      ),
      icon: Icon(icon),
    );
  }
}
