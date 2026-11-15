import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/workout/domain/plan_diff.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_draft.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_repository.g.dart';

/// History layer: workouts in progress and past ones.
///
/// A workout copies its plan when it starts and never reads the plan layer
/// again. Every logged set is written immediately (crash safety).
class WorkoutRepository {
  new(this._db, this._program, this._clock, this._newId);

  final AppDatabase _db;
  final ProgramRepository _program;
  final Clock _clock;
  final IdGenerator _newId;

  List<ResultSetImplementation<dynamic, dynamic>> get _tables => [
    _db.workouts,
    _db.workoutExercises,
    _db.workoutSets,
  ];

  // ------------------------------------------------------------------ reads

  Stream<WorkoutDetail?> watchWorkout(String id) =>
      _db.historyDao.watching(_tables, () => getWorkout(id));

  Future<WorkoutDetail?> getWorkout(String id) async {
    final row = await _db.historyDao.workoutById(id);
    return row == null ? null : await _load(row);
  }

  /// The workout in progress, if any.
  Stream<WorkoutDetail?> watchInProgress() =>
      _db.historyDao.watching(_tables, getInProgress);

  Future<WorkoutDetail?> getInProgress() async {
    final row = await _db.historyDao.inProgressWorkout();
    return row == null ? null : await _load(row);
  }

  Future<WorkoutDetail> _load(WorkoutRow row) async {
    final exercises = await _db.historyDao.exercisesOf([row.id]);
    final sets = await _db.historyDao.setsOf([for (final e in exercises) e.id]);
    return WorkoutDetail(
      workout: _workout(row),
      exercises: [
        for (final e in exercises)
          _exercise(e, [
            for (final s in sets)
              if (s.workoutExerciseId == e.id) s,
          ]),
      ],
    );
  }

  // ------------------------------------------------------------------ start

  /// Starts a workout by copying [exercises] (the session's plan, possibly
  /// edited in the preview). [sessionId] is null for an empty workout.
  /// [planSnapshot] is the session's untouched plan, kept to list the
  /// changes at the end.
  Future<String> startWorkout({
    required String sessionName,
    required List<WorkoutDraftExercise> exercises,
    String? sessionId,
    List<PlannedExercise>? planSnapshot,
  }) async {
    if (await _db.historyDao.inProgressWorkout() != null) {
      throw StateError('A workout is already in progress');
    }
    final now = _clock();
    final id = _newId();
    await _db.transaction(() async {
      await _db.historyDao.insertSynced(
        _db.workouts,
        WorkoutsCompanion(
          id: Value(id),
          sessionId: Value(sessionId),
          sessionName: Value(sessionName),
          startedAt: Value(now),
          status: const Value(WorkoutStatus.inProgress),
          lastActivityAt: Value(now),
          planSnapshot: Value(
            planSnapshot == null ? null : jsonEncode(planSnapshot),
          ),
        ),
        now,
      );
      String? first;
      for (final (i, draft) in exercises.indexed) {
        final exerciseRowId = await _insertExercise(
          workoutId: id,
          plan: draft.plan,
          position: i,
          fromPlan: draft.fromPlan,
          swappedFrom: draft.swappedFrom,
          now: now,
        );
        first ??= exerciseRowId;
      }
      if (first != null) {
        await _db.historyDao.patch(
          _db.workouts,
          id,
          WorkoutsCompanion(currentExerciseId: Value(first)),
          now,
        );
      }
    });
    return id;
  }

  Future<String> _insertExercise({
    required String workoutId,
    required PlannedExercise plan,
    required int position,
    required bool fromPlan,
    required DateTime now,
    String? swappedFrom,
  }) async {
    final id = _newId();
    await _db.historyDao.insertSynced(
      _db.workoutExercises,
      WorkoutExercisesCompanion(
        id: Value(id),
        workoutId: Value(workoutId),
        exerciseId: Value(plan.exerciseId),
        position: Value(position),
        restSeconds: Value(plan.restSeconds),
        status: const Value(WorkoutExerciseStatus.todo),
        swappedFrom: Value(swappedFrom),
        fromPlan: Value(fromPlan),
      ),
      now,
    );
    for (final (i, target) in plan.sets.indexed) {
      await _insertSet(id, i, target, now);
    }
    return id;
  }

