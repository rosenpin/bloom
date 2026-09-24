import '../../onboarding/domain/onboarding_answers.dart';

final class MonthEstimate {
  const MonthEstimate({
    required this.day,
    required this.gapDays,
    required this.about,
  });

  final int day;
  final int gapDays;
  final bool about;

  String get title =>
      '${about ? 'About day' : 'Day'} $day since your period started';

  String get observation {
    if (day <= 3) {
      return 'Training on your period is safe. Gentle movement eases cramps for some women.';
    }
    if (day >= gapDays - 4) {
      return 'Some women feel more tired before a period. If today feels heavy, that is normal.';
    }
    return "Everyone's month feels different. Your plan can flex any day.";
  }
}

MonthEstimate estimateMonth({
  required DateTime today,
  required DateTime lastPeriodStart,
  required MenstrualGap? gap,
}) {
  final gapDays = gap?.days ?? 28;
  final todayDate = DateTime.utc(today.year, today.month, today.day);
  final startDate = DateTime.utc(
    lastPeriodStart.year,
    lastPeriodStart.month,
    lastPeriodStart.day,
  );
  final elapsed = todayDate.difference(startDate).inDays;
  return MonthEstimate(
    day: (elapsed < 0 ? 0 : elapsed) % gapDays + 1,
    gapDays: gapDays,
    about:
        gap == null ||
        gap == MenstrualGap.notSure ||
        gap == MenstrualGap.days30Plus,
  );
}
