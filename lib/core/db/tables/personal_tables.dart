import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/tables/catalogue_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/synced_table.dart';

/// Personal layer: the user's own data about exercises, units, body, settings.
@DataClassName('ExerciseNoteRow')
class ExerciseNotes extends Table with SyncedTable {
  TextColumn get exerciseId => text().references(Exercises, #id).unique()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

@DataClassName('LoadUnitRow')
class LoadUnits extends Table with SyncedTable {
  TextColumn get name => text()();
  RealColumn get step => real()();
  IntColumn get decimals => integer()();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

@DataClassName('BodyWeightRow')
@TableIndex(name: 'body_weights_measured_at', columns: {#measuredAt})
class BodyWeights extends Table with SyncedTable {
  DateTimeColumn get measuredAt => dateTime()();
  RealColumn get weightKg => real()();
  TextColumn get note => text().nullable()();
}

/// Key/value settings. The key is the row id (and the cloud document id).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Personal records (PRs): attempts made on purpose, kept apart from the
/// training sets (v1.0.1, schema v2). What is filled depends on the
/// exercise's measure; the repository checks it.
@DataClassName('PersonalRecordRow')
@TableIndex(name: 'personal_records_exercise', columns: {#exerciseId})
class PersonalRecords extends Table with SyncedTable {
  TextColumn get exerciseId => text().references(Exercises, #id)();
  DateTimeColumn get achievedAt => dateTime()();
  RealColumn get load => real().nullable()();
  TextColumn get unitId => text().nullable().references(LoadUnits, #id)();
  IntColumn get reps => integer().nullable()();
  IntColumn get seconds => integer().nullable()();
  TextColumn get note => text().nullable()();
}
