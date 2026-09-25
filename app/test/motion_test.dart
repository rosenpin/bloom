import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/features/onboarding/presentation/onboarding_widgets.dart';

void main() {
  testWidgets('an option card unfolds and folds its extra row smoothly', (
    tester,
  ) async {
    Widget card({required bool open}) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            OptionCard(
              key: const ValueKey('card'),
              title: 'Yoga or pilates',
              selected: open,
              onTap: () {},
              child: open ? const SizedBox(height: 60) : null,
            ),
          ],
        ),
      ),
    );
    double height() =>
        tester.getSize(find.byKey(const ValueKey('card'))).height;

    await tester.pumpWidget(card(open: false));
    final closed = height();
    await tester.pumpWidget(card(open: true));
    await tester.pump(const Duration(milliseconds: 40));
    final opening = height();
    await tester.pumpAndSettle();
    final opened = height();
    await tester.pumpWidget(card(open: false));
    await tester.pump(const Duration(milliseconds: 40));
    final closing = height();
    await tester.pumpAndSettle();

    expect(opening, inExclusiveRange(closed, opened));
    expect(closing, inExclusiveRange(closed, opened));
    expect(height(), closed);
  });

  testWidgets('an edge swipe goes back a step, a mid-screen swipe does not', (
    tester,
  ) async {
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingBackScope(
          onBack: () => backs++,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    await tester.dragFrom(const Offset(4, 300), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(backs, 1);

    await tester.dragFrom(const Offset(160, 300), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(backs, 1);
  });
}
