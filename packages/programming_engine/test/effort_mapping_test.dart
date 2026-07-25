/// `PROGRAMMING.md` §4 "Feedback capture" — the five-level table, 1:1.
library;

import 'package:programming_engine/programming_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

typedef Mapping = ({
  String uiLabel,
  EffortLevel level,
  RpeBand band,
  int rpe,
  int rir,
  bool clamped,
});

void main() {
  const table = <Mapping>[
    (
      uiLabel: 'Way too easy',
      level: EffortLevel.wayTooEasy,
      band: RpeBand(1, 4),
      rpe: 4,
      rir: 5, // nominal 6+, clamped at 5
      clamped: true,
    ),
    (
      uiLabel: 'A bit easy',
      level: EffortLevel.aBitEasy,
      band: RpeBand(5, 6),
      rpe: 6,
      rir: 4,
      clamped: false,
    ),
    (
      uiLabel: 'Just right',
      level: EffortLevel.justRight,
      band: RpeBand(7, 7),
      rpe: 7,
      rir: 3,
      clamped: false,
    ),
    (
      uiLabel: "Harder than I'd like",
      level: EffortLevel.harderThanIdLike,
      band: RpeBand(8, 8),
      rpe: 8,
      rir: 2,
      clamped: false,
    ),
    (
      uiLabel: 'Too hard',
      level: EffortLevel.tooHard,
      band: RpeBand(9, 10),
      rpe: 9,
      rir: 1,
      clamped: false,
    ),
  ];

  group('§4 the five-level feel tap', () {
    for (final entry in table) {
      test('"${entry.uiLabel}" reads as ${entry.band} / ${entry.rir} RIR', () {
        final interpreted = interpretEffort(entry.level, config);
        expect(interpreted.band, entry.band);
        expect(interpreted.rpe, entry.rpe);
        expect(interpreted.rir, entry.rir);
        expect(interpreted.rirWasClamped, entry.clamped);
        expect(interpreted.band.contains(interpreted.rpe), isTrue);
      });
    }

    test('the levels are ordered 1..5 easiest to hardest', () {
      expect(
        EffortLevel.values.map((l) => l.value),
        <int>[1, 2, 3, 4, 5],
      );
      final rirs = EffortLevel.values
          .map((level) => interpretEffort(level, config).rir)
          .toList();
      for (var i = 1; i < rirs.length; i++) {
        expect(rirs[i], lessThan(rirs[i - 1]), reason: 'RIR must fall monotonically');
      }
    });

    test('§4 interpreted RIR is clamped at 5 — the scale is meaningless beyond that',
        () {
      expect(config.maxInterpretedRir, 5);
      for (final level in EffortLevel.values) {
        expect(interpretEffort(level, config).rir, lessThanOrEqualTo(5));
      }
    });

    test('only "way too easy" triggers the §4.1 calibration regime', () {
      for (final level in EffortLevel.values) {
        expect(
          isCalibrationReport(interpretEffort(level, config), config),
          level == EffortLevel.wayTooEasy,
          reason: level.name,
        );
      }
    });

    test('§4.3 a decrease is licensed only by missed reps or RPE ≥9', () {
      for (final level in EffortLevel.values) {
        final report = interpretEffort(level, config);
        expect(
          licensesDecrease(effort: report, lastReps: 10, targetReps: 10),
          level == EffortLevel.tooHard,
          reason: 'reps met, ${level.name}',
        );
        expect(
          licensesDecrease(effort: report, lastReps: 6, targetReps: 10),
          isTrue,
          reason: 'reps missed, ${level.name}',
        );
      }
    });

    test('decoding a level from the log is total', () {
      expect(EffortLevel.fromValue(3), EffortLevel.justRight);
      expect(EffortLevel.fromValue(0), isNull);
      expect(EffortLevel.fromValue(6), isNull);
      expect(EffortLevel.fromValue(-1), isNull);
      expect(EffortLevel.clampFromValue(0), EffortLevel.wayTooEasy);
      expect(EffortLevel.clampFromValue(99), EffortLevel.tooHard);
      expect(
        EffortReported.fromLevelValue(exerciseId: 'x', level: 7),
        isNull,
      );
      expect(
        EffortReported.fromLevelValue(exerciseId: 'x', level: 5),
        const EffortReported(exerciseId: 'x', level: EffortLevel.tooHard),
      );
    });

    test('a config missing a level still maps it (total by construction)', () {
      const sparse = ProgrammingConfig(
        reportedRpeByLevel: {EffortLevel.justRight: 7},
        rpeBandByLevel: {EffortLevel.justRight: RpeBand(7, 7)},
      );
      final interpreted = interpretEffort(EffortLevel.tooHard, sparse);
      expect(interpreted.rir, 1);
      expect(interpreted.band, const RpeBand(9, 9));
    });
  });

  group('§4 effort targets', () {
    test('RPE 7 means 3 reps in reserve — the beginner target', () {
      expect(EffortTarget.rpe7.rir, 3);
      expect(config.noviceMaxRpe, 7);
    });

    test('an easier week is just an easier target', () {
      expect(EffortTarget.rpe7.easierBy(1), const EffortTarget(6));
      expect(EffortTarget.rpe7.easierBy(99), const EffortTarget(1));
    });
  });
}
