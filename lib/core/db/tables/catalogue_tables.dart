import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/tables/synced_table.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';

/// Catalogue layer: describes movements, holds none of the user's numbers.
@DataClassName('MuscleRow')
class Muscles extends Table with SyncedTable {
  TextColumn get name => text()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  TextColumn get seedKey => text().nullable().unique()();
  BoolColumn get userModified => boolean().withDefault(const Constant(false))();

  /// Display order (seed order first, the user's own muscles after).
  IntColumn get position => integer().withDefault(const Constant(0))();
}

@DataClassName('ExerciseRow')
class Exercises extends Table with SyncedTable {
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// `seed:<file>` for a bundled illustration, `user:<file>` for a photo in
  /// private app storage, null for none (placeholder by primary muscle).
  TextColumn get image => text().nullable()();
  TextColumn get measure => textEnum<Measure>()();
  TextColumn get seedKey => text().nullable().unique()();
  BoolColumn get userModified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

@DataClassName('ExerciseMuscleRow')
@TableIndex(name: 'exercise_muscles_exercise', columns: {#exerciseId})
class ExerciseMuscles extends Table with SyncedTable {
  TextColumn get exerciseId => text().references(Exercises, #id)();
  TextColumn get muscleId => text().references(Muscles, #id)();
  TextColumn get role => textEnum<MuscleRole>()();

  /// Order within the role; the first primary muscle picks the placeholder.
  IntColumn get position => integer().withDefault(const Constant(0))();
}
