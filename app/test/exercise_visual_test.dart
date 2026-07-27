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
      find.byKey(const ValueKey('exercise-video-placeholder')),
      findsOneWidget,
    );
    expect(find.text('A future exercise'), findsOneWidget);
  });
}
