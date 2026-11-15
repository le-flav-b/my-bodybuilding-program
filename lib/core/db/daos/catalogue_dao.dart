import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/daos/synced_writes.dart';
import 'package:my_bodybuilding_program/core/db/tables/catalogue_tables.dart';
import 'package:my_bodybuilding_program/core/db/tables/personal_tables.dart';

part 'catalogue_dao.g.dart';

/// Queries of the catalogue layer (and the personal exercise notes).
@DriftAccessor(tables: [Muscles, Exercises, ExerciseMuscles, ExerciseNotes])
class CatalogueDao extends DatabaseAccessor<AppDatabase>
    with _$CatalogueDaoMixin, SyncedWrites {
  new(super.attachedDatabase);

  Future<List<MuscleRow>> allMuscles() =>
      (select(muscles)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .get();

  /// Seeded muscles, deleted ones included (for the seed merge).
  Future<List<MuscleRow>> seededMuscles() =>
      (select(muscles)..where((t) => t.seedKey.isNotNull())).get();

  Future<int> nextMusclePosition() async {
    final max = muscles.position.max();
    final row = await (selectOnly(muscles)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<List<ExerciseRow>> allExercises() =>
      (select(exercises)..where((t) => t.deletedAt.isNull())).get();

  Future<ExerciseRow?> exerciseById(String id) => (select(
    exercises,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// Seeded exercises, deleted ones included (for the seed merge).
  Future<List<ExerciseRow>> seededExercises() =>
      (select(exercises)..where((t) => t.seedKey.isNotNull())).get();

  /// Muscle links, of one exercise or of all.
  Future<List<ExerciseMuscleRow>> muscleLinks({String? exerciseId}) =>
      (select(exerciseMuscles)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  (exerciseId == null
                      ? const Constant(true)
                      : t.exerciseId.equals(exerciseId)),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.rowId),
            ]))
          .get();

  /// Muscle links of an exercise, deleted ones included (slots to reuse).
  Future<List<ExerciseMuscleRow>> muscleLinkSlots(String exerciseId) =>
      (select(exerciseMuscles)
            ..where((t) => t.exerciseId.equals(exerciseId))
            ..orderBy([(t) => OrderingTerm.asc(t.rowId)]))
          .get();

  Future<ExerciseNoteRow?> noteOf(String exerciseId) => (select(
    exerciseNotes,
  )..where((t) => t.exerciseId.equals(exerciseId))).getSingleOrNull();

  Future<List<ExerciseNoteRow>> allNotes() =>
      (select(exerciseNotes)..where((t) => t.deletedAt.isNull())).get();
}
