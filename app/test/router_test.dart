import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/app.dart';

void main() {
  testWidgets('three-tab shell builds and switches branches', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WomensGymApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-screen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-screen')), findsOneWidget);
    expect(
      find.text('A plan shaped around your schedule, goals, and real life.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('me-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-screen')), findsOneWidget);
    expect(
      find.text(
        'Your preferences and progress will live here, quietly remembered.',
      ),
      findsOneWidget,
    );
  });
}
