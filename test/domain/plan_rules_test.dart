import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/program/domain/estimated_duration.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_draft.dart';

import '../helpers/fixtures.dart';

void main() {
  group('EstimatedDuration', () {
    const plan = [
      PlannedExercise(
        exerciseId: 'bench',
        restSeconds: 90,
        sets: [SetTarget.defaultReps, SetTarget.defaultReps],
      ),
      PlannedExercise(
        exerciseId: 'plank',
        restSeconds: 60,
        sets: [SetTarget(seconds: 45), SetTarget(isMax: true)],
      ),
    ];

    test('adds work, rest after every set and the change of exercise', () {
      // bench: 60 + 2 × (30 + 90); plank: 60 + (45 + 60) + (40 + 60)
      expect(EstimatedDuration.fromPlan(plan), 300 + 265);
    });

    test('an exercise without sets costs nothing', () {
      expect(
        EstimatedDuration.fromPlan(const [
          PlannedExercise(exerciseId: 'x', restSeconds: 90, sets: []),
        ]),
        0,
      );
    });

    test('uses the plan when there is no history', () {
      expect(EstimatedDuration.ofSession(plan), 565);
    });

    test('averages the last three past durations when available', () {
      expect(
        EstimatedDuration.ofSession(
          plan,
          pastDurations: [3000, 3300, 3600, 9999],
        ),
        3300,
      );
      expect(EstimatedDuration.ofSession(plan, pastDurations: [3100]), 3100);
    });

    test('rounds to whole minutes, at least one', () {
      expect(EstimatedDuration.minutes(3290), 55);
      expect(EstimatedDuration.minutes(10), 1);
    });
  });

  group('PlanFormat', () {
    test('clock', () {
      expect(PlanFormat.clock(45), '0:45');
      expect(PlanFormat.clock(90), '1:30');
      expect(PlanFormat.clock(725), '12:05');
      expect(PlanFormat.clock(3723), '1:02:03');
      expect(PlanFormat.clock(-5), '0:00');
    });

    test('duration', () {
      expect(PlanFormat.duration(52 * 60), '52 min');
      expect(PlanFormat.duration(65 * 60), '1 h 05');
    });

    test('straight sets', () {
      const sets = [
        SetTarget(reps: 10, load: 40, unitId: 'kg'),
        SetTarget(reps: 10, load: 40, unitId: 'kg'),
        SetTarget(reps: 10, load: 40, unitId: 'kg'),
        SetTarget(reps: 10, load: 40, unitId: 'kg'),
      ];
      expect(PlanFormat.summary(sets, unitLookup), '4 × 10 · 40 kg');
    });

    test('pyramid with a custom unit', () {
      const sets = [
        SetTarget(reps: 12, load: 5, unitId: 'level'),
        SetTarget(reps: 10, load: 6, unitId: 'level'),
        SetTarget(reps: 8, load: 7, unitId: 'level'),
      ];
      expect(PlanFormat.summary(sets, unitLookup), '12, 10, 8 · 5–7 level');
    });

    test('time, max and bodyweight sets', () {
      expect(
        PlanFormat.summary(const [
          SetTarget(seconds: 45),
          SetTarget(seconds: 45),
          SetTarget(seconds: 45),
        ], unitLookup),
        '3 × 0:45',
      );
      expect(
        PlanFormat.summary(const [
          SetTarget(isMax: true),
          SetTarget(isMax: true),
          SetTarget(isMax: true),
        ], unitLookup),
        '3 × max',
      );
      expect(PlanFormat.summary(const [], unitLookup), 'No sets');
    });

    test('a logged set', () {
      expect(
        PlanFormat.set(
          reps: 10,
          seconds: null,
          loadValue: 42.5,
          unitId: 'kg',
          units: unitLookup,
        ),
        '10 × 42.5 kg',
      );
      expect(
        PlanFormat.set(
          reps: 12,
          seconds: null,
          loadValue: null,
          unitId: null,
          units: unitLookup,
        ),
        '12',
      );
      expect(
        PlanFormat.set(
          reps: null,
          seconds: 80,
          loadValue: 10,
          unitId: 'kg',
          units: unitLookup,
        ),
        '1:20 · 10 kg',
      );
    });
  });

  group('LoadUnit', () {
    test('formats without trailing zeros and with a minus for assisted', () {
      expect(kg.formatValue(40), '40');
      expect(kg.formatValue(42.5), '42.5');
      expect(kg.formatValue(-10), '−10');
      expect(kg.format(42.5), '42.5 kg');
      expect(level.format(7), '7 level');
      expect(formatLoadValue(0, 1), '0');
    });

    test('steps on its grid', () {
      expect(kg.stepBy(40, 1), 40.5);
      expect(kg.stepBy(40, -1), 39.5);
      expect(kg.stepBy(0, -1), -0.5);
      expect(level.stepBy(5, 1), 6);
      const fine = LoadUnit(id: 'f', name: 'f', step: 0.25, decimals: 2);
      expect(fine.stepBy(1.25, 1), 1.5);
      // Off-grid values snap to the grid.
      expect(kg.stepBy(40.3, 1), 41);
    });

    test('validates a draft', () {
      expect(
        const LoadUnitDraft(name: 'level', step: 1, decimals: 0).error,
        isNull,
      );
      expect(
        const LoadUnitDraft(name: ' ', step: 1, decimals: 0).error,
        isNotNull,
      );
      expect(
        const LoadUnitDraft(name: 'x', step: 0, decimals: 0).error,
        isNotNull,
      );
      expect(
        const LoadUnitDraft(name: 'x', step: 1, decimals: 3).error,
        isNotNull,
      );
    });
  });

  group('SetTarget', () {
    test('a load always has a unit and no load has none', () {
      expect(
        const SetTarget(reps: 8, load: 20).normalized(defaultUnitId: 'kg'),
        const SetTarget(reps: 8, load: 20, unitId: 'kg'),
      );
      expect(
        const SetTarget(reps: 8, unitId: 'kg').normalized(defaultUnitId: 'kg'),
        const SetTarget(reps: 8),
      );
    });

    test('round-trips through JSON', () {
      const plan = PlannedExercise(
        exerciseId: 'bench',
        restSeconds: 120,
        sets: [
          SetTarget(reps: 10, load: 40, unitId: 'kg'),
          SetTarget(isMax: true),
        ],
      );
      expect(PlannedExercise.fromJson(plan.toJson()), plan);
    });
  });

  group('SwapRule', () {
    const current = [
      SetTarget(reps: 10, load: 40, unitId: 'kg'),
      SetTarget(reps: 8, load: 45, unitId: 'kg'),
    ];

    test('keeps the goals and drops the loads for the same measure', () {
      expect(
        SwapRule.targets(
          current: current,
          from: Measure.reps,
          to: Measure.reps,
        ),
        const [SetTarget.defaultReps, SetTarget(reps: 8)],
      );
    });

    test('takes the loads last done on the new exercise', () {
      expect(
        SwapRule.targets(
          current: current,
          from: Measure.reps,
          to: Measure.reps,
          lastLoads: const [(load: 12, unitId: 'kg')],
        ),
        const [
          SetTarget(reps: 10, load: 12, unitId: 'kg'),
          SetTarget(reps: 8, load: 12, unitId: 'kg'),
        ],
      );
    });

    test('resets the goals when the measure changes', () {
      expect(
        SwapRule.targets(
          current: current,
          from: Measure.reps,
          to: Measure.time,
        ),
        const [SetTarget.defaultTime, SetTarget.defaultTime],
      );
    });
  });

  group('AppSettings', () {
    test('defaults follow the spec', () {
      const s = AppSettings();
      expect(s.themeMode, AppThemeMode.system);
      expect(s.defaultRestSeconds, 90);
      expect(s.timerSound, isTrue);
      expect(s.timerVibration, isTrue);
      expect(s.weeklyTarget, 3);
    });

    test('reads stored values and ignores bad ones', () {
      final s = AppSettings.fromMap({
        SettingKeys.themeMode: 'dark',
        SettingKeys.defaultRestSeconds: '120',
        SettingKeys.timerSound: 'false',
        SettingKeys.weeklyTarget: '99',
        SettingKeys.keepScreenOn: 'maybe',
      });
      expect(s.themeMode, AppThemeMode.dark);
      expect(s.defaultRestSeconds, 120);
      expect(s.timerSound, isFalse);
      expect(s.weeklyTarget, 7);
      expect(s.keepScreenOn, isTrue);
    });
  });

  group('filterExercises', () {
    final exercises = [
      const Exercise(
        id: '1',
        name: 'Squat',
        measure: Measure.reps,
        primaryMuscleIds: ['quads'],
        secondaryMuscleIds: ['glutes'],
      ),
      const Exercise(
        id: '2',
        name: 'Bench press',
        measure: Measure.reps,
        primaryMuscleIds: ['chest'],
      ),
      Exercise(
        id: '3',
        name: 'Old press',
        measure: Measure.reps,
        primaryMuscleIds: const ['chest'],
        archivedAt: DateTime.utc(2026),
      ),
    ];

    test('hides archived exercises and sorts by name', () {
      expect(filterExercises(exercises).map((e) => e.id), ['2', '1']);
    });

    test('searches by name, case-insensitively', () {
      expect(filterExercises(exercises, query: 'SQU').map((e) => e.id), ['1']);
    });

    test('filters by primary or secondary muscle', () {
      expect(
        filterExercises(exercises, muscleIds: {'glutes'}).map((e) => e.id),
        ['1'],
      );
      expect(
        filterExercises(
          exercises,
          muscleIds: {'glutes', 'chest'},
        ).map((e) => e.id),
        ['2', '1'],
      );
    });

    test('shows only archived exercises when asked', () {
      expect(filterExercises(exercises, archived: true).map((e) => e.id), [
        '3',
      ]);
    });
  });

  test('ExerciseImage parses and writes its stored form', () {
    expect(ExerciseImage.parse(null), isNull);
    expect(ExerciseImage.parse(''), isNull);
    final seed = ExerciseImage.parse('seed:plank.webp');
    expect(seed, const SeedImage('plank.webp'));
    expect((seed! as SeedImage).assetPath, 'assets/seed/images/plank.webp');
    expect(ExerciseImage.parse('user:abc.jpg'), const UserImage('abc.jpg'));
    expect(const UserImage('abc.jpg').raw, 'user:abc.jpg');
    expect(ExerciseImage.parse('weird'), isNull);
  });
}
