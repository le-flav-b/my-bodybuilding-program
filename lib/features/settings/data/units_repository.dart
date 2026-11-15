import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'units_repository.g.dart';

/// The user-managed list of load units. `kg` is built in and locked.
class UnitsRepository {
  new(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  /// Every unit, archived ones included; `kg` first.
  Stream<List<LoadUnit>> watchUnits() =>
      _db.personalDao.watching([_db.loadUnits], getUnits);

  Future<List<LoadUnit>> getUnits() async => [
    for (final row in await _db.personalDao.allUnits()) _unit(row),
  ];

  Future<String> createUnit(LoadUnitDraft draft) async {
    _check(draft);
    final id = _newId();
    await _db.personalDao.insertSynced(
      _db.loadUnits,
      LoadUnitsCompanion(
        id: Value(id),
        name: Value(draft.name.trim()),
        step: Value(draft.step),
        decimals: Value(draft.decimals),
      ),
      _clock(),
    );
    return id;
  }

  Future<void> updateUnit(String id, LoadUnitDraft draft) async {
    _check(draft);
    await _requireCustom(id);
    await _db.personalDao.patch(
      _db.loadUnits,
      id,
      LoadUnitsCompanion(
        name: Value(draft.name.trim()),
        step: Value(draft.step),
        decimals: Value(draft.decimals),
      ),
      _clock(),
    );
  }

  /// Hides a unit from the pickers; sets logged in it keep it.
  Future<void> archiveUnit(String id) async {
    await _requireCustom(id);
    await _db.personalDao.patch(
      _db.loadUnits,
      id,
      LoadUnitsCompanion(archivedAt: Value(_clock())),
      _clock(),
    );
  }

  Future<void> restoreUnit(String id) => _db.personalDao.patch(
    _db.loadUnits,
    id,
    const LoadUnitsCompanion(archivedAt: Value(null)),
    _clock(),
  );

  /// Deletes a unit that was never used. One in use can only be archived.
  Future<void> deleteUnit(String id) async {
    await _requireCustom(id);
    if (((await usageByUnit())[id] ?? 0) > 0) {
      throw const InUseException('This unit is in use; archive it instead.');
    }
    await _db.personalDao.softDelete(_db.loadUnits, id, _clock());
  }

  /// Number of exercises each unit is used in (planned or logged).
  Future<Map<String, int>> usageByUnit() async {
    final planned = await _db.planDao.exercisesByPlannedUnit();
    final logged = await _db.historyDao.exercisesByLoggedUnit();
    return {
      for (final unitId in {...planned.keys, ...logged.keys})
        unitId: {...?planned[unitId], ...?logged[unitId]}.length,
    };
  }

  Stream<Map<String, int>> watchUsageByUnit() => _db.personalDao.watching([
    _db.plannedSets,
    _db.sessionExercises,
    _db.workoutSets,
    _db.workoutExercises,
    _db.workouts,
  ], usageByUnit);

  void _check(LoadUnitDraft draft) {
    final error = draft.error;
    if (error != null) throw ArgumentError(error);
  }

  Future<void> _requireCustom(String id) async {
    final row = await _db.personalDao.unitById(id);
    if (row == null || row.isBuiltin) {
      throw const InUseException('The built-in unit cannot be changed.');
    }
  }

  LoadUnit _unit(LoadUnitRow row) => LoadUnit(
    id: row.id,
    name: row.name,
    step: row.step,
    decimals: row.decimals,
    isBuiltin: row.isBuiltin,
    archivedAt: row.archivedAt,
  );
}

@Riverpod(keepAlive: true)
UnitsRepository unitsRepository(Ref ref) => UnitsRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
  ref.watch(idGeneratorProvider),
);