  Future<String> _insertSet(
    String workoutExerciseId,
    int position,
    SetTarget raw,
    DateTime now,
  ) async {
    final target = raw.normalized(defaultUnitId: FixedIds.kgUnit);
    final id = _newId();
    await _db.historyDao.insertSynced(
      _db.workoutSets,
      WorkoutSetsCompanion(
        id: Value(id),
        workoutExerciseId: Value(workoutExerciseId),
        position: Value(position),
        targetReps: Value(target.reps),
        targetSeconds: Value(target.seconds),
        isMax: Value(target.isMax),
        plannedLoad: Value(target.load),
        plannedUnitId: Value(target.unitId),
      ),
      now,
    );
    return id;
  }

  // ---------------------------------------------------------------- logging

  /// Logs a set as done with the given values, written to disk at once.
  /// Starts the rest of its exercise unless the whole workout is finished
  /// or [startRest] is false.
  Future<void> logSet(
    String setId, {
    int? reps,
    int? seconds,
    double? load,
    String? unitId,
    bool startRest = true,
  }) async {
    final now = _clock();
    await _db.transaction(() async {
      final set = await _db.historyDao.setById(setId);
      if (set == null) return;
      await _db.historyDao.patch(
        _db.workoutSets,
        setId,
        WorkoutSetsCompanion(
          reps: Value(reps),
          seconds: Value(seconds),
          load: Value(load),
          unitId: Value(load == null ? null : unitId ?? FixedIds.kgUnit),
          completedAt: Value(now),
        ),
        now,
      );
      final exercise = await _db.historyDao.workoutExerciseById(
        set.workoutExerciseId,
      );
      if (exercise == null) return;
      await _refreshExerciseStatus(exercise.id, now);
      final workout = await _db.historyDao.workoutById(exercise.workoutId);
      if (workout == null || workout.status != WorkoutStatus.inProgress) {
        return;
      }
      final detail = await _load(workout);
      final rest =
          startRest && !detail.isAllFinished && exercise.restSeconds > 0;
      await _db.historyDao.patch(
        _db.workouts,
        workout.id,
        WorkoutsCompanion(
          lastActivityAt: Value(now),
          currentExerciseId: Value(exercise.id),
          restEndsAt: Value(
            rest ? now.add(Duration(seconds: exercise.restSeconds)) : null,
          ),
          restTotalSeconds: Value(rest ? exercise.restSeconds : null),
        ),
        now,
      );
    });
  }

  /// Changes the values of a set that is already logged (during the workout
  /// or later from the history). Records and charts follow.
  Future<void> editLoggedSet(
    String setId, {
    int? reps,
    int? seconds,
    double? load,
    String? unitId,
  }) => _db.historyDao.patch(
    _db.workoutSets,
    setId,
    WorkoutSetsCompanion(
      reps: Value(reps),
      seconds: Value(seconds),
      load: Value(load),
      unitId: Value(load == null ? null : unitId ?? FixedIds.kgUnit),
    ),
    _clock(),
  );

  /// Marks a logged set as not done again.
  Future<void> unlogSet(String setId) async {
    final now = _clock();
    await _db.transaction(() async {
      final set = await _db.historyDao.setById(setId);
      if (set == null) return;
      await _db.historyDao.patch(
        _db.workoutSets,
        setId,
        const WorkoutSetsCompanion(
          reps: Value(null),
          seconds: Value(null),
          load: Value(null),
          unitId: Value(null),
          completedAt: Value(null),
        ),
        now,
      );
      await _refreshExerciseStatus(set.workoutExerciseId, now);
    });
  }

