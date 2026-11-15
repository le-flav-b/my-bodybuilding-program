import 'dart:async';

import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/features/program/domain/estimated_duration.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/progress/domain/last_time.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
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
