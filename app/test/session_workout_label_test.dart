import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/features/session/domain/session_presentation.dart';

void main() {
  test('uses the planned weekday only when it matches the workout date', () {
    expect(
      SessionPresentation.workoutLabel(
        dayName: 'Lower Body',
        dayIndex: 1,
        daysPerWeek: 3,
        date: DateTime(2026, 7, 27),
      ),
      'MONDAY · LOWER BODY',
    );
    expect(
      SessionPresentation.workoutLabel(
        dayName: 'Lower Body',
        dayIndex: 1,
        daysPerWeek: 3,
        date: DateTime(2026, 7, 30),
      ),
      'LOWER BODY',
    );
    expect(
      SessionPresentation.plannedWeekdayLabel(
        dayIndex: 1,
        daysPerWeek: 3,
        date: DateTime(2026, 7, 30),
      ),
      isNull,
    );
  });
}
