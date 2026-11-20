import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/daos/history_dao.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/features/progress/domain/bests.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/progress/domain/stats.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'history_repository.g.dart';

/// Read side of the history: the raw material of every derived figure
/// (records, charts, last time, streak, stats). Nothing derived is stored.
class HistoryRepository {
  new(this._db);

  final AppDatabase _db;

  /// Every completed set of the completed workouts, oldest first.
  Stream<List<LoggedSet>> watchLoggedSets({String? exerciseId}) =>
      _db.historyDao.watching([
        _db.workouts,
        _db.workoutExercises,
        _db.workoutSets,
        _db.exercises,
      ], () => getLoggedSets(exerciseId: exerciseId));

  /// [includeWorkoutId] adds the sets of that workout even if it is still
  /// in progress (records during a workout).
  Future<List<LoggedSet>> getLoggedSets({
    String? exerciseId,
    String? includeWorkoutId,
  }) async {
    final rows = await _db.historyDao.loggedSets(
      exerciseId: exerciseId,
      includeWorkoutId: includeWorkoutId,
    );
    return [for (final row in rows) _loggedSet(row)]
      ..sort(LoggedSet.chronological);
  }

  /// Completed workouts, newest first, with their counts.
  Stream<List<WorkoutSummary>> watchWorkoutSummaries() =>
      _db.historyDao.watching([
        _db.workouts,
        _db.workoutExercises,
        _db.workoutSets,
        _db.exercises,
      ], getWorkoutSummaries);

  Future<List<WorkoutSummary>> getWorkoutSummaries() async {
    final sets = await getLoggedSets();
    final setCount = <String, int>{};
    final exercises = <String, Set<String>>{};
    for (final set in sets) {
      setCount.update(set.workoutId, (c) => c + 1, ifAbsent: () => 1);
      exercises.putIfAbsent(set.workoutId, () => {}).add(set.exerciseId);
    }
    final records = <String, Set<Object>>{};
    for (final event in Bests.events(sets)) {
      records.putIfAbsent(event.workoutId, () => {}).add((
        event.exerciseId,
        event.series,
      ));
    }
    return [
      for (final row in await _db.historyDao.completedWorkouts())
        WorkoutSummary(
          id: row.id,
          sessionId: row.sessionId,
          sessionName: row.sessionName,
          startedAt: row.startedAt,
          endedAt: row.endedAt,
          durationSeconds: _duration(row),
          setCount: setCount[row.id] ?? 0,
          exerciseCount: exercises[row.id]?.length ?? 0,
          recordCount: records[row.id]?.length ?? 0,
        ),
    ];
  }

  int _duration(WorkoutRow row) {
    final end = row.endedAt ?? row.startedAt;
    final seconds = end.difference(row.startedAt).inSeconds - row.pausedSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  LoggedSet _loggedSet(LoggedSetRow row) => LoggedSet(
    setId: row.set.id,
    workoutId: row.workout.id,
    workoutStartedAt: row.workout.startedAt,
    sessionName: row.workout.sessionName,
    exerciseId: row.exercise.exerciseId,
    measure: row.catalogue.measure,
    completedAt: row.set.completedAt!,
    order: row.exercise.position * 1000 + row.set.position,
    reps: row.set.reps,
    seconds: row.set.seconds,
    load: row.set.load,
    unitId: row.set.unitId,
  );
}

@Riverpod(keepAlive: true)
HistoryRepository historyRepository(Ref ref) =>
    HistoryRepository(ref.watch(appDatabaseProvider));
