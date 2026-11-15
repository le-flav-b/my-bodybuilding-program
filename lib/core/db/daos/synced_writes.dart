import 'dart:async';

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

  /// Loads [load] once and again whenever one of [tables] changes.
  ///
  /// Built on the database's table-update notifications rather than on a
  /// watched query: drift shares watched queries that have the same SQL, so
  /// a generic "changed" query would only follow the tables of its first
  /// listener. Reloads never overlap; a change during a reload triggers one
  /// more reload when it ends.
  Stream<R> watching<R>(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<R> Function() load,
  ) {
    late final StreamController<R> controller;
    StreamSubscription<void>? updates;
    var loading = false;
    var stale = false;

    Future<void> reload() async {
      if (loading) {
        stale = true;
        return;
      }
      loading = true;
      do {
        stale = false;
        try {
          final value = await load();
          if (!controller.isClosed) controller.add(value);
        } on Object catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      } while (stale && !controller.isClosed);
      loading = false;
    }

    controller = StreamController<R>(
      onListen: () {
        updates = attachedDatabase
            .tableUpdates(TableUpdateQuery.onAllTables(tables))
            .listen((_) => unawaited(reload()));
        unawaited(reload());
      },
      onCancel: () async {
        await updates?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }
}
