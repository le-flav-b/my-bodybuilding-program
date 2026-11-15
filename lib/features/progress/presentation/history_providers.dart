import 'package:my_bodybuilding_program/features/progress/data/history_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/progress/domain/stats.dart';
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
