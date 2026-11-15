import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/tables/synced_table.dart';

/// Writes that keep the sync columns right on every synced table:
/// `created_at` / `updated_at` in UTC, `dirty` set, deletes soft.
mixin SyncedWrites on DatabaseAccessor<AppDatabase> {
  /// Inserts [row] (which carries its id) stamped with [now].
  Future<void> insertSynced<T extends Table, D>(
    TableInfo<T, D> table,
    UpdateCompanion<D> row,
    DateTime now,
  ) => into(table).insert(
    RawValuesInsertable<D>({
      ...row.toColumns(true),
      'created_at': Variable<DateTime>(now),
      'updated_at': Variable<DateTime>(now),
      'dirty': const Constant(true),
    }),
  );

  /// Applies [changes] to the row [id] and marks it updated at [now].
  Future<int> patch<T extends SyncedTable, D>(
    TableInfo<T, D> table,
    String id,
    UpdateCompanion<D> changes,
    DateTime now,
  ) => (update(table)..where((t) => t.id.equals(id))).write(
    RawValuesInsertable<D>({
      ...changes.toColumns(true),
      'updated_at': Variable<DateTime>(now),
      'dirty': const Constant(true),
    }),
  );

  /// Soft-deletes the rows matching [filter].
  Future<int> softDeleteWhere<T extends SyncedTable, D>(
    TableInfo<T, D> table,
    Expression<bool> Function(T) filter,
    DateTime now,
  ) => (update(table)..where((t) => filter(t) & t.deletedAt.isNull())).write(
    RawValuesInsertable<D>({
      'deleted_at': Variable<DateTime>(now),
      'updated_at': Variable<DateTime>(now),
      'dirty': const Constant(true),
    }),
  );

  /// Soft-deletes the row [id].
  Future<int> softDelete<T extends SyncedTable, D>(
    TableInfo<T, D> table,
    String id,
    DateTime now,
  ) => softDeleteWhere(table, (t) => t.id.equals(id), now);

  /// Emits once now and again whenever one of [tables] changes.
  Stream<void> changes(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
  ) => customSelect('SELECT 1', readsFrom: tables.toSet()).watch();

  /// Reloads [load] whenever one of [tables] changes.
  Stream<R> watching<R>(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<R> Function() load,
  ) => changes(tables).asyncMap((_) => load());
}
