import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/daos/synced_writes.dart';
import 'package:my_bodybuilding_program/core/db/tables/personal_tables.dart';

part 'personal_dao.g.dart';

/// Queries of the personal layer: load units, bodyweight, settings and
/// personal records.
@DriftAccessor(tables: [LoadUnits, BodyWeights, Settings, PersonalRecords])
class PersonalDao extends DatabaseAccessor<AppDatabase>
    with _$PersonalDaoMixin, SyncedWrites {
  new(super.attachedDatabase);

  /// Built-in first, then by creation.
  Future<List<LoadUnitRow>> allUnits() =>
      (select(loadUnits)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.isBuiltin),
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.rowId),
            ]))
          .get();

  Future<LoadUnitRow?> unitById(String id) =>
      (select(loadUnits)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Newest first.
  Future<List<BodyWeightRow>> allBodyWeights() =>
      (select(bodyWeights)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.measuredAt)]))
          .get();

  /// Personal records, newest first; only [exerciseId]'s when given.
  Future<List<PersonalRecordRow>> allPersonalRecords({String? exerciseId}) =>
      (select(personalRecords)
            ..where(
              (t) => exerciseId == null
                  ? t.deletedAt.isNull()
                  : t.deletedAt.isNull() & t.exerciseId.equals(exerciseId),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.achievedAt),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .get();

  Future<PersonalRecordRow?> personalRecordById(String id) => (select(
    personalRecords,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  Future<bool> exerciseHasPersonalRecords(String exerciseId) async {
    final row =
        await (select(personalRecords)
              ..where(
                (t) => t.exerciseId.equals(exerciseId) & t.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Exercise ids having a PR in each unit.
  Future<Map<String, Set<String>>> exercisesByPersonalRecordUnit() async {
    final rows = await (select(
      personalRecords,
    )..where((t) => t.deletedAt.isNull() & t.unitId.isNotNull())).get();
    final result = <String, Set<String>>{};
    for (final r in rows) {
      result.putIfAbsent(r.unitId!, () => {}).add(r.exerciseId);
    }
    return result;
  }

  Future<Map<String, String>> allSettings() async {
    final rows = await (select(
      settings,
    )..where((t) => t.deletedAt.isNull())).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<String?> setting(String key) async {
    final row =
        await (select(settings)
              ..where((t) => t.key.equals(key) & t.deletedAt.isNull()))
            .getSingleOrNull();
    return row?.value;
  }

  Future<void> putSetting(String key, String value, DateTime now) =>
      into(settings).insert(
        SettingsCompanion.insert(
          key: key,
          value: value,
          createdAt: now,
          updatedAt: now,
        ),
        onConflict: DoUpdate(
          (old) => SettingsCompanion(
            value: Value(value),
            updatedAt: Value(now),
            deletedAt: const Value(null),
            dirty: const Value(true),
          ),
        ),
      );
}
