import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:my_bodybuilding_program/core/db/daos/catalogue_dao.dart';
import 'package:my_bodybuilding_program/core/db/daos/history_dao.dart';
import 'package:my_bodybuilding_program/core/db/daos/personal_dao.dart';
import 'package:my_bodybuilding_program/core/db/daos/plan_dao.dart';
import 'package:my_bodybuilding_program/core/db/tables/catalogue_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/history_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/personal_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/plan_tables.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';

part 'app_database.g.dart';

/// The local database: the source of truth of the app (offline-first).
@DriftDatabase(
  tables: [
    Muscles,
    Exercises,
    ExerciseMuscles,
    ExerciseNotes,
    LoadUnits,
    BodyWeights,
    Settings,
    Programs,
    Sessions,
    SessionExercises,
    PlannedSets,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
  ],
  daos: [CatalogueDao, PersonalDao, PlanDao, HistoryDao],
)
class AppDatabase extends _$AppDatabase {
  new(super.e, {this._clock = utcNow});

  /// Opens the on-device database file.
  factory onDevice() => AppDatabase(driftDatabase(name: databaseName));

  static const String databaseName = 'my_bodybuilding_program';

  /// Name and settings of the built-in unit.
  static const String kgName = 'kg';
  static const double kgStep = 0.5;
  static const int kgDecimals = 1;
  static const String programName = 'My program';

  final Clock _clock;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureBuiltIns();
    },
  );

  /// The rows every installation has: the `kg` unit and the single program.
  Future<void> _ensureBuiltIns() async {
    final now = _clock();
    await into(loadUnits).insert(
      LoadUnitsCompanion.insert(
        id: FixedIds.kgUnit,
        createdAt: now,
        updatedAt: now,
        name: kgName,
        step: kgStep,
        decimals: kgDecimals,
        isBuiltin: const Value(true),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await into(programs).insert(
      ProgramsCompanion.insert(
        id: FixedIds.program,
        createdAt: now,
        updatedAt: now,
        name: programName,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
