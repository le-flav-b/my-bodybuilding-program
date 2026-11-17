import 'dart:async';

import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/estimated_duration.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/progress/domain/last_time.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/progress/domain/records.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_providers.g.dart';

/// The workout in progress, if any.
@Riverpod(keepAlive: true)
Stream<WorkoutDetail?> activeWorkout(Ref ref) =>
    ref.watch(workoutRepositoryProvider).watchInProgress();

/// Any workout by id (summary, history).
@riverpod
Stream<WorkoutDetail?> workoutDetail(Ref ref, String workoutId) =>
    ref.watch(workoutRepositoryProvider).watchWorkout(workoutId);

/// The current time, refreshed every second while something watches it
/// (elapsed time, countdowns).
@riverpod
class Now extends _$Now {
  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => state = clock(),
    );
    ref.onDispose(timer.cancel);
    return clock();
  }
}

/// What was done last time on an exercise (most recent completed workout).
@riverpod
List<LoggedSet> lastTimeSets(Ref ref, String exerciseId) => LastTime.sets(
  ref.watch(loggedSetsByExerciseProvider)[exerciseId] ?? const [],
);

/// Estimated seconds left in a workout: what remains of its plan.
int estimatedSecondsLeft(WorkoutDetail detail) => EstimatedDuration.fromPlan([
  for (final e in detail.exercises)
    if (!e.isFinished)
      PlannedExercise(
        exerciseId: e.exerciseId,
        restSeconds: e.restSeconds,
        sets: [
          for (final s in e.sets)
            if (!s.isDone) s.target,
        ],
      ),
]);

/// The done sets of [detail] as logged sets (records while it runs).
List<LoggedSet> loggedSetsOf(
  WorkoutDetail detail,
  Map<String, Exercise> exercises,
) => [
  for (final (i, e) in detail.exercises.indexed)
    for (final s in e.doneSets)
      LoggedSet(
        setId: s.id,
        workoutId: detail.workout.id,
        workoutStartedAt: detail.workout.startedAt,
        exerciseId: e.exerciseId,
        measure:
            exercises[e.exerciseId]?.measure ??
            (s.seconds != null && s.reps == null ? Measure.time : Measure.reps),
        completedAt: s.completedAt!,
        sessionName: detail.workout.sessionName,
        order: i * 1000 + s.position,
        reps: s.reps,
        seconds: s.seconds,
        load: s.load,
        unitId: s.unitId,
      ),
];

/// The records beaten by the sets of [detail], in or out of progress.
List<RecordEvent> workoutRecordEvents(
  WorkoutDetail detail,
  Map<String, List<LoggedSet>> history,
  Map<String, Exercise> exercises,
) {
  final mine = loggedSetsOf(detail, exercises);
  final exerciseIds = {for (final s in mine) s.exerciseId};
  final sets = [
    for (final id in exerciseIds)
      ...?history[id]?.where((s) => s.workoutId != detail.workout.id),
    ...mine,
  ];
  return [
    for (final e in Records.events(sets))
      if (e.workoutId == detail.workout.id) e,
  ];
}

/// Ids of the sets of a workout that beat a record.
@riverpod
Set<String> workoutRecordSetIds(Ref ref, String workoutId) {
  final detail = ref.watch(workoutDetailProvider(workoutId)).value;
  if (detail == null) return const {};
  return {
    for (final e in workoutRecordEvents(
      detail,
      ref.watch(loggedSetsByExerciseProvider),
      ref.watch(exercisesByIdProvider),
    ))
      e.setId,
  };
}
