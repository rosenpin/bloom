import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/core/theme/app_colors.dart';
import 'package:womens_gym/core/theme/app_theme.dart';
import 'package:womens_gym/features/tabs/presentation/week_strip.dart';

void main() {
  testWidgets('shows done, today, future planned, and rest dots', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpStrip(
        tester,
        today: DateTime(2026, 7, 28),
        completedAt: [DateTime(2026, 7, 27, 18)],
        plannedWeekdays: const {DateTime.tuesday, DateTime.thursday},
      );

      expect(_colorOf(tester, 'week-strip-dot-1'), AppColors.sage);
      expect(_colorOf(tester, 'week-strip-dot-2'), AppColors.rose);
      expect(_colorOf(tester, 'week-strip-dot-3'), AppColors.line);
      expect(_colorOf(tester, 'week-strip-dot-4'), AppColors.blush);
      expect(_colorOf(tester, 'week-strip-day-2'), AppColors.blushSoft);

      expect(find.bySemanticsLabel('Monday, done'), findsOneWidget);
      expect(find.bySemanticsLabel('Tuesday, today, planned'), findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday, rest'), findsOneWidget);
      expect(find.bySemanticsLabel('Thursday, planned'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('uses the green today chip once today is done', (tester) async {
    await _pumpStrip(
      tester,
      today: DateTime(2026, 7, 28),
      completedAt: [DateTime(2026, 7, 27, 18), DateTime(2026, 7, 28, 18)],
      plannedWeekdays: const {DateTime.tuesday, DateTime.thursday},
    );

    expect(_colorOf(tester, 'week-strip-dot-2'), AppColors.sage);
    expect(_colorOf(tester, 'week-strip-day-2'), AppColors.sageSoft);
    expect(_colorOf(tester, 'week-strip-dot-4'), AppColors.blush);
  });
}

Future<void> _pumpStrip(
  WidgetTester tester, {
  required DateTime today,
  required Iterable<DateTime> completedAt,
  required Set<int> plannedWeekdays,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: WeekStrip(
          today: today,
          completedAt: completedAt,
          plannedWeekdays: plannedWeekdays,
        ),
      ),
    ),
  ),
);

Color? _colorOf(WidgetTester tester, String key) {
  final container = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
  return (container.decoration as BoxDecoration?)?.color;
}
