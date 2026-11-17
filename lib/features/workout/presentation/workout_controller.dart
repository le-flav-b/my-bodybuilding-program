import 'package:my_bodybuilding_program/core/notifications/workout_notifier.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/program/domain/program.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_controller.dart';
import 'package:my_bodybuilding_program/features/progress/data/history_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/last_time.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/progress/domain/records.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';
import 'package:my_bodybuilding_program/features/workout/domain/plan_diff.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_draft.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_controller.g.dart';

/// Actions of the workout flow: start, log, deviate, rest, pause, end.
class WorkoutController {
  new(this._ref);

  final Ref _ref;

  /// Name given to a workout that is not started from a session.
  static const String emptyWorkoutName = 'Empty workout';

  WorkoutRepository get _workouts => _ref.read(workoutRepositoryProvider);
  HistoryRepository get _history => _ref.read(historyRepositoryProvider);

  // ------------------------------------------------------------------ start

  /// Starts a workout from [session] with the (possibly edited) [draft].
  Future<String> start(
    SessionPlan session,
    List<WorkoutDraftExercise> draft,
  ) async {
    await _ref.read(workoutNotificationsProvider).requestPermission();
    return await _workouts.startWorkout(
      sessionId: session.session.id,
      sessionName: session.session.name,
      planSnapshot: session.toPlan(),
      exercises: draft,
    );
  }

  /// Starts a workout with no exercises; it never moves the program pointer.
  Future<String> startEmpty() async {
    await _ref.read(workoutNotificationsProvider).requestPermission();
    return await _workouts.startWorkout(
      sessionName: emptyWorkoutName,
      exercises: const [],
    );
  }

  // ---------------------------------------------------------------- logging

  /// Logs [set] as done. Returns the record it beat, if any (trophy).
  Future<RecordEvent?> logSet(
    WorkoutDetail detail,
    WorkoutExercise exercise,
    WorkoutSet set, {
    int? reps,
    int? seconds,
    double? load,
    String? unitId,
  }) async {
    await _workouts.logSet(
      set.id,
      reps: reps,
      seconds: seconds,
      load: load,
      unitId: unitId,
    );
    await _advanceIfIdle(detail.workout.id);
    final sets = await _history.getLoggedSets(
      exerciseId: exercise.exerciseId,
      includeWorkoutId: detail.workout.id,
    );
    for (final event in Records.events(sets)) {
      if (event.setId == set.id) return event;
    }
    return null;
  }

  Future<void> editSet(
    String setId, {
    int? reps,
    int? seconds,
    double? load,
    String? unitId,
  }) => _workouts.editLoggedSet(
    setId,
    reps: reps,
    seconds: seconds,
    load: load,
    unitId: unitId,
  );

  Future<void> unlogSet(String setId) => _workouts.unlogSet(setId);

  Future<void> addSet(String workoutExerciseId) =>
      _workouts.addSet(workoutExerciseId);

  Future<void> removeSet(String setId) => _workouts.removeSet(setId);

  Future<void> restoreSet(String setId) => _workouts.restoreSet(setId);

  Future<void> deleteLoggedSet(String setId) => _workouts.deleteSet(setId);

  // -------------------------------------------------------------- deviating

  Future<void> goTo(String workoutId, String workoutExerciseId) async {
    await _workouts.endRest(workoutId);
    await _workouts.setCurrentExercise(workoutId, workoutExerciseId);
  }

  Future<void> skip(WorkoutDetail detail, WorkoutExercise exercise) async {
    await _workouts.skipExercise(exercise.id);
    if (detail.currentExercise?.id == exercise.id) {
      await _advance(detail.workout.id);
    }
  }

  Future<void> unskip(String workoutExerciseId) =>
      _workouts.unskipExercise(workoutExerciseId);

  Future<void> remove(String workoutExerciseId) =>
      _workouts.removeExercise(workoutExerciseId);

  Future<void> reorder(String workoutId, List<String> orderedIds) =>
      _workouts.reorderExercises(workoutId, orderedIds);

