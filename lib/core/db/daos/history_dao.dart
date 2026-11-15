import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/daos/synced_writes.dart';
import 'package:my_bodybuilding_program/core/db/tables/catalogue_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/history_tables.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';

part 'history_dao.g.dart';

/// A completed set joined with its exercise and workout.
typedef LoggedSetRow = ({
  WorkoutSetRow set,
  WorkoutExerciseRow exercise,
  WorkoutRow workout,
  ExerciseRow catalogue,
});

/// Queries of the history layer.
@DriftAccessor(tables: [Workouts, WorkoutExercises, WorkoutSets, Exercises])
class HistoryDao extends DatabaseAccessor<AppDatabase>
    with _$HistoryDaoMixin, SyncedWrites {
  new(super.attachedDatabase);

  Future<WorkoutRow?> workoutById(String id) => (select(
    workouts,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// The workout in progress, if any (the most recent one if several).
  Future<WorkoutRow?> inProgressWorkout() =>
      (select(workouts)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.status.equalsValue(WorkoutStatus.inProgress),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Completed workouts, newest first.
  Future<List<WorkoutRow>> completedWorkouts() =>
      (select(workouts)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.status.equalsValue(WorkoutStatus.completed),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// Exercises of the given workouts, in order.
  Future<List<WorkoutExerciseRow>> exercisesOf(Iterable<String> workoutIds) =>
      (select(workoutExercises)
            ..where((t) => t.deletedAt.isNull() & t.workoutId.isIn(workoutIds))
            ..orderBy([
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.rowId),
            ]))
          .get();

  Future<WorkoutExerciseRow?> workoutExerciseById(String id) => (select(
    workoutExercises,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// Sets of the given workout exercises, in order.
  Future<List<WorkoutSetRow>> setsOf(Iterable<String> workoutExerciseIds) =>
      (select(workoutSets)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.workoutExerciseId.isIn(workoutExerciseIds),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.rowId),
            ]))
          .get();

  Future<WorkoutSetRow?> setById(String id) => (select(
    workoutSets,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// Every completed set of the completed workouts, optionally of one
  /// exercise or one workout. [includeWorkoutId] also takes the sets of
  /// that workout whatever its status (the one in progress).
  Future<List<LoggedSetRow>> loggedSets({
    String? exerciseId,
    String? includeWorkoutId,
  }) async {
    final statusFilter = workouts.status.equalsValue(WorkoutStatus.completed);
    final query =
        select(workoutSets).join([
          innerJoin(
            workoutExercises,
            workoutExercises.id.equalsExp(workoutSets.workoutExerciseId),
          ),
          innerJoin(
            workouts,
            workouts.id.equalsExp(workoutExercises.workoutId),
          ),
          innerJoin(
            exercises,
            exercises.id.equalsExp(workoutExercises.exerciseId),
          ),
        ])..where(
          workoutSets.deletedAt.isNull() &
              workoutSets.completedAt.isNotNull() &
              workoutExercises.deletedAt.isNull() &
              workouts.deletedAt.isNull() &
              (includeWorkoutId == null
                  ? statusFilter
                  : statusFilter | workouts.id.equals(includeWorkoutId)) &
              (exerciseId == null
                  ? const Constant(true)
                  : workoutExercises.exerciseId.equals(exerciseId)),
        );
    return [
      for (final row in await query.get())
        (
          set: row.readTable(workoutSets),
          exercise: row.readTable(workoutExercises),
          workout: row.readTable(workouts),
          catalogue: row.readTable(exercises),
        ),
    ];
  }

  /// Whether [exerciseId] appears in any workout that was not discarded.
  Future<bool> exerciseHasHistory(String exerciseId) async {
    final query =
        select(workoutExercises).join([
            innerJoin(
              workouts,
              workouts.id.equalsExp(workoutExercises.workoutId),
            ),
          ])
          ..where(
            workoutExercises.exerciseId.equals(exerciseId) &
                workoutExercises.deletedAt.isNull() &
                workouts.deletedAt.isNull() &
                workouts.status.isNotValue(WorkoutStatus.discarded.name),
          )
          ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Exercises in which each unit was logged or planned in a workout.
  Future<Map<String, Set<String>>> exercisesByLoggedUnit() async {
    final query =
        select(workoutSets).join([
          innerJoin(
            workoutExercises,
            workoutExercises.id.equalsExp(workoutSets.workoutExerciseId),
          ),
          innerJoin(
            workouts,
            workouts.id.equalsExp(workoutExercises.workoutId),
          ),
        ])..where(
          workoutSets.deletedAt.isNull() &
              workoutExercises.deletedAt.isNull() &
              workouts.deletedAt.isNull() &
              workouts.status.isNotValue(WorkoutStatus.discarded.name),
        );
    final result = <String, Set<String>>{};
    for (final row in await query.get()) {
      final set = row.readTable(workoutSets);
      final exerciseId = row.readTable(workoutExercises).exerciseId;
      final unitId = set.completedAt != null ? set.unitId : set.plannedUnitId;
      final hasLoad = set.completedAt != null
          ? set.load != null
          : set.plannedLoad != null;
      if (unitId != null && hasLoad) {
        result.putIfAbsent(unitId, () => {}).add(exerciseId);
      }
    }
    return result;
  }
}