  /// Adds a set to an exercise, copying the previous one (with the load
  /// actually used when it is already done). Returns the new set id.
  Future<String> addSet(String workoutExerciseId, {SetTarget? target}) async {
    final now = _clock();
    return await _db.transaction(() async {
      final sets = await _db.historyDao.setsOf([workoutExerciseId]);
      var next = target;
      if (next == null && sets.isNotEmpty) {
        final last = sets.last;
        next = SetTarget(
          reps: last.targetReps,
          seconds: last.targetSeconds,
          isMax: last.isMax,
          load: last.completedAt != null ? last.load : last.plannedLoad,
          unitId: last.completedAt != null ? last.unitId : last.plannedUnitId,
        );
      }
      final position = sets.isEmpty ? 0 : sets.last.position + 1;
      final id = await _insertSet(
        workoutExerciseId,
        position,
        next ?? SetTarget.defaultReps,
        now,
      );
      await _refreshExerciseStatus(workoutExerciseId, now);
      return id;
    });
  }

  /// Removes a set (it can be brought back with [restoreSet]).
  Future<void> removeSet(String setId) async {
    final now = _clock();
    await _db.transaction(() async {
      final set = await _db.historyDao.setById(setId);
      if (set == null) return;
      await _db.historyDao.softDelete(_db.workoutSets, setId, now);
      await _refreshExerciseStatus(set.workoutExerciseId, now);
    });
  }

  /// Undoes [removeSet].
  Future<void> restoreSet(String setId) async {
    final now = _clock();
    await _db.transaction(() async {
      await _db.historyDao.patch(
        _db.workoutSets,
        setId,
        const WorkoutSetsCompanion(deletedAt: Value(null)),
        now,
      );
      final set = await _db.historyDao.setById(setId);
      if (set != null) await _refreshExerciseStatus(set.workoutExerciseId, now);
    });
  }

  /// Changes what a set aims for (this workout only).
  Future<void> setTarget(String setId, SetTarget raw) {
    final target = raw.normalized(defaultUnitId: FixedIds.kgUnit);
    return _db.historyDao.patch(
      _db.workoutSets,
      setId,
      WorkoutSetsCompanion(
        targetReps: Value(target.reps),
        targetSeconds: Value(target.seconds),
        isMax: Value(target.isMax),
        plannedLoad: Value(target.load),
        plannedUnitId: Value(target.unitId),
      ),
      _clock(),
    );
  }

  /// "This machine uses levels": the sets still to do of an exercise switch
  /// to [unitId]. Loads are never converted, so they take [load] (what was
  /// last done in that unit, if anything).
  Future<void> setUnitForRemainingSets(
    String workoutExerciseId,
    String unitId, {
    double? load,
  }) async {
    final now = _clock();
    await _db.transaction(() async {
      for (final set in await _db.historyDao.setsOf([workoutExerciseId])) {
        if (set.completedAt != null) continue;
        await _db.historyDao.patch(
          _db.workoutSets,
          set.id,
          WorkoutSetsCompanion(
            plannedLoad: Value(load),
            plannedUnitId: Value(unitId),
          ),
          now,
        );
      }
    });
  }

  /// done when every set is logged, otherwise back to todo (skipped stays).
  Future<void> _refreshExerciseStatus(String exerciseId, DateTime now) async {
    final exercise = await _db.historyDao.workoutExerciseById(exerciseId);
    if (exercise == null) return;
    final sets = await _db.historyDao.setsOf([exerciseId]);
    final allDone = sets.isNotEmpty && sets.every((s) => s.completedAt != null);
    final status = allDone
        ? WorkoutExerciseStatus.done
        : exercise.status == WorkoutExerciseStatus.skipped &&
              sets.every((s) => s.completedAt == null)
        ? WorkoutExerciseStatus.skipped
        : WorkoutExerciseStatus.todo;
    if (status == exercise.status) return;
    await _db.historyDao.patch(
      _db.workoutExercises,
      exerciseId,
      WorkoutExercisesCompanion(status: Value(status)),
      now,
    );
  }

  // -------------------------------------------------------------- exercises

  /// Shows [workoutExerciseId] in the player.
  Future<void> setCurrentExercise(String workoutId, String workoutExerciseId) {
    final now = _clock();
    return _db.historyDao.patch(
      _db.workouts,
      workoutId,
      WorkoutsCompanion(
        currentExerciseId: Value(workoutExerciseId),
        lastActivityAt: Value(now),
      ),
      now,
    );
  }

