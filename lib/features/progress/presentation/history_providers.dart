import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/features/progress/data/history_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/progress/domain/stats.dart';
import 'package:my_bodybuilding_program/features/progress/domain/streak.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'history_providers.g.dart';

/// Every completed set of the completed workouts, oldest first: the input
/// of all derived figures (records, charts, last time, stats).
@Riverpod(keepAlive: true)
Stream<List<LoggedSet>> loggedSets(Ref ref) =>
    ref.watch(historyRepositoryProvider).watchLoggedSets();

/// Logged sets grouped by exercise id.
@Riverpod(keepAlive: true)
Map<String, List<LoggedSet>> loggedSetsByExercise(Ref ref) {
  final result = <String, List<LoggedSet>>{};
  for (final set
      in ref.watch(loggedSetsProvider).value ?? const <LoggedSet>[]) {
    result.putIfAbsent(set.exerciseId, () => []).add(set);
  }
  return result;
}

/// Completed workouts, newest first.
@Riverpod(keepAlive: true)
Stream<List<WorkoutSummary>> workoutSummaries(Ref ref) =>
    ref.watch(historyRepositoryProvider).watchWorkoutSummaries();

/// The weekly streak, from the completed workouts and the weekly target.
@riverpod
Streak streak(Ref ref) {
  final dates = [
    for (final w
        in ref.watch(workoutSummariesProvider).value ??
            const <WorkoutSummary>[])
      w.startedAt.toLocal(),
  ];
  return StreakRule.compute(
    dates,
    weeklyTarget: ref.watch(currentSettingsProvider).weeklyTarget,
    today: ref.watch(clockProvider)().toLocal(),
  );
}

/// An exercise I have done, for the Progress › Exercises list.
typedef DoneExercise = ({String exerciseId, DateTime lastDone, int workouts});

/// Exercises with logged sets, most recently done first.
@riverpod
List<DoneExercise> doneExercises(Ref ref) {
  final result = <DoneExercise>[];
  ref.watch(loggedSetsByExerciseProvider).forEach((id, sets) {
    if (sets.isEmpty) return;
    result.add((
      exerciseId: id,
      lastDone: sets.last.workoutStartedAt,
      workouts: {for (final s in sets) s.workoutId}.length,
    ));
  });
  return result..sort((a, b) => b.lastDone.compareTo(a.lastDone));
}

/// Totals and this month vs last month.
@riverpod
Stats stats(Ref ref) => StatsRule.compute(
  ref.watch(workoutSummariesProvider).value ?? const <WorkoutSummary>[],
  ref.watch(clockProvider)().toLocal(),
);
