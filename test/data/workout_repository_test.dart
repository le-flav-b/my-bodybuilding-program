import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/progress/domain/bests.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/workout/domain/plan_diff.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_draft.dart';

import '../helpers/test_env.dart';

void main() {
  late TestEnv env;
  late String bench;
  late String press;
  late String plank;
  late String push;
  late String pull;

  const benchTarget = SetTarget(reps: 10, load: 40, unitId: kgId);

  setUp(() async {
    env = TestEnv();
    bench = await env.exercise('Bench press');
    press = await env.exercise('Overhead press');
    plank = await env.exercise('Plank', measure: Measure.time);
    push = await env.session('Push', [
      PlannedExercise(
        exerciseId: bench,
        restSeconds: 120,
        sets: sets(2, benchTarget),
      ),
      PlannedExercise(
        exerciseId: press,
        restSeconds: 90,
        sets: sets(2, const SetTarget(reps: 8, load: 30, unitId: kgId)),
      ),
    ]);
    pull = await env.session('Pull', [
      PlannedExercise(
        exerciseId: plank,
        restSeconds: 60,
        sets: sets(1, const SetTarget(seconds: 45)),
      ),
    ]);
  });
  tearDown(() => env.close());

  Future<WorkoutDetail> detail(String id) async =>
      (await env.workouts.getWorkout(id))!;

  group('starting', () {
    test('copies the plan of the session', () async {
      final id = await env.startFromSession(push);
      final d = await detail(id);
      expect(d.workout.sessionId, push);
      expect(d.workout.sessionName, 'Push');
      expect(d.workout.status, WorkoutStatus.inProgress);
      expect(d.workout.startedAt, env.clock.now);
      expect(d.exercises.map((e) => e.exerciseId), [bench, press]);
      expect(d.exercises.first.restSeconds, 120);
      expect(d.exercises.first.sets.map((s) => s.target), [
        benchTarget,
        benchTarget,
      ]);
      expect(d.exercises.every((e) => e.fromPlan), isTrue);
      expect(d.workout.currentExerciseId, d.exercises.first.id);
      expect(d.workout.planSnapshot, hasLength(2));
    });

    test(
      'never reads the plan again: editing the program changes nothing',
      () async {
        final id = await env.startFromSession(push);
        await env.program.savePlan(push, [
          PlannedExercise(
            exerciseId: press,
            restSeconds: 30,
            sets: sets(5, const SetTarget(reps: 3)),
          ),
        ]);
        await env.program.renameSession(push, 'Renamed');
        final d = await detail(id);
        expect(d.workout.sessionName, 'Push');
        expect(d.exercises.map((e) => e.exerciseId), [bench, press]);
        expect(d.exercises.first.sets, hasLength(2));
      },
    );

    test('an empty workout has no session and no exercises', () async {
      final id = await env.workouts.startWorkout(
        sessionName: 'Empty workout',
        exercises: const [],
      );
      final d = await detail(id);
      expect(d.workout.sessionId, isNull);
      expect(d.exercises, isEmpty);
      expect(d.workout.planSnapshot, isNull);
    });

    test('only one workout can be in progress', () async {
      await env.startFromSession(push);
      await expectLater(env.startFromSession(pull), throwsStateError);
    });

    test('is found again as the workout in progress (resume)', () async {
      expect(await env.workouts.getInProgress(), isNull);
      final id = await env.startFromSession(push);
      expect((await env.workouts.getInProgress())!.workout.id, id);
    });
  });

  group('logging', () {
    test('a logged set is saved at once with its values and time', () async {
      final id = await env.startFromSession(push);
      final set = (await detail(id)).exercises.first.sets.first;
      env.clock.advance(const Duration(minutes: 3));
      await env.workouts.logSet(set.id, reps: 9, load: 42.5, unitId: kgId);

      final logged = (await detail(id)).exercises.first.sets.first;
      expect(logged.isDone, isTrue);
      expect(logged.completedAt, env.clock.now);
      expect(logged.reps, 9);
      expect(logged.load, 42.5);
      expect(logged.unitId, kgId);
      // The planned snapshot is untouched.
      expect(logged.target, benchTarget);
    });

    test('starts the rest of that exercise', () async {
      final id = await env.startFromSession(push);
      final set = (await detail(id)).exercises.first.sets.first;
      await env.workouts.logSet(set.id, reps: 10, load: 40, unitId: kgId);
      final w = (await detail(id)).workout;
      expect(w.restTotalSeconds, 120);
      expect(w.restEndsAt, env.clock.now.add(const Duration(seconds: 120)));
      expect(WorkoutClock.restRemainingSeconds(w, env.clock.now), 120);
    });

    test('an exercise is done once all its sets are logged', () async {
      final id = await env.startFromSession(push);
      final first = (await detail(id)).exercises.first;
      await env.workouts.logSet(first.sets[0].id, reps: 10, load: 40);
      expect(
        (await detail(id)).exercises.first.status,
        WorkoutExerciseStatus.todo,
      );
      await env.workouts.logSet(first.sets[1].id, reps: 10, load: 40);
      expect(
        (await detail(id)).exercises.first.status,
        WorkoutExerciseStatus.done,
      );
    });

    test('no rest after the very last set of the workout', () async {
      final id = await env.startFromSession(push);
      await env.logEverything(id);
      final d = await detail(id);
      expect(d.isAllFinished, isTrue);
      expect(d.workout.restEndsAt, isNull);
    });

    test('a bodyweight set stores no unit', () async {
      final id = await env.startFromSession(push);
      final set = (await detail(id)).exercises.first.sets.first;
      await env.workouts.logSet(set.id, reps: 12, unitId: kgId);
      final logged = (await detail(id)).exercises.first.sets.first;
      expect(logged.load, isNull);
      expect(logged.unitId, isNull);
    });

    test(
      'add a set copies the previous one, with the load actually used',
      () async {
        final id = await env.startFromSession(push);
        final first = (await detail(id)).exercises.first;
        await env.workouts.logSet(first.sets[0].id, reps: 10, load: 42.5);
        await env.workouts.logSet(first.sets[1].id, reps: 10, load: 45);
        await env.workouts.addSet(first.id);
        final after = (await detail(id)).exercises.first;
        expect(after.sets, hasLength(3));
        expect(
          after.sets.last.target,
          const SetTarget(reps: 10, load: 45, unitId: kgId),
        );
        expect(after.status, WorkoutExerciseStatus.todo);
      },
    );

    test('remove a set and undo', () async {
      final id = await env.startFromSession(push);
      final first = (await detail(id)).exercises.first;
      await env.workouts.removeSet(first.sets[1].id);
      expect((await detail(id)).exercises.first.sets, hasLength(1));
      await env.workouts.restoreSet(first.sets[1].id);
      expect((await detail(id)).exercises.first.sets, hasLength(2));
    });

    test('edit and unlog a set', () async {
      final id = await env.startFromSession(push);
      final set = (await detail(id)).exercises.first.sets.first;
      await env.workouts.logSet(set.id, reps: 10, load: 40);
      await env.workouts.editLoggedSet(set.id, reps: 8, load: 41);
      var after = (await detail(id)).exercises.first.sets.first;
      expect(after.reps, 8);
      expect(after.load, 41);
      await env.workouts.unlogSet(set.id);
      after = (await detail(id)).exercises.first.sets.first;
      expect(after.isDone, isFalse);
      expect(after.reps, isNull);
    });

    test('changing the unit applies to the remaining sets only', () async {
      final level = await env.units.createUnit(
        const LoadUnitDraft(name: 'level', step: 1, decimals: 0),
      );
      final id = await env.startFromSession(push);
      final first = (await detail(id)).exercises.first;
      await env.workouts.logSet(first.sets[0].id, reps: 10, load: 40);
      await env.workouts.setUnitForRemainingSets(first.id, level, load: 6);
      final after = (await detail(id)).exercises.first;
      // The logged set stays in kg: units are never converted.
      expect(after.sets[0].unitId, kgId);
      expect(after.sets[0].load, 40);
      expect(after.sets[1].target, SetTarget(reps: 10, load: 6, unitId: level));
    });
  });

  group('deviating from the plan', () {
    test('jump to another exercise', () async {
      final id = await env.startFromSession(push);
      final second = (await detail(id)).exercises[1];
      await env.workouts.setCurrentExercise(id, second.id);
      expect((await detail(id)).currentExercise!.id, second.id);
    });

    test('skip and un-skip an exercise', () async {
      final id = await env.startFromSession(push);
      final second = (await detail(id)).exercises[1];
      await env.workouts.skipExercise(second.id);
      expect((await detail(id)).exercises[1].isSkipped, isTrue);
      await env.workouts.unskipExercise(second.id);
      expect(
        (await detail(id)).exercises[1].status,
        WorkoutExerciseStatus.todo,
      );
    });

    test('add, reorder and remove exercises', () async {
      final id = await env.startFromSession(push);
      final added = await env.workouts.addExercise(
        id,
        PlannedExercise(
          exerciseId: plank,
          restSeconds: 60,
          sets: sets(2, SetTarget.defaultTime),
        ),
      );
      var d = await detail(id);
      expect(d.exercises.map((e) => e.exerciseId), [bench, press, plank]);
      expect(d.exercises.last.fromPlan, isFalse);

      await env.workouts.reorderExercises(id, [
        added,
        d.exercises[0].id,
        d.exercises[1].id,
      ]);
      d = await detail(id);
      expect(d.exercises.map((e) => e.exerciseId), [plank, bench, press]);

      await env.workouts.removeExercise(d.exercises[1].id);
      d = await detail(id);
      expect(d.exercises.map((e) => e.exerciseId), [plank, press]);
    });

    test('swap before any set replaces the exercise in place', () async {
      final fly = await env.exercise('Fly');
      final id = await env.startFromSession(push);
      final second = (await detail(id)).exercises[1];
      final holder = await env.workouts.swapExercise(
        second.id,
        fly,
        sets(2, const SetTarget(reps: 8)),
      );
      final d = await detail(id);
      expect(holder, second.id);
      expect(d.exercises.map((e) => e.exerciseId), [bench, fly]);
      expect(d.exercises[1].swappedFrom, press);
      expect(
        d.exercises[1].sets.map((s) => s.target),
        sets(2, const SetTarget(reps: 8)),
      );
    });

    test(
      'swap after some sets: the logs stay on the exercise actually done',
      () async {
        final fly = await env.exercise('Fly');
        final id = await env.startFromSession(push);
        final first = (await detail(id)).exercises.first;
        await env.workouts.logSet(first.sets[0].id, reps: 10, load: 40);
        final holder = await env.workouts.swapExercise(
          first.id,
          fly,
          sets(2, const SetTarget(reps: 12)),
        );
        final d = await detail(id);
        expect(d.exercises.map((e) => e.exerciseId), [bench, fly, press]);
        // The bench keeps its logged set and is closed.
        expect(d.exercises[0].sets, hasLength(1));
        expect(d.exercises[0].sets.single.isDone, isTrue);
        expect(d.exercises[0].isSwapRemainder, isTrue);
        // The replacement takes the remaining set.
        expect(d.exercises[1].id, holder);
        expect(d.exercises[1].sets, hasLength(1));
        expect(d.exercises[1].swappedFrom, bench);
        expect(d.workout.currentExerciseId, holder);
      },
    );

    test('exercise and workout notes', () async {
      final id = await env.startFromSession(push);
      final first = (await detail(id)).exercises.first;
      await env.workouts.setExerciseNotes(first.id, ' felt heavy ');
      await env.workouts.setWorkoutNotes(id, 'Good session');
      final d = await detail(id);
      expect(d.exercises.first.notes, 'felt heavy');
      expect(d.workout.notes, 'Good session');
    });
  });

  group('pause and rest', () {
    test('paused time is excluded from the duration', () async {
      final id = await env.startFromSession(push);
      env.clock.advance(const Duration(minutes: 10));
      await env.workouts.pause(id);
      env.clock.advance(const Duration(minutes: 25));
      var w = (await detail(id)).workout;
      expect(w.isPaused, isTrue);
      expect(WorkoutClock.elapsedSeconds(w, env.clock.now), 600);

      await env.workouts.resume(id);
      env.clock.advance(const Duration(minutes: 5));
      w = (await detail(id)).workout;
      expect(w.isPaused, isFalse);
      expect(w.pausedSeconds, 25 * 60);
      expect(WorkoutClock.elapsedSeconds(w, env.clock.now), 900);
    });

    test('pausing freezes the rest timer', () async {
      final id = await env.startFromSession(push);
      final set = (await detail(id)).exercises.first.sets.first;
      await env.workouts.logSet(set.id, reps: 10, load: 40);
      env.clock.advance(const Duration(seconds: 30));
      await env.workouts.pause(id);
      env.clock.advance(const Duration(minutes: 10));
      expect(
        WorkoutClock.restRemainingSeconds(
          (await detail(id)).workout,
          env.clock.now,
        ),
        90,
      );
      await env.workouts.resume(id);
      env.clock.advance(const Duration(seconds: 20));
      expect(
        WorkoutClock.restRemainingSeconds(
          (await detail(id)).workout,
          env.clock.now,
        ),
        70,
      );
    });

    test('+15 s, −15 s and skip', () async {
      final id = await env.startFromSession(push);
      await env.workouts.startRest(id, 90);
      await env.workouts.adjustRest(id, 15);
      var w = (await detail(id)).workout;
      expect(WorkoutClock.restRemainingSeconds(w, env.clock.now), 105);
      expect(w.restTotalSeconds, 105);
      await env.workouts.adjustRest(id, -15);
      await env.workouts.adjustRest(id, -15);
      w = (await detail(id)).workout;
      expect(WorkoutClock.restRemainingSeconds(w, env.clock.now), 75);
      await env.workouts.endRest(id);
      expect((await detail(id)).workout.isResting, isFalse);
    });

    test('−15 s below zero ends the rest', () async {
      final id = await env.startFromSession(push);
      await env.workouts.startRest(id, 10);
      await env.workouts.adjustRest(id, -15);
      expect((await detail(id)).workout.isResting, isFalse);
    });
  });

  group('ending', () {
    test('finish keeps the workout and advances the pointer', () async {
      final id = await env.startFromSession(push);
      await env.logEverything(id);
      env.clock.advance(const Duration(minutes: 1));
      expect(await env.workouts.finish(id), isTrue);
      final w = (await detail(id)).workout;
      expect(w.status, WorkoutStatus.completed);
      expect(w.endedAt, env.clock.now);
      expect(await env.workouts.getInProgress(), isNull);
      expect((await env.program.getOverview()).nextSessionId, pull);
    });

    test('the pointer follows the session actually done', () async {
      // Push is next, but Pull is done: next is the session after Pull.
      final id = await env.startFromSession(pull);
      await env.logEverything(id);
      await env.workouts.finish(id);
      expect((await env.program.getOverview()).nextSessionId, push);
    });

    test('an empty workout does not move the pointer', () async {
      await env.program.setNextSession(pull);
      final id = await env.workouts.startWorkout(
        sessionName: 'Empty workout',
        exercises: [
          WorkoutDraftExercise(
            fromPlan: false,
            plan: PlannedExercise(
              exerciseId: bench,
              restSeconds: 90,
              sets: sets(1, benchTarget),
            ),
          ),
        ],
      );
      await env.logEverything(id);
      await env.workouts.finish(id);
      expect((await env.program.getOverview()).nextSessionId, pull);
    });

    test('finishing with nothing logged discards the workout', () async {
      final id = await env.startFromSession(push);
      expect(await env.workouts.finish(id), isFalse);
      expect((await detail(id)).workout.status, WorkoutStatus.discarded);
      expect((await env.program.getOverview()).nextSessionId, push);
      expect(await env.history.getWorkoutSummaries(), isEmpty);
    });

    test('finishing while paused ends at the pause', () async {
      final id = await env.startFromSession(push);
      await env.logEverything(id);
      final pausedAt = env.clock.now;
      await env.workouts.pause(id);
      env.clock.advance(const Duration(hours: 2));
      await env.workouts.finish(id);
      final w = (await detail(id)).workout;
      expect(w.endedAt, pausedAt);
      expect(w.isPaused, isFalse);
      expect(WorkoutClock.elapsedSeconds(w, env.clock.now), 8 * 60);
    });

    test('discard keeps nothing in history or records', () async {
      final id = await env.startFromSession(push);
      await env.logEverything(id);
      await env.workouts.discard(id);
      expect(await env.history.getLoggedSets(), isEmpty);
      expect(await env.workouts.getInProgress(), isNull);
      expect((await env.program.getOverview()).nextSessionId, push);
    });

    test(
      'a workout idle for more than 12 h is finished automatically',
      () async {
        final id = await env.startFromSession(push);
        final first = (await detail(id)).exercises.first;
        env.clock.advance(const Duration(minutes: 20));
        await env.workouts.logSet(first.sets[0].id, reps: 10, load: 40);
        final lastActivity = env.clock.now;

        env.clock.advance(const Duration(hours: 11));
        expect(await env.workouts.finishIfStale(), isFalse);
        env.clock.advance(const Duration(hours: 2));
        expect(await env.workouts.finishIfStale(), isTrue);

        final w = (await detail(id)).workout;
        expect(w.status, WorkoutStatus.completed);
        expect(w.endedAt, lastActivity);
        expect((await env.program.getOverview()).nextSessionId, pull);
      },
    );

    test('a stale workout with nothing logged is discarded', () async {
      final id = await env.startFromSession(push);
      env.clock.advance(const Duration(hours: 13));
      expect(await env.workouts.finishIfStale(), isTrue);
      expect((await detail(id)).workout.status, WorkoutStatus.discarded);
    });
  });

  group('update the program?', () {
    test('nothing to report when the plan was followed', () async {
      final id = await env.startFromSession(push);
      await env.logEverything(id);
      await env.workouts.finish(id);
      final d = await detail(id);
      expect(
        PlanDiff.diff(d.workout.planSnapshot!, PlanDiff.effectivePlan(d)),
        isEmpty,
      );
    });

    test('yes rewrites the session from the workout', () async {
      final fly = await env.exercise('Fly');
      final id = await env.startFromSession(push);
      var d = await detail(id);
      // Heavier bench, one more set, and the press swapped for flies.
      await env.workouts.logSet(
        d.exercises[0].sets[0].id,
        reps: 10,
        load: 42.5,
      );
      await env.workouts.logSet(d.exercises[0].sets[1].id, reps: 9, load: 42.5);
      final extra = await env.workouts.addSet(d.exercises[0].id);
      await env.workouts.logSet(extra, reps: 8, load: 42.5);
      await env.workouts.swapExercise(
        d.exercises[1].id,
        fly,
        sets(2, const SetTarget(reps: 12)),
      );
      await env.workouts.finish(id);

      d = await detail(id);
      final changes = PlanDiff.diff(
        d.workout.planSnapshot!,
        PlanDiff.effectivePlan(d),
      );
      expect(PlanDiff.changesProgram(changes), isTrue);
      expect(changes.whereType<PlanSwapped>().single.toExerciseId, fly);
      expect(changes.whereType<PlanSetsChanged>().single.exerciseId, bench);

      await env.workouts.applyChangesToProgram(id);
      final plan = (await env.program.getSessionPlan(push))!;
      expect(plan.exercises.map((e) => e.exerciseId), [bench, fly]);
      expect(
        plan.exercises[0].sets.map((s) => s.target),
        sets(3, const SetTarget(reps: 10, load: 42.5, unitId: kgId)),
      );
      expect(
        plan.exercises[1].sets.map((s) => s.target),
        sets(2, const SetTarget(reps: 12)),
      );
    });

    test('no leaves the program as it was', () async {
      final id = await env.startFromSession(push);
      final d = await detail(id);
      await env.workouts.logSet(d.exercises[0].sets[0].id, reps: 10, load: 50);
      await env.workouts.removeExercise(d.exercises[1].id);
      await env.workouts.finish(id);
      final plan = (await env.program.getSessionPlan(push))!;
      expect(plan.exercises.map((e) => e.exerciseId), [bench, press]);
      expect(plan.exercises[0].sets.first.target, benchTarget);
    });

    test('a skipped exercise stays in the program', () async {
      final id = await env.startFromSession(push);
      final d = await detail(id);
      await env.workouts.skipExercise(d.exercises[1].id);
      await env.logEverything(id);
      await env.workouts.finish(id);
      await env.workouts.applyChangesToProgram(id);
      final plan = (await env.program.getSessionPlan(push))!;
      expect(plan.exercises.map((e) => e.exerciseId), [bench, press]);
      expect(plan.exercises[1].sets, hasLength(2));
    });
  });

  group('history and derived data', () {
    Future<String> doPush({required double load, int reps = 10}) async {
      final id = await env.startFromSession(push);
      final d = await detail(id);
      for (final s in d.exercises.first.sets) {
        env.clock.advance(const Duration(minutes: 3));
        await env.workouts.logSet(s.id, reps: reps, load: load);
      }
      env.clock.advance(const Duration(minutes: 3));
      await env.workouts.finish(id);
      env.clock.advance(const Duration(days: 2));
      return id;
    }

    test('full flow: start next session, log all sets, finish', () async {
      // Start the session the program suggests.
      final next = (await env.program.getOverview()).nextSession!;
      expect(next.session.name, 'Push');
      final first = await env.startFromSession(next.session.id);
      await env.logEverything(first);
      env.clock.advance(const Duration(minutes: 2));
      await env.workouts.finish(first);

      // History has it, with its numbers.
      var summaries = await env.history.getWorkoutSummaries();
      expect(summaries.single.sessionName, 'Push');
      expect(summaries.single.setCount, 4);
      expect(summaries.single.exerciseCount, 2);
      expect(summaries.single.durationSeconds, 10 * 60);
      expect(summaries.single.recordCount, 0);
      // The next session moved on.
      expect(
        (await env.program.getOverview()).nextSession!.session.name,
        'Pull',
      );

      // Second time on Push, heavier: records are updated.
      env.clock.advance(const Duration(days: 2));
      await env.program.setNextSession(push);
      final second = await env.startFromSession(push);
      final d = await detail(second);
      for (final e in d.exercises) {
        for (final s in e.sets) {
          env.clock.advance(const Duration(minutes: 2));
          await env.workouts.logSet(
            s.id,
            reps: s.target.reps,
            load: s.target.load! + 2.5,
            unitId: kgId,
          );
        }
      }
      await env.workouts.finish(second);

      final logged = await env.history.getLoggedSets();
      expect(logged, hasLength(8));
      final records = {
        for (final r in Bests.current(logged)) r.exerciseId: r.value,
      };
      expect(records, {bench: 42.5, press: 32.5});
      final events = Bests.ofWorkout(Bests.events(logged), second);
      expect(events, hasLength(2));
      expect(events.map((e) => e.previous), containsAll([40, 30]));

      summaries = await env.history.getWorkoutSummaries();
      expect(summaries.map((s) => s.id), [second, first]);
      expect(summaries.first.recordCount, 2);
      expect(
        (await env.program.getOverview()).nextSession!.session.name,
        'Pull',
      );
    });

    test('logged sets carry what charts and records need', () async {
      final id = await doPush(load: 40);
      final logged = await env.history.getLoggedSets(exerciseId: bench);
      expect(logged, hasLength(2));
      expect(logged.first.workoutId, id);
      expect(logged.first.measure, Measure.reps);
      expect(logged.first.sessionName, 'Push');
      expect(SeriesKey.of(logged.first), (
        const SeriesKey.load(unitId: kgId),
        40.0,
      ));
      expect(logged.first.order, lessThan(logged.last.order));
    });

    test(
      'the workout in progress can be included (records while training)',
      () async {
        await doPush(load: 40);
        final id = await env.startFromSession(push);
        final set = (await detail(id)).exercises.first.sets.first;
        await env.workouts.logSet(set.id, reps: 10, load: 45);
        expect(
          await env.history.getLoggedSets(exerciseId: bench),
          hasLength(2),
        );
        final withCurrent = await env.history.getLoggedSets(
          exerciseId: bench,
          includeWorkoutId: id,
        );
        expect(withCurrent, hasLength(3));
        expect(Bests.events(withCurrent).single.setId, set.id);
      },
    );

    test('editing or deleting history recomputes the records', () async {
      await doPush(load: 40);
      final typo = await doPush(load: 400);
      await doPush(load: 45);
      var logged = await env.history.getLoggedSets(exerciseId: bench);
      expect(Bests.current(logged).single.value, 400);

      // Fix one set, delete the other.
      final wrong = (await detail(typo)).exercises.first.sets;
      await env.workouts.editLoggedSet(wrong[0].id, reps: 10, load: 40);
      await env.workouts.deleteSet(wrong[1].id);
      logged = await env.history.getLoggedSets(exerciseId: bench);
      expect(logged, hasLength(5));
      expect(Bests.current(logged).single.value, 45);
      expect(Bests.events(logged).single.value, 45);
    });

    test('deleting a workout removes it from history', () async {
      final first = await doPush(load: 40);
      final second = await doPush(load: 45);
      await env.workouts.deleteWorkout(second);
      expect((await env.history.getWorkoutSummaries()).map((s) => s.id), [
        first,
      ]);
      expect(await env.history.getLoggedSets(), hasLength(2));
      expect(await env.workouts.getWorkout(second), isNull);
    });

    test('watchWorkoutSummaries emits when a workout is finished', () async {
      final counts = <int>[];
      final sub = env.history.watchWorkoutSummaries().listen(
        (s) => counts.add(s.length),
      );
      await pumpEventQueue();
      await doPush(load: 40);
      await pumpEventQueue();
      await sub.cancel();
      expect(counts.first, 0);
      expect(counts.last, 1);
    });
  });
}