  Future<void> skipExercise(String workoutExerciseId) =>
      _setStatus(workoutExerciseId, WorkoutExerciseStatus.skipped);

  Future<void> unskipExercise(String workoutExerciseId) =>
      _setStatus(workoutExerciseId, WorkoutExerciseStatus.todo);

  Future<void> _setStatus(String id, WorkoutExerciseStatus status) async {
    final now = _clock();
    await _db.transaction(() async {
      await _db.historyDao.patch(
        _db.workoutExercises,
        id,
        WorkoutExercisesCompanion(status: Value(status)),
        now,
      );
      if (status == WorkoutExerciseStatus.todo) {
        await _refreshExerciseStatus(id, now);
      }
    });
  }

  /// Adds an exercise at the end (or at [position]). Returns its row id.
  Future<String> addExercise(
    String workoutId,
    PlannedExercise plan, {
    int? position,
  }) async {
    final now = _clock();
    return await _db.transaction(() async {
      final existing = await _db.historyDao.exercisesOf([workoutId]);
      final index = position ?? existing.length;
      final id = await _insertExercise(
        workoutId: workoutId,
        plan: plan,
        position: index,
        fromPlan: false,
        now: now,
      );
      final order = [for (final e in existing) e.id]
        ..insert(index.clamp(0, existing.length), id);
      await _writeOrder(workoutId, order, now);
      return id;
    });
  }

  /// Removes an exercise and its sets from the workout.
  Future<void> removeExercise(String workoutExerciseId) async {
    final now = _clock();
    await _db.transaction(() async {
      final exercise = await _db.historyDao.workoutExerciseById(
        workoutExerciseId,
      );
      if (exercise == null) return;
      await _db.historyDao.softDeleteWhere(
        _db.workoutSets,
        (t) => t.workoutExerciseId.equals(workoutExerciseId),
        now,
      );
      await _db.historyDao.softDelete(
        _db.workoutExercises,
        workoutExerciseId,
        now,
      );
      final workout = await _db.historyDao.workoutById(exercise.workoutId);
      if (workout?.currentExerciseId == workoutExerciseId) {
        await _db.historyDao.patch(
          _db.workouts,
          exercise.workoutId,
          const WorkoutsCompanion(currentExerciseId: Value(null)),
          now,
        );
      }
    });
  }

  Future<void> reorderExercises(String workoutId, List<String> orderedIds) =>
      _db.transaction(() => _writeOrder(workoutId, orderedIds, _clock()));

  Future<void> _writeOrder(
    String workoutId,
    List<String> orderedIds,
    DateTime now,
  ) async {
    final current = {
      for (final e in await _db.historyDao.exercisesOf([workoutId]))
        e.id: e.position,
    };
    for (final (i, id) in orderedIds.indexed) {
      if (current[id] == i) continue;
      await _db.historyDao.patch(
        _db.workoutExercises,
        id,
        WorkoutExercisesCompanion(position: Value(i)),
        now,
      );
    }
  }

