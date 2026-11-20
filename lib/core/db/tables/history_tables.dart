import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/tables/catalogue_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/personal_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/synced_table.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';

/// History layer: what was planned (a copy made at start) and what was done.
@DataClassName('WorkoutRow')
@TableIndex(name: 'workouts_status_started', columns: {#status, #startedAt})
class Workouts extends Table with SyncedTable {
  /// The session it was started from; null for an empty workout. Not a
  /// foreign key on purpose: history survives the deletion of the session.
  TextColumn get sessionId => text().nullable()();
  TextColumn get sessionName => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get status => textEnum<WorkoutStatus>()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Set while the workout is paused.
  DateTimeColumn get pausedAt => dateTime().nullable()();

  /// Total time spent paused so far; excluded from the duration.
  IntColumn get pausedSeconds => integer().withDefault(const Constant(0))();

  /// Last user action; the 12 h auto-finish counts from here.
  DateTimeColumn get lastActivityAt => dateTime()();

  /// The exercise shown in the player (restored on resume).
  TextColumn get currentExerciseId => text().nullable()();

  /// Running rest timer, so it survives an app kill.
  DateTimeColumn get restEndsAt => dateTime().nullable()();
  IntColumn get restTotalSeconds => integer().nullable()();

  /// JSON copy of the session's plan at start, used only to list what
  /// changed when asking "Update the program?".
  TextColumn get planSnapshot => text().nullable()();
}

@DataClassName('WorkoutExerciseRow')
@TableIndex(name: 'workout_exercises_workout', columns: {#workoutId})
@TableIndex(name: 'workout_exercises_exercise', columns: {#exerciseId})
class WorkoutExercises extends Table with SyncedTable {
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get restSeconds => integer().named('rest_s')();
  TextColumn get status => textEnum<WorkoutExerciseStatus>()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// The planned exercise this one replaced (swap), if any.
  TextColumn get swappedFrom => text().nullable()();

  /// False for exercises added during the workout.
  BoolColumn get fromPlan => boolean().withDefault(const Constant(true))();
}

@DataClassName('WorkoutSetRow')
@TableIndex(
  name: 'workout_sets_workout_exercise',
  columns: {#workoutExerciseId},
)
class WorkoutSets extends Table with SyncedTable {
  TextColumn get workoutExerciseId =>
      text().references(WorkoutExercises, #id)();
  IntColumn get position => integer()();

  // Planned snapshot.
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetSeconds => integer().nullable()();
  BoolColumn get isMax => boolean().withDefault(const Constant(false))();
  RealColumn get plannedLoad => real().nullable()();
  TextColumn get plannedUnitId =>
      text().nullable().references(LoadUnits, #id)();

  // Done values.
  IntColumn get reps => integer().nullable()();
  IntColumn get seconds => integer().nullable()();
  RealColumn get load => real().nullable()();
  TextColumn get unitId => text().nullable().references(LoadUnits, #id)();

  /// A set is done when this is set.
  DateTimeColumn get completedAt => dateTime().nullable()();
}