  /// Adds [exercise] at the end with the default plan. Returns its row id.
  Future<String> addExercise(String workoutId, Exercise exercise) async {
    final plan = await _ref
        .read(programControllerProvider)
        .defaultPlanFor(exercise);
    final sets = await _targetsFor(plan.sets, exercise, exercise.measure);
    return await _workouts.addExercise(workoutId, plan.copyWith(sets: sets));
  }

  /// Swaps [current] for [replacement]; logged sets stay on [current].
  Future<void> swap(WorkoutExercise current, Exercise replacement) async {
    final from = await _ref
        .read(catalogueRepositoryProvider)
        .getExercise(current.exerciseId);
    final targets = await _targetsFor(
      [for (final s in current.sets) s.target],
      replacement,
      from?.measure ?? replacement.measure,
    );
    await _workouts.swapExercise(current.id, replacement.id, targets);
  }

  /// Targets for [exercise] with the loads last done on it.
  Future<List<SetTarget>> _targetsFor(
    List<SetTarget> current,
    Exercise exercise,
    Measure from,
  ) async {
    final last = LastTime.sets(
      await _history.getLoggedSets(exerciseId: exercise.id),
    );
    return SwapRule.targets(
      current: current,
      from: from,
      to: exercise.measure,
      lastLoads: [for (final s in last) (load: s.load, unitId: s.unitId)],
    );
  }

  /// "This machine uses levels": the remaining sets switch to [unitId], with
  /// the load last done in that unit on this exercise (never converted).
  Future<void> changeUnit(WorkoutExercise exercise, String unitId) async {
    final sets = await _history.getLoggedSets(exerciseId: exercise.exerciseId);
    LoggedSet? lastInUnit;
    for (final s in sets) {
      if (s.unitId == unitId && s.load != null) lastInUnit = s;
    }
    await _workouts.setUnitForRemainingSets(
      exercise.id,
      unitId,
      load: lastInUnit?.load,
    );
  }

  Future<void> setExerciseNotes(String workoutExerciseId, String notes) =>
      _workouts.setExerciseNotes(workoutExerciseId, notes);

  Future<void> setWorkoutNotes(String workoutId, String notes) =>
      _workouts.setWorkoutNotes(workoutId, notes);

  // ---------------------------------------------------------- pause & rest

  Future<void> pause(String workoutId) => _workouts.pause(workoutId);

  Future<void> resume(String workoutId) => _workouts.resume(workoutId);

  Future<void> adjustRest(String workoutId, int deltaSeconds) async {
    await _workouts.adjustRest(workoutId, deltaSeconds);
    await _advanceIfIdle(workoutId);
  }

  /// Skip, or the rest ran out: back to the sets, on the next exercise when
  /// the current one is finished.
  Future<void> completeRest(String workoutId) async {
    await _workouts.endRest(workoutId);
    await _advanceIfIdle(workoutId);
  }

  Future<void> _advanceIfIdle(String workoutId) async {
    final detail = await _workouts.getWorkout(workoutId);
    if (detail == null || detail.workout.isResting) return;
    if (detail.currentExercise?.isFinished ?? false) await _advance(workoutId);
  }

  Future<void> _advance(String workoutId) async {
    final detail = await _workouts.getWorkout(workoutId);
    final current = detail?.currentExercise;
    if (detail == null || current == null) return;
    final next = detail.nextUnfinishedAfter(current.id);
    if (next != null) await _workouts.setCurrentExercise(workoutId, next.id);
  }

  // ----------------------------------------------------------------- ending

  /// Finishes with what is logged. False when nothing was logged (the
  /// workout is discarded instead).
  Future<bool> finish(String workoutId) => _workouts.finish(workoutId);

  Future<void> discard(String workoutId) => _workouts.discard(workoutId);

  /// What the workout changed compared with the session's plan.
  List<PlanChange> planChanges(WorkoutDetail detail) {
    final snapshot = detail.workout.planSnapshot;
    if (snapshot == null || detail.workout.sessionId == null) return const [];
    return PlanDiff.diff(snapshot, PlanDiff.effectivePlan(detail));
  }

  /// "Update the program?" → Update.
  Future<void> applyChangesToProgram(String workoutId) =>
      _workouts.applyChangesToProgram(workoutId);
}

@Riverpod(keepAlive: true)
WorkoutController workoutController(Ref ref) => WorkoutController(ref);
