import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/workout/domain/plan_diff.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';

void main() {
  final start = DateTime.utc(2026, 11, 15, 18);

  Workout workout({
    DateTime? endedAt,
    DateTime? pausedAt,
    int pausedSeconds = 0,
    DateTime? lastActivityAt,
    DateTime? restEndsAt,
    WorkoutStatus status = WorkoutStatus.inProgress,
  }) => Workout(
    id: 'w',
    sessionName: 'Push A',
    startedAt: start,
    status: status,
    lastActivityAt: lastActivityAt ?? start,
    endedAt: endedAt,
    pausedAt: pausedAt,
    pausedSeconds: pausedSeconds,
    restEndsAt: restEndsAt,
  );

  group('WorkoutClock', () {
    test('elapsed time runs from the start', () {
      expect(
        WorkoutClock.elapsedSeconds(
          workout(),
          start.add(const Duration(minutes: 38, seconds: 12)),
        ),
        38 * 60 + 12,
      );
    });

    test('paused time is not counted', () {
      final w = workout(pausedSeconds: 300);
      expect(
        WorkoutClock.elapsedSeconds(w, start.add(const Duration(minutes: 30))),
        25 * 60,
      );
    });

    test('the clock is frozen while paused', () {
      final w = workout(pausedAt: start.add(const Duration(minutes: 20)));
      expect(
        WorkoutClock.elapsedSeconds(w, start.add(const Duration(hours: 3))),
        20 * 60,
      );
    });

    test('a finished workout lasts until its end, minus pauses', () {
      final w = workout(
        endedAt: start.add(const Duration(minutes: 57)),
        pausedSeconds: 120,
        status: WorkoutStatus.completed,
      );
      expect(
        WorkoutClock.elapsedSeconds(w, start.add(const Duration(days: 9))),
        55 * 60,
      );
    });

    test('auto-finish after 12 h without any action, paused or not', () {
      final w = workout(lastActivityAt: start.add(const Duration(hours: 1)));
      expect(
        WorkoutClock.shouldAutoFinish(w, start.add(const Duration(hours: 12))),
        isFalse,
      );
      expect(
        WorkoutClock.shouldAutoFinish(
          w,
          start.add(const Duration(hours: 13, seconds: 1)),
        ),
        isTrue,
      );
      final paused = workout(
        pausedAt: start.add(const Duration(minutes: 30)),
        lastActivityAt: start.add(const Duration(minutes: 30)),
      );
      expect(
        WorkoutClock.shouldAutoFinish(
          paused,
          start.add(const Duration(hours: 13)),
        ),
        isTrue,
      );
      expect(
        WorkoutClock.shouldAutoFinish(
          workout(status: WorkoutStatus.completed),
          start.add(const Duration(days: 2)),
        ),
        isFalse,
      );
    });

    test('an auto-finished workout ends at its last activity', () {
      final last = start.add(const Duration(minutes: 44));
      expect(WorkoutClock.autoFinishEnd(workout(lastActivityAt: last)), last);
    });

    test('rest countdown rounds up and stops at zero', () {
      final w = workout(restEndsAt: start.add(const Duration(seconds: 90)));
      expect(WorkoutClock.restRemainingSeconds(w, start), 90);
      expect(
        WorkoutClock.restRemainingSeconds(
          w,
          start.add(const Duration(milliseconds: 500)),
        ),
        90,
      );
      expect(
        WorkoutClock.restRemainingSeconds(
          w,
          start.add(const Duration(seconds: 91)),
        ),
        0,
      );
      expect(WorkoutClock.restRemainingSeconds(workout(), start), 0);
    });

    test('pausing freezes the rest and resuming pushes its end back', () {
      final pausedAt = start.add(const Duration(seconds: 30));
      final w = workout(
        restEndsAt: start.add(const Duration(seconds: 90)),
        pausedAt: pausedAt,
      );
      final later = start.add(const Duration(minutes: 10));
      expect(WorkoutClock.restRemainingSeconds(w, later), 60);
      expect(
        WorkoutClock.restEndAfterResume(w.restEndsAt, pausedAt, later),
        later.add(const Duration(seconds: 60)),
      );
      expect(WorkoutClock.restEndAfterResume(null, pausedAt, later), isNull);
      expect(WorkoutClock.pauseLength(pausedAt, later), 570);
    });
  });

  group('WorkoutDetail', () {
    WorkoutSet set(String id, {bool done = false}) => WorkoutSet(
      id: id,
      workoutExerciseId: 'e',
      position: 0,
      target: SetTarget.defaultReps,
      completedAt: done ? start : null,
    );
    WorkoutExercise exercise(
      String id, {
      List<WorkoutSet> sets = const [],
      WorkoutExerciseStatus status = WorkoutExerciseStatus.todo,
    }) => WorkoutExercise(
      id: id,
      workoutId: 'w',
      exerciseId: 'x$id',
      position: 0,
      restSeconds: 90,
      status: status,
      sets: sets,
    );

    final detail = WorkoutDetail(
      workout: workout(),
      exercises: [
        exercise('a', sets: [set('1', done: true), set('2', done: true)]),
        exercise('b', sets: [set('3', done: true), set('4')]),
        exercise('c', sets: [set('5')], status: WorkoutExerciseStatus.skipped),
        exercise('d', sets: [set('6')]),
      ],
    );

    test('counts done sets and exercises', () {
      expect(detail.doneSetCount, 3);
      expect(detail.doneExerciseCount, 2);
      expect(detail.isAllFinished, isFalse);
    });

    test('the current exercise defaults to the first unfinished one', () {
      expect(detail.currentExercise!.id, 'b');
      expect(detail.exercises[1].nextSet!.id, '4');
    });

    test('the stored pointer wins when it is valid', () {
      final pointed = detail.copyWith(
        workout: detail.workout.copyWith(currentExerciseId: 'd'),
      );
      expect(pointed.currentExercise!.id, 'd');
    });

    test('next unfinished exercise skips done and skipped ones and wraps', () {
      expect(detail.nextUnfinishedAfter('a')!.id, 'b');
      expect(detail.nextUnfinishedAfter('b')!.id, 'd');
      expect(detail.nextUnfinishedAfter('d')!.id, 'b');
    });
  });

  group('PlanDiff', () {
    const bench = PlannedExercise(
      exerciseId: 'bench',
      restSeconds: 120,
      sets: [
        SetTarget(reps: 10, load: 40, unitId: 'kg'),
        SetTarget(reps: 10, load: 40, unitId: 'kg'),
      ],
    );
    const press = PlannedExercise(
      exerciseId: 'ohp',
      restSeconds: 90,
      sets: [SetTarget(reps: 8, load: 30, unitId: 'kg')],
    );
    const triceps = PlannedExercise(
      exerciseId: 'triceps',
      restSeconds: 60,
      sets: [SetTarget(reps: 12, load: 15, unitId: 'kg')],
    );
    const original = [bench, press, triceps];

    EffectiveExercise eff(
      PlannedExercise plan, {
      String? swappedFrom,
      bool skipped = false,
    }) => EffectiveExercise(
      plan: plan,
      swappedFrom: swappedFrom,
      skipped: skipped,
    );

    test('an unchanged workout has no changes', () {
      final changes = PlanDiff.diff(original, [
        eff(bench),
        eff(press),
        eff(triceps),
      ]);
      expect(changes, isEmpty);
      expect(PlanDiff.changesProgram(changes), isFalse);
    });

    test('a swap is reported with both exercises', () {
      final changes = PlanDiff.diff(original, [
        eff(bench),
        eff(press.copyWith(exerciseId: 'db-press'), swappedFrom: 'ohp'),
        eff(triceps),
      ]);
      expect(changes, [
        const PlanChange.swapped(
          fromExerciseId: 'ohp',
          toExerciseId: 'db-press',
        ),
      ]);
    });

    test('added and removed exercises', () {
      final changes = PlanDiff.diff(original, [
        eff(bench),
        eff(triceps),
        eff(
          const PlannedExercise(
            exerciseId: 'fly',
            restSeconds: 60,
            sets: [SetTarget(reps: 12)],
          ),
        ),
      ]);
      expect(changes, [
        const PlanChange.added(exerciseId: 'fly'),
        const PlanChange.removed(exerciseId: 'ohp'),
      ]);
    });

    test('a heavier load is a set change', () {
      final heavier = bench.copyWith(
        sets: const [
          SetTarget(reps: 10, load: 42.5, unitId: 'kg'),
          SetTarget(reps: 10, load: 42.5, unitId: 'kg'),
        ],
      );
      final changes = PlanDiff.diff(original, [
        eff(heavier),
        eff(press),
        eff(triceps),
      ]);
      expect(changes.single, isA<PlanSetsChanged>());
      final change = changes.single as PlanSetsChanged;
      expect(change.exerciseId, 'bench');
      expect(change.before.first.load, 40);
      expect(change.after.first.load, 42.5);
    });

    test('an added set is a set change', () {
      final more = bench.copyWith(sets: [...bench.sets, bench.sets.last]);
      final changes = PlanDiff.diff(original, [
        eff(more),
        eff(press),
        eff(triceps),
      ]);
      expect((changes.single as PlanSetsChanged).after, hasLength(3));
    });

    test('a different order is reported once', () {
      final changes = PlanDiff.diff(original, [
        eff(press),
        eff(bench),
        eff(triceps),
      ]);
      expect(changes, [const PlanChange.reordered()]);
    });

    test('skipped exercises are listed but do not change the program', () {
      final changes = PlanDiff.diff(original, [
        eff(bench),
        eff(press),
        eff(triceps, skipped: true),
      ]);
      expect(changes, [const PlanChange.skipped(exerciseId: 'triceps')]);
      expect(PlanDiff.changesProgram(changes), isFalse);
    });

    test('the design example: swap, skip and a heavier bench', () {
      final changes = PlanDiff.diff(original, [
        eff(
          bench.copyWith(
            sets: const [
              SetTarget(reps: 10, load: 42.5, unitId: 'kg'),
              SetTarget(reps: 10, load: 42.5, unitId: 'kg'),
            ],
          ),
        ),
        eff(press.copyWith(exerciseId: 'db-press'), swappedFrom: 'ohp'),
        eff(triceps, skipped: true),
      ]);
      expect(changes.map((c) => c.runtimeType.toString()), [
        contains('PlanSwapped'),
        contains('PlanSetsChanged'),
        contains('PlanSkipped'),
      ]);
      expect(PlanDiff.changesProgram(changes), isTrue);
    });

    group('effectivePlan', () {
      final now = DateTime.utc(2026, 11, 15, 18, 30);
      WorkoutSet done(
        String id,
        SetTarget target, {
        int? reps,
        double? load,
        String? unit,
      }) => WorkoutSet(
        id: id,
        workoutExerciseId: 'e',
        position: 0,
        target: target,
        reps: reps,
        load: load,
        unitId: unit,
        completedAt: now,
      );
      WorkoutSet todo(String id, SetTarget target) => WorkoutSet(
        id: id,
        workoutExerciseId: 'e',
        position: 0,
        target: target,
      );
      const target = SetTarget(reps: 10, load: 40, unitId: 'kg');

      WorkoutDetail detailOf(List<WorkoutExercise> exercises) =>
          WorkoutDetail(workout: workout(), exercises: exercises);

      test('done sets keep their goal and take the load actually used', () {
        final plan = PlanDiff.effectivePlan(
          detailOf([
            WorkoutExercise(
              id: 'e',
              workoutId: 'w',
              exerciseId: 'bench',
              position: 0,
              restSeconds: 120,
              sets: [
                // 9 reps instead of 10 at a heavier load.
                done('1', target, reps: 9, load: 42.5, unit: 'kg'),
                todo('2', target),
              ],
            ),
          ]),
        );
        expect(plan.single.plan.sets, const [
          SetTarget(reps: 10, load: 42.5, unitId: 'kg'),
          SetTarget(reps: 10, load: 40, unitId: 'kg'),
        ]);
      });

      test('missing the reps is performance, not a plan change', () {
        final detail = detailOf([
          WorkoutExercise(
            id: 'e',
            workoutId: 'w',
            exerciseId: 'bench',
            position: 0,
            restSeconds: 120,
            sets: [
              done('1', target, reps: 7, load: 40, unit: 'kg'),
              done('2', target, reps: 6, load: 40, unit: 'kg'),
            ],
          ),
        ]);
        expect(
          PlanDiff.diff(const [bench], PlanDiff.effectivePlan(detail)),
          isEmpty,
        );
      });

      test('a skipped exercise keeps its plan and is flagged', () {
        final plan = PlanDiff.effectivePlan(
          detailOf([
            WorkoutExercise(
              id: 'e',
              workoutId: 'w',
              exerciseId: 'bench',
              position: 0,
              restSeconds: 120,
              status: WorkoutExerciseStatus.skipped,
              sets: [todo('1', target), todo('2', target)],
            ),
          ]),
        );
        expect(plan.single.skipped, isTrue);
        expect(plan.single.plan, bench);
      });

      test('a mid-way swap gives the replacement the full set count', () {
        final plan = PlanDiff.effectivePlan(
          detailOf([
            // One set done on the planned exercise, then swapped.
            WorkoutExercise(
              id: 'a',
              workoutId: 'w',
              exerciseId: 'bench',
              position: 0,
              restSeconds: 120,
              status: WorkoutExerciseStatus.done,
              swappedFrom: 'bench',
              sets: [done('1', target, reps: 10, load: 40, unit: 'kg')],
            ),
            WorkoutExercise(
              id: 'b',
              workoutId: 'w',
              exerciseId: 'machine-press',
              position: 1,
              restSeconds: 120,
              swappedFrom: 'bench',
              sets: [todo('2', SetTarget.defaultReps)],
            ),
          ]),
        );
        expect(plan.single.plan.exerciseId, 'machine-press');
        expect(plan.single.plan.sets, const [
          SetTarget.defaultReps,
          SetTarget.defaultReps,
        ]);
        expect(PlanDiff.diff(const [bench], plan), [
          const PlanChange.swapped(
            fromExerciseId: 'bench',
            toExerciseId: 'machine-press',
          ),
        ]);
      });
    });
  });
}
