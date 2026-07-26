import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/features/session/application/rest_timer_foundation.dart';

void main() {
  test('rest timer replaces its notification and can cancel early', () async {
    final scheduler = _FakeScheduler();
    final foundation = RestTimerFoundation(scheduler);
    final end = DateTime.utc(2026, 7, 26, 10, 1, 15);

    await foundation.schedule(
      notificationId: 42,
      endsAt: end,
      nextSet: 3,
      exerciseName: 'Goblet Squat',
    );

    expect(scheduler.cancelled, [42]);
    expect(scheduler.scheduled, hasLength(1));
    expect(scheduler.scheduled.single.id, 42);
    expect(scheduler.scheduled.single.at, end);
    expect(scheduler.scheduled.single.title, "Rest's done.");
    expect(scheduler.scheduled.single.body, 'Set 3 of Goblet Squat.');

    await foundation.cancel(42);
    expect(scheduler.cancelled, [42, 42]);
  });
}

final class _FakeScheduler implements RestNotificationScheduler {
  final List<int> cancelled = [];
  final List<({int id, DateTime at, String title, String body})> scheduled = [];

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    scheduled.add((id: id, at: at, title: title, body: body));
  }
}
