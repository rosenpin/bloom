import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:programming_engine/programming_engine.dart';
import 'package:review_site/models/journey_simulator.dart';
import 'package:review_site/models/review_form_state.dart';
import 'package:review_site/models/review_notes.dart';
import 'package:review_site/widgets/journey_tab.dart';

void main() {
  test('journey volume uses load for loaded moves and reps for bodyweight', () {
    const loaded = JourneyPoint(
      session: 1,
      absoluteWeek: 1,
      weekKind: MesocycleWeekKind.build,
      exerciseId: 'loaded',
      exerciseName: 'Loaded',
      load: Kg(5),
      hasExternalLoad: true,
      sets: 3,
      target: 10,
      targetKind: JourneyTargetKind.reps,
    );
    const bodyweight = JourneyPoint(
      session: 1,
      absoluteWeek: 1,
      weekKind: MesocycleWeekKind.build,
      exerciseId: 'bodyweight',
      exerciseName: 'Bodyweight',
      load: Kg.zero,
      hasExternalLoad: false,
      sets: 3,
      target: 10,
      targetKind: JourneyTargetKind.reps,
    );

    expect(loaded.volume(UnitSystem.metric), 150);
    expect(loaded.volume(UnitSystem.imperial), closeTo(330.693, 0.001));
    expect(bodyweight.volume(UnitSystem.metric), 30);
    expect(bodyweight.volume(UnitSystem.imperial), 30);
  });

  test(
    'journey summary leads with peak volume and explains a deload latest',
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
          sets: 3,
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
          sets: 3,
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
          sets: 3,
          target: 10,
          targetKind: JourneyTargetKind.reps,
        ),
      ];

      expect(
        journeyProgressSummary(points, UnitSystem.metric),
        'volume 150 -> 1080 (peak) · latest 600\n'
        'load 5 -> 30 kg · reps 10 -> 12 · ends in deload week',
      );
    },
  );

  testWidgets('journey chart renders three series and purposeful week legend', (
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
        sets: 3,
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
        sets: 3,
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
        sets: 3,
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

    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Load (kg)'), findsOneWidget);
    expect(find.text('Target reps / hold'), findsOneWidget);
    expect(find.text('Easier · lighter on purpose'), findsOneWidget);
    expect(find.text('Deload · lighter on purpose'), findsOneWidget);
  });

  test('feedback export includes the aligned volume series', () {
    final plan = assemblePlan(
      ReviewFormState.defaults.toProfile(),
      const ProgrammingConfig(),
      catalogV1,
    ).valueOrNull!;
    const points = <JourneyPoint>[
      JourneyPoint(
        session: 1,
        absoluteWeek: 1,
        weekKind: MesocycleWeekKind.build,
        exerciseId: 'test-exercise',
        exerciseName: 'Test exercise',
        load: Kg(5),
        hasExternalLoad: true,
        sets: 3,
        target: 10,
        targetKind: JourneyTargetKind.reps,
      ),
    ];
    final journey = JourneyResult(
      points: points,
      sessions: const <JourneySession>[
        JourneySession(
          session: 1,
          absoluteWeek: 1,
          weekKind: MesocycleWeekKind.build,
        ),
      ],
    );

    final payload =
        jsonDecode(
              createNotesExportJson(
                form: ReviewFormState.defaults,
                plan: plan,
                notes: ReviewNotes(),
                journey: journey,
                journeyWeeks: 6,
                journeyPattern: JourneyPattern.honestNovice.name,
                generatedAt: '2026-01-01T00:00:00.000Z',
              ),
            )
            as Map<String, Object?>;
    final simulation = payload['journeySimulation']! as Map<String, Object?>;
    final series = simulation['series']! as List<Object?>;
    final exercise = series.single! as Map<String, Object?>;

    expect(exercise['sets'], <Object?>[3]);
    expect(exercise['externalLoad'], <Object?>[5]);
    expect(exercise['target'], <Object?>[10]);
    expect(exercise['volume'], <Object?>[150]);
  });
}
