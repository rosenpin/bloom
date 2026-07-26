import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart';
import 'package:review_site/models/journey_simulator.dart';
import 'package:review_site/models/review_form_state.dart';
import 'package:review_site/widgets/journey_tab.dart';

void main() {
  test(
    'journey summary reports peak load instead of treating final as peak',
    () {
      const points = <JourneyPoint>[
        JourneyPoint(
          session: 1,
          absoluteWeek: 1,
          weekKind: MesocycleWeekKind.build,
          exerciseId: 'test-exercise',
          exerciseName: 'Test exercise',
          load: Kg(5),
          hasExternalLoad: true,
          target: 10,
          targetKind: JourneyTargetKind.reps,
        ),
        JourneyPoint(
          session: 2,
          absoluteWeek: 5,
          weekKind: MesocycleWeekKind.push,
          exerciseId: 'test-exercise',
          exerciseName: 'Test exercise',
          load: Kg(30),
          hasExternalLoad: true,
          target: 12,
          targetKind: JourneyTargetKind.reps,
        ),
        JourneyPoint(
          session: 3,
          absoluteWeek: 6,
          weekKind: MesocycleWeekKind.deload,
          exerciseId: 'test-exercise',
          exerciseName: 'Test exercise',
          load: Kg(20),
          hasExternalLoad: true,
          target: 10,
          targetKind: JourneyTargetKind.reps,
        ),
      ];

      expect(
        journeyProgressSummary(points, UnitSystem.metric),
        'load 5 → 30 kg (peak) · current 20 kg · '
        'reps 10 → 12 (peak) · current 10 · ends in deload week',
      );
    },
  );

  testWidgets('journey chart renders both series and purposeful week legend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const points = <JourneyPoint>[
      JourneyPoint(
        session: 1,
        absoluteWeek: 1,
        weekKind: MesocycleWeekKind.build,
        exerciseId: 'test-exercise',
        exerciseName: 'Test exercise',
        load: Kg(5),
        hasExternalLoad: true,
        target: 10,
        targetKind: JourneyTargetKind.reps,
      ),
      JourneyPoint(
        session: 2,
        absoluteWeek: 4,
        weekKind: MesocycleWeekKind.easier,
        exerciseId: 'test-exercise',
        exerciseName: 'Test exercise',
        load: Kg(10),
        hasExternalLoad: true,
        target: 11,
        targetKind: JourneyTargetKind.reps,
      ),
      JourneyPoint(
        session: 3,
        absoluteWeek: 6,
        weekKind: MesocycleWeekKind.deload,
        exerciseId: 'test-exercise',
        exerciseName: 'Test exercise',
        load: Kg(7.5),
        hasExternalLoad: true,
        target: 10,
        targetKind: JourneyTargetKind.reps,
      ),
    ];
    const sessions = <JourneySession>[
      JourneySession(
        session: 1,
        absoluteWeek: 1,
        weekKind: MesocycleWeekKind.build,
      ),
      JourneySession(
        session: 2,
        absoluteWeek: 4,
        weekKind: MesocycleWeekKind.easier,
      ),
      JourneySession(
        session: 3,
        absoluteWeek: 6,
        weekKind: MesocycleWeekKind.deload,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyTab(
            form: ReviewFormState.defaults,
            weeks: 6,
            pattern: JourneyPattern.honestNovice,
            result: JourneyResult(points: points, sessions: sessions),
            onWeeksChanged: (_) {},
            onPatternChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Load (kg)'), findsOneWidget);
    expect(find.text('Target reps / hold'), findsOneWidget);
    expect(find.text('Easier · lighter on purpose'), findsOneWidget);
    expect(find.text('Deload · lighter on purpose'), findsOneWidget);
  });
}
