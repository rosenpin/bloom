import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/core/theme/app_motion.dart';
import 'package:womens_gym/core/theme/app_sizes.dart';
import 'package:womens_gym/features/session/presentation/exercise_visual.dart';

void main() {
  testWidgets('exercise stills keep the portrait frame and whole image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: ExerciseVisual(
                  exerciseId: 'barbell-hip-thrust',
                  exerciseName: 'Barbell Hip Thrust',
                  blockRoleLabel: 'Glute focus',
                  aspectRatio: AppSizes.exerciseVisualAspect,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(const ValueKey('exercise-visual')));
    expect(
      rect.width / rect.height,
      closeTo(AppSizes.exerciseVisualAspect, 0.01),
    );
    expect(
      tester.widget<Image>(find.byKey(const ValueKey('exercise-still-1'))).fit,
      BoxFit.contain,
    );
    expect(
      tester.widget<Image>(find.byKey(const ValueKey('exercise-still-2'))).fit,
      BoxFit.contain,
    );
  });

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
    await tester.pump(AppMotion.stillsHold);
    expect(_secondOpacity(tester), 0);
    await tester.pump(AppMotion.stillsCrossfade ~/ 2);
    expect(_secondOpacity(tester), closeTo(0.5, 0.1));
    await tester.pump(AppMotion.stillsCrossfade ~/ 2);
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
    await tester.pump(AppMotion.stillsHold + AppMotion.stillsCrossfade ~/ 2);
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

  testWidgets('the diptych shows both positions side by side at 16:9', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 342,
                child: ExerciseDiptych(
                  exerciseId: 'plank',
                  exerciseName: 'Plank',
                  blockRoleLabel: 'Core',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final card = tester.getRect(find.byKey(const ValueKey('exercise-diptych')));
    expect(card.width / card.height, closeTo(16 / 9, 0.01));
    final first = tester.getRect(
      find.byKey(const ValueKey('exercise-diptych-1')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('exercise-diptych-2')),
    );
    expect(first.height, card.height);
    expect(second.left - first.right, 2);
    expect(find.byType(ExerciseStillsPlayer), findsNothing);
  });

  testWidgets('thumbnails hold still, large visuals keep their loop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Column(
                children: [
                  SizedBox.square(
                    dimension: AppSizes.thumbnailMd,
                    child: ExerciseVisual(
                      exerciseId: 'barbell-hip-thrust',
                      exerciseName: 'Barbell Hip Thrust',
                      blockRoleLabel: 'Glute focus',
                      compact: true,
                    ),
                  ),
                  SizedBox(
                    height: 200,
                    child: ExerciseVisual(
                      exerciseId: 'dumbbell-goblet-squat',
                      exerciseName: 'Goblet Squat',
                      blockRoleLabel: 'Squat',
                      aspectRatio: AppSizes.exerciseVisualAspect,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ExerciseStillsPlayer), findsNothing);
    expect(find.byKey(const ValueKey('exercise-still-flip')), findsNothing);
    expect(find.byType(ExerciseVideoPlayer), findsOneWidget);
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
