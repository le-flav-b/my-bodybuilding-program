import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/profile/data/body_weight_repository.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/progress/data/history_repository.dart';
import 'package:my_bodybuilding_program/features/progress/data/personal_records_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/data/units_repository.dart';

import 'migrations/generated/schema.dart';
import 'migrations/generated/schema_v1.dart' as v1;

/// v1.0.0 → v1.0.1: schema 1 → 2 adds `personal_records`. The phone already
/// holds real v1 data: every row must survive, unchanged.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every schema migrates to the latest and matches its dump', () async {
    for (final from in GeneratedHelper.versions) {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, db.schemaVersion);
      await db.close();
    }
  });

  test('v1 → v2 keeps every v1 row and adds personal records', () async {
    const t = '2026-11-10T18:00:00.000Z';
    const kg = FixedIds.kgUnit;
    final schema = await verifier.schemaAt(1);

    // A v1.0.0 database with a bit of everything.
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.batch((b) {
      b
        ..insert(
          old.loadUnits,
          v1.LoadUnitsCompanion.insert(
            id: kg,
            createdAt: t,
            updatedAt: t,
            name: 'kg',
            step: 0.5,
            decimals: 1,
            isBuiltin: const Value(1),
          ),
        )
        ..insert(
          old.loadUnits,
          v1.LoadUnitsCompanion.insert(
            id: 'unit-level',
            createdAt: t,
            updatedAt: t,
            name: 'level',
            step: 1,
            decimals: 0,
          ),
        )
        ..insert(
          old.muscles,
          v1.MusclesCompanion.insert(
            id: 'm-chest',
            createdAt: t,
            updatedAt: t,
            name: 'Chest',
          ),
        )
        ..insert(
          old.exercises,
          v1.ExercisesCompanion.insert(
            id: 'ex-bench',
            createdAt: t,
            updatedAt: t,
            name: 'Bench press',
            measure: 'reps',
          ),
        )
        ..insert(
          old.exerciseMuscles,
          v1.ExerciseMusclesCompanion.insert(
            id: 'em-1',
            createdAt: t,
            updatedAt: t,
            exerciseId: 'ex-bench',
            muscleId: 'm-chest',
            role: 'primary',
          ),
        )
        ..insert(
          old.exerciseNotes,
          v1.ExerciseNotesCompanion.insert(
            id: 'note-1',
            createdAt: t,
            updatedAt: t,
            exerciseId: 'ex-bench',
            notes: const Value('seat 4'),
          ),
        )
        ..insert(
          old.bodyWeights,
          v1.BodyWeightsCompanion.insert(
            id: 'bw-1',
            createdAt: t,
            updatedAt: t,
            measuredAt: t,
            weightKg: 78.4,
            note: const Value('morning'),
          ),
        )
        ..insert(
          old.settings,
          v1.SettingsCompanion.insert(
            key: 'weekly_target',
            value: '4',
            createdAt: t,
            updatedAt: t,
          ),
        )
        ..insert(
          old.programs,
          v1.ProgramsCompanion.insert(
            id: FixedIds.program,
            createdAt: t,
            updatedAt: t,
            name: 'My program',
          ),
        )
        ..insert(
          old.sessions,
          v1.SessionsCompanion.insert(
            id: 'session-push',
            createdAt: t,
            updatedAt: t,
            programId: FixedIds.program,
            name: 'Push A',
            position: 0,
          ),
        )
        ..insert(
          old.sessionExercises,
          v1.SessionExercisesCompanion.insert(
            id: 'se-1',
            createdAt: t,
            updatedAt: t,
            sessionId: 'session-push',
            exerciseId: 'ex-bench',
            position: 0,
            restS: 120,
          ),
        )
        ..insert(
          old.plannedSets,
          v1.PlannedSetsCompanion.insert(
            id: 'ps-1',
            createdAt: t,
            updatedAt: t,
            sessionExerciseId: 'se-1',
            position: 0,
            targetReps: const Value(10),
            load: const Value(40),
            unitId: const Value(kg),
          ),
        )
        ..insert(
          old.workouts,
          v1.WorkoutsCompanion.insert(
            id: 'w-1',
            createdAt: t,
            updatedAt: t,
            sessionId: const Value('session-push'),
            sessionName: 'Push A',
            startedAt: t,
            endedAt: const Value('2026-11-10T18:50:00.000Z'),
            status: 'completed',
            lastActivityAt: t,
          ),
        )
        ..insert(
          old.workoutExercises,
          v1.WorkoutExercisesCompanion.insert(
            id: 'we-1',
            createdAt: t,
            updatedAt: t,
            workoutId: 'w-1',
            exerciseId: 'ex-bench',
            position: 0,
            restS: 120,
            status: 'done',
          ),
        )
        ..insert(
          old.workoutSets,
          v1.WorkoutSetsCompanion.insert(
            id: 'set-1',
            createdAt: t,
            updatedAt: t,
            workoutExerciseId: 'we-1',
            position: 0,
            targetReps: const Value(10),
            plannedLoad: const Value(40),
            plannedUnitId: const Value(kg),
            reps: const Value(10),
            load: const Value(42.5),
            unitId: const Value(kg),
            completedAt: const Value('2026-11-10T18:05:00.000Z'),
          ),
        );
    });
    final before = await _counts(old);
    await old.close();

    // Opening it with the app runs the migration.
    final db = AppDatabase(
      schema.newConnection(),
      clock: () => DateTime.utc(2026, 11, 20),
    );
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);
    final after = await _counts(db);
    expect(after, before);
    expect(after.values.every((n) => n > 0), isTrue);

    // The data reads back through the repositories, unchanged.
    DateTime clock() => DateTime.utc(2026, 11, 20);
    final catalogue = CatalogueRepository(db, clock, newId);
    final bench = (await catalogue.getExercise('ex-bench'))!;
    expect(bench.name, 'Bench press');
    expect((await catalogue.getNotes())['ex-bench'], 'seat 4');
    final weights = await BodyWeightRepository(db, clock, newId).getEntries();
    expect(weights.single.weightKg, 78.4);
    expect(weights.single.note, 'morning');
    expect((await SettingsRepository(db, clock).getSettings()).weeklyTarget, 4);
    final units = await UnitsRepository(db, clock, newId).getUnits();
    expect(units.map((u) => u.name), ['kg', 'level']);
    final plan = await ProgramRepository(
      db,
      clock,
      newId,
    ).getSessionPlan('session-push');
    expect(plan!.toPlan().single.sets.single.load, 40);
    final history = HistoryRepository(db);
    final sets = await history.getLoggedSets();
    expect(sets.single.load, 42.5);
    expect(sets.single.reps, 10);
    expect((await history.getWorkoutSummaries()).single.sessionName, 'Push A');

    // The new table works on the migrated database.
    final records = PersonalRecordsRepository(db, clock, newId);
    expect(await records.getRecords(), isEmpty);
    await records.addRecord(
      'ex-bench',
      PersonalRecordDraft(
        achievedAt: DateTime.utc(2026, 11, 19),
        load: 100,
        unitId: kg,
      ),
    );
    expect((await records.getRecords()).single.load, 100);
    expect(await catalogue.exerciseHasHistory('ex-bench'), isTrue);
  });
}

/// Rows per v1 table, read with plain SQL (works on both versions).
Future<Map<String, int>> _counts(GeneratedDatabase db) async {
  const tables = [
    'muscles',
    'exercises',
    'exercise_muscles',
    'exercise_notes',
    'load_units',
    'body_weights',
    'settings',
    'programs',
    'sessions',
    'session_exercises',
    'planned_sets',
    'workouts',
    'workout_exercises',
    'workout_sets',
  ];
  return {
    for (final table in tables)
      table:
          (await db
                  .customSelect('SELECT COUNT(*) AS n FROM $table')
                  .getSingle())
              .read<int>('n'),
  };
}
