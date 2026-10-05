import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/core/navigation/app_tab_bar.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required int selected,
    bool reduced = false,
    ValueChanged<int>? onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(402, 874),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            bottomNavigationBar: AppTabBar(
              selectedIndex: selected,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  double lensX(WidgetTester tester) =>
      (tester.widget<Align>(find.byKey(const ValueKey('tab-lens'))).alignment
              as Alignment)
          .x;

  testWidgets('the lens springs past the tab, then settles on it', (
    tester,
  ) async {
    await pumpBar(tester, selected: 0);
    expect(lensX(tester), -1);

    await pumpBar(tester, selected: 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(lensX(tester), inInclusiveRange(-0.99, -0.01));

    var furthest = -1.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (lensX(tester) > furthest) furthest = lensX(tester);
    }
    expect(furthest, greaterThan(0.01));
    await tester.pumpAndSettle();
    expect(lensX(tester), closeTo(0, 0.001));
  });

  testWidgets('with reduced motion the lens snaps', (tester) async {
    await pumpBar(tester, selected: 0, reduced: true);
    await pumpBar(tester, selected: 2, reduced: true);
    expect(lensX(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('each tab reads as a tab and answers a tap', (tester) async {
    final taps = <int>[];
    await pumpBar(tester, selected: 0, onSelected: taps.add);

    expect(find.bySemanticsLabel('Today, tab, 1 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Plan, tab, 2 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Me, tab, 3 of 3'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('me-tab'))).shortestSide,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(const ValueKey('me-tab')));
    await tester.tap(find.byKey(const ValueKey('today-tab')));
    expect(taps, [2, 0]);
  });
}
