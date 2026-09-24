import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/features/onboarding/domain/onboarding_answers.dart';
import 'package:womens_gym/features/tabs/domain/month_presentation.dart';

void main() {
  test('estimates day one on the start date and one gap later', () {
    final start = DateTime(2026, 9, 1);
    expect(
      estimateMonth(
        today: start,
        lastPeriodStart: start,
        gap: MenstrualGap.days26,
      ).day,
      1,
    );
    expect(
      estimateMonth(
        today: DateTime(2026, 9, 27),
        lastPeriodStart: start,
        gap: MenstrualGap.days26,
      ).day,
      1,
    );
  });

  test(
    'wraps dates far past the stored start and selects the premenstrual line',
    () {
      final estimate = estimateMonth(
        today: DateTime(2026, 9, 24),
        lastPeriodStart: DateTime(2025, 9, 1),
        gap: MenstrualGap.days28,
      );
      expect(estimate.day, (388 % 28) + 1);
      final premenstrual = estimateMonth(
        today: DateTime(2026, 9, 24),
        lastPeriodStart: DateTime(2026, 9, 1),
        gap: MenstrualGap.days28,
      );
      expect(premenstrual.observation, contains('more tired before a period'));
    },
  );

  test('not sure uses about and a 28 day gap', () {
    final estimate = estimateMonth(
      today: DateTime(2026, 9, 6),
      lastPeriodStart: DateTime(2026, 9, 1),
      gap: MenstrualGap.notSure,
    );
    expect(estimate.gapDays, 28);
    expect(estimate.title, 'About day 6 since your period started');
  });
}
