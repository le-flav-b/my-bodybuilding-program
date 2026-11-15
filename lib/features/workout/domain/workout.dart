import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';

part 'workout.freezed.dart';

enum WorkoutStatus { inProgress, completed, discarded }

enum WorkoutExerciseStatus { todo, done, skipped }

/// A workout: a copy of what was planned plus what was done.
@freezed
abstract class Workout with _$Workout {
  const factory({
    required String id,
    required String sessionName,
    required DateTime startedAt,
    required WorkoutStatus status,
    required DateTime lastActivityAt,
    String? sessionId,
    DateTime? endedAt,
    @Default('') String notes,
    DateTime? pausedAt,
    @Default(0) int pausedSeconds,
    String? currentExerciseId,
    DateTime? restEndsAt,
    int? restTotalSeconds,

    /// The session's plan as it was at start (null for an empty workout).
    List<PlannedExercise>? planSnapshot,
  }) = _Workout;
  const new _();

  bool get isInProgress => status == WorkoutStatus.inProgress;
  bool get isPaused => pausedAt != null;
  bool get isResting => restEndsAt != null;
}

/// One set of a workout: the planned snapshot and, once done, the values.
@freezed
abstract class WorkoutSet with _$WorkoutSet {
  const factory({
    required String id,
    required String workoutExerciseId,
    required int position,
    required SetTarget target,
    int? reps,
    int? seconds,
    double? load,
    String? unitId,
    DateTime? completedAt,
  }) = _WorkoutSet;
  const new _();

  bool get isDone => completedAt != null;
}

/// An exercise of a workout with its sets.
@freezed
abstract class WorkoutExercise with _$WorkoutExercise {
  const factory({
    required String id,
    required String workoutId,
    required String exerciseId,
    required int position,
    required int restSeconds,
    @Default(WorkoutExerciseStatus.todo) WorkoutExerciseStatus status,
    @Default('') String notes,
    String? swappedFrom,
    @Default(true) bool fromPlan,
    @Default(<WorkoutSet>[]) List<WorkoutSet> sets,
  }) = _WorkoutExercise;
  const new _();

  Iterable<WorkoutSet> get doneSets => sets.where((s) => s.isDone);
  int get doneCount => doneSets.length;
  bool get hasDoneSets => sets.any((s) => s.isDone);
  bool get allSetsDone => sets.isNotEmpty && sets.every((s) => s.isDone);
  bool get isSkipped => status == WorkoutExerciseStatus.skipped;

  /// The already-done part of an exercise that was swapped mid-way: its
  /// logged sets stay here and the rest moved to the replacement. Marked by
  /// [swappedFrom] pointing at its own exercise.
  bool get isSwapRemainder => swappedFrom == exerciseId;

  /// The first set still to do, if any.
  WorkoutSet? get nextSet {
    for (final s in sets) {
      if (!s.isDone) return s;
    }
    return null;
  }

  /// Nothing left to do here: every set done, or skipped.
  bool get isFinished => isSkipped || allSetsDone;
}

/// A workout with its exercises and sets.
@freezed
abstract class WorkoutDetail with _$WorkoutDetail {
  const factory({
    required Workout workout,
    @Default(<WorkoutExercise>[]) List<WorkoutExercise> exercises,
  }) = _WorkoutDetail;
  const new _();

  int get doneSetCount => exercises.fold(0, (sum, e) => sum + e.doneCount);

  /// Exercises with at least one logged set.
  int get doneExerciseCount => exercises.where((e) => e.hasDoneSets).length;

  WorkoutExercise? exercise(String? id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// The exercise shown in the player: the stored pointer when valid,
  /// otherwise the first unfinished exercise, otherwise the last one.
  WorkoutExercise? get currentExercise {
    final pointed = exercise(workout.currentExerciseId);
    if (pointed != null) return pointed;
    return firstUnfinished ?? (exercises.isEmpty ? null : exercises.last);
  }

  WorkoutExercise? get firstUnfinished {
    for (final e in exercises) {
      if (!e.isFinished) return e;
    }
    return null;
  }

  /// The next unfinished exercise after [exerciseId] in list order,
  /// wrapping to earlier unfinished ones; null when everything is finished.
  WorkoutExercise? nextUnfinishedAfter(String exerciseId) {
    final index = exercises.indexWhere((e) => e.id == exerciseId);
    if (index < 0) return firstUnfinished;
    final ordered = [...exercises.skip(index + 1), ...exercises.take(index)];
    for (final e in ordered) {
      if (!e.isFinished) return e;
    }
    return null;
  }

  /// Every exercise is finished (done or skipped).
  bool get isAllFinished =>
      exercises.isNotEmpty && exercises.every((e) => e.isFinished);
}
