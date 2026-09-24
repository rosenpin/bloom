import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/core/theme/app_colors.dart';
import 'package:womens_gym/core/theme/app_theme.dart';
import 'package:womens_gym/features/tabs/presentation/week_strip.dart';

void main() {
  testWidgets(
    'shows planned labels, a completed check, and a rose today ring',
    (tester) async {
      final opened = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: WeekStrip(
              today: DateTime(2026, 7, 28),
              completedAt: [DateTime(2026, 7, 27, 18)],
              plannedDays: const {
                DateTime.monday: WeekStripPlanDay(dayIndex: 1, label: 'Lower'),
                DateTime.thursday: WeekStripPlanDay(
                  dayIndex: 2,
                  label: 'Upper',
                ),
              },
              onOpenDay: opened.add,
            ),
          ),
        ),
      );

      expect(find.text('Lower'), findsOneWidget);
      expect(find.text('Upper'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      final todayRing = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('week-strip-day-2')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (todayRing.decoration as BoxDecoration).border!.top.color,
        AppColors.rose,
      );
      await tester.tap(find.byKey(const ValueKey('week-strip-day-4')));
      expect(opened, [2]);
    },
  );
}