  /// Swaps an exercise for [newExerciseId] with [newSets] (see `SwapRule`).
  ///
  /// Sets already logged stay on the exercise that was actually done: it
  /// keeps them and the replacement takes over as a new entry right after.
  /// With nothing logged the entry is replaced in place. Returns the id of
  /// the entry that now holds the replacement.
  Future<String> swapExercise(
    String workoutExerciseId,
    String newExerciseId,
    List<SetTarget> newSets,
  ) async {
    final now = _clock();
    return await _db.transaction(() async {
      final exercise = await _db.historyDao.workoutExerciseById(
        workoutExerciseId,
      );
      if (exercise == null) throw StateError('Exercise not found');
      final sets = await _db.historyDao.setsOf([workoutExerciseId]);
      final done = [
        for (final s in sets)
          if (s.completedAt != null) s,
      ];
      // The exercise the plan had here (kept across successive swaps).
      final origin = exercise.swappedFrom ?? exercise.exerciseId;

      if (done.isEmpty) {
        await _db.historyDao.softDeleteWhere(
          _db.workoutSets,
          (t) => t.workoutExerciseId.equals(workoutExerciseId),
          now,
        );
        await _db.historyDao.patch(
          _db.workoutExercises,
          workoutExerciseId,
          WorkoutExercisesCompanion(
            exerciseId: Value(newExerciseId),
            status: const Value(WorkoutExerciseStatus.todo),
            swappedFrom: Value(
              !exercise.fromPlan || origin == newExerciseId ? null : origin,
            ),
          ),
          now,
        );
        for (final (i, target) in newSets.indexed) {
          await _insertSet(workoutExerciseId, i, target, now);
        }
        return workoutExerciseId;
      }

      // Keep the logged sets where they are; move the rest to a new entry.
      for (final s in sets) {
        if (s.completedAt == null) {
          await _db.historyDao.softDelete(_db.workoutSets, s.id, now);
        }
      }
      await _db.historyDao.patch(
        _db.workoutExercises,
        workoutExerciseId,
        WorkoutExercisesCompanion(
          status: const Value(WorkoutExerciseStatus.done),
          swappedFrom: Value(
            exercise.fromPlan ? exercise.exerciseId : exercise.swappedFrom,
          ),
        ),
        now,
      );
      final remaining = newSets.length > done.length
          ? newSets.sublist(done.length)
          : [newSets.last];
      final existing = await _db.historyDao.exercisesOf([exercise.workoutId]);
      final index = existing.indexWhere((e) => e.id == workoutExerciseId) + 1;
      final id = await _insertExercise(
        workoutId: exercise.workoutId,
        plan: PlannedExercise(
          exerciseId: newExerciseId,
          restSeconds: exercise.restSeconds,
          sets: remaining,
        ),
        position: index,
        fromPlan: exercise.fromPlan,
        swappedFrom: exercise.fromPlan ? exercise.exerciseId : null,
        now: now,
      );
      final order = [for (final e in existing) e.id]..insert(index, id);
      await _writeOrder(exercise.workoutId, order, now);
      final workout = await _db.historyDao.workoutById(exercise.workoutId);
      if (workout?.currentExerciseId == workoutExerciseId) {
        await _db.historyDao.patch(
          _db.workouts,
          exercise.workoutId,
          WorkoutsCompanion(currentExerciseId: Value(id)),
          now,
        );
      }
      return id;
    });
  }

  Future<void> setExerciseRest(String workoutExerciseId, int seconds) =>
      _db.historyDao.patch(
        _db.workoutExercises,
        workoutExerciseId,
        WorkoutExercisesCompanion(restSeconds: Value(seconds)),
        _clock(),
      );

  // ------------------------------------------------------------------ notes

  Future<void> setWorkoutNotes(String workoutId, String notes) =>
      _db.historyDao.patch(
        _db.workouts,
        workoutId,
        WorkoutsCompanion(notes: Value(notes.trim())),
        _clock(),
      );

  Future<void> setExerciseNotes(String workoutExerciseId, String notes) =>
      _db.historyDao.patch(
        _db.workoutExercises,
        workoutExerciseId,
        WorkoutExercisesCompanion(notes: Value(notes.trim())),
        _clock(),
      );

  // ---------------------------------------------------------- pause & rest

  /// Freezes the workout clock and any running timer.
  Future<void> pause(String workoutId) async {
    final now = _clock();
    final workout = await _db.historyDao.workoutById(workoutId);
    if (workout == null || workout.pausedAt != null) return;
    await _db.historyDao.patch(
      _db.workouts,
      workoutId,
      WorkoutsCompanion(pausedAt: Value(now), lastActivityAt: Value(now)),
      now,
    );
  }

