import 'package:programming_engine/programming_engine.dart' as engine;

abstract final class HistoryPresentation {
  static const _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String weekday(DateTime date, {bool uppercase = false}) {
    final value = _weekdays[date.toLocal().weekday - 1];
    return uppercase ? value.toUpperCase() : value;
  }

  static String monthDay(DateTime date, {bool includeYear = false}) {
    final local = date.toLocal();
    final value = '${_months[local.month - 1]} ${local.day}';
    return includeYear ? '$value, ${local.year}' : value;
  }

  static String shortDate(DateTime date) {
    final local = date.toLocal();
    final month = _months[local.month - 1].substring(0, 3);
    return '$month ${local.day}, ${local.year}';
  }

  static String duration(Duration duration) =>
      '${duration.inMinutes.clamp(0, 999)} min';

  static String feel(engine.EffortLevel effort) => switch (effort) {
    engine.EffortLevel.wayTooEasy => 'felt way too easy',
    engine.EffortLevel.aBitEasy => 'felt a bit easy',
    engine.EffortLevel.justRight => 'felt just right',
    engine.EffortLevel.harderThanIdLike => "felt harder than I'd like",
    engine.EffortLevel.tooHard => 'felt too hard',
  };
}
