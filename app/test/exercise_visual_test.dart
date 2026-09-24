import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/features/session/presentation/exercise_visual.dart';

void main() {
  testWidgets('an unmapped exercise renders the gradient placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExerciseVisual(
              exerciseId: 'unmapped-exercise',
              exerciseName: 'A future exercise',
              blockRoleLabel: 'Glute focus',
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('exercise-visual-placeholder')),
      findsOneWidget,
    );
    expect(find.text('A future exercise'), findsOneWidget);
  });

  testWidgets('stills hold and crossfade between both positions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExerciseVisual(
              exerciseId: 'barbell-hip-thrust',
              exerciseName: 'Barbell Hip Thrust',
              blockRoleLabel: 'Glute focus',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('exercise-still-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('exercise-still-2')), findsOneWidget);
    expect(_secondOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_secondOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_secondOpacity(tester), closeTo(0.5, 0.1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_secondOpacity(tester), 1);
  });

  testWidgets('reduced motion shows the first still until tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ExerciseVisual(
                exerciseId: 'barbell-hip-thrust',
                exerciseName: 'Barbell Hip Thrust',
                blockRoleLabel: 'Glute focus',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('exercise-still-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('exercise-still-flip')));
    await tester.pump();
    expect(find.byKey(const ValueKey('exercise-still-2')), findsOneWidget);
  });

  testWidgets('stills pause while another route is current', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(
            body: ExerciseVisual(
              exerciseId: 'barbell-hip-thrust',
              exerciseName: 'Barbell Hip Thrust',
              blockRoleLabel: 'Glute focus',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1350));
    final before = _secondOpacity(tester);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Next')),
      ),
    );
    await tester.pumpAndSettle();
    final paused = _secondOpacity(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(_secondOpacity(tester), paused);
    expect(before, greaterThan(0));
  });
}

double _secondOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey('exercise-still-2'),
              skipOffstage: false,
            ),
            matching: find.byType(Opacity, skipOffstage: false),
          )
          .first,
    )
    .opacity;