  /// Resumes: the paused time is excluded from the duration and the rest
  /// timer continues where it stopped.
  Future<void> resume(String workoutId) async {
    final now = _clock();
    final workout = await _db.historyDao.workoutById(workoutId);
    final pausedAt = workout?.pausedAt;
    if (workout == null || pausedAt == null) return;
    await _db.historyDao.patch(
      _db.workouts,
      workoutId,
      WorkoutsCompanion(
        pausedAt: const Value(null),
        pausedSeconds: Value(
          workout.pausedSeconds + WorkoutClock.pauseLength(pausedAt, now),
        ),
        restEndsAt: Value(
          WorkoutClock.restEndAfterResume(workout.restEndsAt, pausedAt, now),
        ),
        lastActivityAt: Value(now),
      ),
      now,
    );
  }

  /// Starts (or restarts) the rest timer for [seconds].
  Future<void> startRest(String workoutId, int seconds) {
    final now = _clock();
    return _db.historyDao.patch(
      _db.workouts,
      workoutId,
      WorkoutsCompanion(
        restEndsAt: Value(now.add(Duration(seconds: seconds))),
        restTotalSeconds: Value(seconds),
        lastActivityAt: Value(now),
      ),
      now,
    );
  }

  /// +15 s / −15 s. Going below zero ends the rest.
  Future<void> adjustRest(String workoutId, int deltaSeconds) async {
    final now = _clock();
    final row = await _db.historyDao.workoutById(workoutId);
    final endsAt = row?.restEndsAt;
    if (row == null || endsAt == null) return;
    final workout = _workout(row);
    final remaining =
        WorkoutClock.restRemainingSeconds(workout, now) + deltaSeconds;
    if (remaining <= 0) return await endRest(workoutId);
    await _db.historyDao.patch(
      _db.workouts,
      workoutId,
      WorkoutsCompanion(
        restEndsAt: Value(endsAt.add(Duration(seconds: deltaSeconds))),
        restTotalSeconds: Value(
          ((row.restTotalSeconds ?? 0) + deltaSeconds).clamp(1, 3600),
        ),
        lastActivityAt: Value(now),
      ),
      now,
    );
  }

  /// Skip, or the rest ran out.
  Future<void> endRest(String workoutId) async {
    final row = await _db.historyDao.workoutById(workoutId);
    if (row == null || row.restEndsAt == null) return;
    await _db.historyDao.patch(
      _db.workouts,
      workoutId,
      const WorkoutsCompanion(
        restEndsAt: Value(null),
        restTotalSeconds: Value(null),
      ),
      _clock(),
    );
  }

  // ----------------------------------------------------------------- ending

  /// Finishes the workout with what is logged and moves the program's
  /// pointer. A workout with no logged set is discarded instead. Returns
  /// whether it was kept. [endedAt] overrides the end time (auto-finish).
  Future<bool> finish(String workoutId, {DateTime? endedAt}) async {
    final now = _clock();
    return await _db.transaction(() async {
      final row = await _db.historyDao.workoutById(workoutId);
      if (row == null || row.status != WorkoutStatus.inProgress) return false;
      final detail = await _load(row);
      if (detail.doneSetCount == 0) {
        await _end(workoutId, WorkoutStatus.discarded, now, now);
        return false;
      }
      for (final e in detail.exercises) {
        if (e.hasDoneSets && e.status == WorkoutExerciseStatus.todo) {
          await _db.historyDao.patch(
            _db.workoutExercises,
            e.id,
            const WorkoutExercisesCompanion(
              status: Value(WorkoutExerciseStatus.done),
            ),
            now,
          );
        }
      }
      // Ending while paused: the pause itself is not part of the workout.
      await _end(
        workoutId,
        WorkoutStatus.completed,
        endedAt ?? row.pausedAt ?? now,
        now,
      );
      await _program.advanceAfterWorkout(row.sessionId);
      return true;
    });
  }

  /// Finishes a workout left without any action for more than 12 h.
  /// Returns true when one was closed.
  Future<bool> finishIfStale() async {
    final row = await _db.historyDao.inProgressWorkout();
    if (row == null) return false;
    final workout = _workout(row);
    if (!WorkoutClock.shouldAutoFinish(workout, _clock())) return false;
    await finish(row.id, endedAt: WorkoutClock.autoFinishEnd(workout));
    return true;
  }

