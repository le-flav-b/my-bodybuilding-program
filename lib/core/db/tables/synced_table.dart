import 'package:drift/drift.dart';

/// Columns every synced table has (Notion > Data & Sync > Identity & deletion).
///
/// Repositories set them on every write: `id` is a UUID v7, timestamps are
/// UTC, deletes are soft (`deleted_at`), and `dirty` marks rows the cloud
/// mirror has not seen yet (used from v1.1).
mixin SyncedTable on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
