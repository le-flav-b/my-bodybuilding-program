import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/tables/catalogue_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/personal_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/synced_table.dart';

/// Plan layer: the single program, its loop of sessions and their targets.
@DataClassName('ProgramRow')
class Programs extends Table with SyncedTable {
  TextColumn get name => text()();

  /// The "next session" pointer (null when the program is empty).
  TextColumn get nextSessionId => text().nullable()();
}

@DataClassName('SessionRow')
@TableIndex(name: 'sessions_program', columns: {#programId})
class Sessions extends Table with SyncedTable {
  TextColumn get programId => text().references(Programs, #id)();
  TextColumn get name => text()();
  IntColumn get position => integer()();
}

@DataClassName('SessionExerciseRow')
@TableIndex(name: 'session_exercises_session', columns: {#sessionId})
class SessionExercises extends Table with SyncedTable {
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get restSeconds => integer().named('rest_s')();
}

@DataClassName('PlannedSetRow')
@TableIndex(
  name: 'planned_sets_session_exercise',
  columns: {#sessionExerciseId},
)
class PlannedSets extends Table with SyncedTable {
  TextColumn get sessionExerciseId =>
      text().references(SessionExercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetSeconds => integer().nullable()();
  BoolColumn get isMax => boolean().withDefault(const Constant(false))();

  /// Empty = bodyweight, negative = assisted.
  RealColumn get load => real().nullable()();
  TextColumn get unitId => text().nullable().references(LoadUnits, #id)();
}