  /// Drops the workout: nothing of it appears in history or records.
  Future<void> discard(String workoutId) {
    final now = _clock();
    return _end(workoutId, WorkoutStatus.discarded, now, now);
  }

  Future<void> _end(
    String workoutId,
    WorkoutStatus status,
    DateTime endedAt,
    DateTime now,
  ) => _db.historyDao.patch(
    _db.workouts,
    workoutId,
    WorkoutsCompanion(
      status: Value(status),
      endedAt: Value(endedAt),
      pausedAt: const Value(null),
      restEndsAt: const Value(null),
      restTotalSeconds: const Value(null),
    ),
    now,
  );

  /// "Update the program?" → Yes: rewrites the session's plan from the
  /// workout (see [PlanDiff.effectivePlan]).
  Future<void> applyChangesToProgram(String workoutId) async {
    final detail = await getWorkout(workoutId);
    final sessionId = detail?.workout.sessionId;
    if (detail == null || sessionId == null) return;
    if (await _program.getSessionPlan(sessionId) == null) return;
    await _program.savePlan(
      sessionId,
      PlanDiff.planToSave(PlanDiff.effectivePlan(detail)),
    );
  }

  // ---------------------------------------------------------------- history

  /// Deletes a logged set from the history.
  Future<void> deleteSet(String setId) =>
      _db.historyDao.softDelete(_db.workoutSets, setId, _clock());

  /// Deletes a whole workout from the history.
  Future<void> deleteWorkout(String workoutId) async {
    final now = _clock();
    await _db.transaction(() async {
      for (final e in await _db.historyDao.exercisesOf([workoutId])) {
        await _db.historyDao.softDeleteWhere(
          _db.workoutSets,
          (t) => t.workoutExerciseId.equals(e.id),
          now,
        );
        await _db.historyDao.softDelete(_db.workoutExercises, e.id, now);
      }
      await _db.historyDao.softDelete(_db.workouts, workoutId, now);
    });
  }

  // ---------------------------------------------------------------- mappers

  Workout _workout(WorkoutRow row) => Workout(
    id: row.id,
    sessionId: row.sessionId,
    sessionName: row.sessionName,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    status: row.status,
    notes: row.notes,
    pausedAt: row.pausedAt,
    pausedSeconds: row.pausedSeconds,
    lastActivityAt: row.lastActivityAt,
    currentExerciseId: row.currentExerciseId,
    restEndsAt: row.restEndsAt,
    restTotalSeconds: row.restTotalSeconds,
    planSnapshot: _decodePlan(row.planSnapshot),
  );

  List<PlannedExercise>? _decodePlan(String? json) {
    if (json == null) return null;
    return [
      for (final item in jsonDecode(json) as List<dynamic>)
        PlannedExercise.fromJson(item as Map<String, dynamic>),
    ];
  }

  WorkoutExercise _exercise(WorkoutExerciseRow row, List<WorkoutSetRow> sets) =>
      WorkoutExercise(
        id: row.id,
        workoutId: row.workoutId,
        exerciseId: row.exerciseId,
        position: row.position,
        restSeconds: row.restSeconds,
        status: row.status,
        notes: row.notes,
        swappedFrom: row.swappedFrom,
        fromPlan: row.fromPlan,
        sets: [for (final s in sets) _set(s)],
      );

  WorkoutSet _set(WorkoutSetRow row) => WorkoutSet(
    id: row.id,
    workoutExerciseId: row.workoutExerciseId,
    position: row.position,
    target: SetTarget(
      reps: row.targetReps,
      seconds: row.targetSeconds,
      isMax: row.isMax,
      load: row.plannedLoad,
      unitId: row.plannedUnitId,
    ),
    reps: row.reps,
    seconds: row.seconds,
    load: row.load,
    unitId: row.unitId,
    completedAt: row.completedAt,
  );
}

@Riverpod(keepAlive: true)
WorkoutRepository workoutRepository(Ref ref) => WorkoutRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(programRepositoryProvider),
  ref.watch(clockProvider),
  ref.watch(idGeneratorProvider),
);
