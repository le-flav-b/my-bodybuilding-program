import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogue_repository.g.dart';

/// Thrown when an exercise, muscle or unit that is in use is deleted.
class InUseException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Catalogue layer (exercises, muscles) and the personal exercise notes.
class CatalogueRepository {
  new(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  // ---------------------------------------------------------------- muscles

  /// Every muscle (hidden ones included), in display order.
  Stream<List<Muscle>> watchMuscles() =>
      _db.catalogueDao.watching([_db.muscles], getMuscles);

  Future<List<Muscle>> getMuscles() async => [
    for (final row in await _db.catalogueDao.allMuscles()) _muscle(row),
  ];

  Future<String> addMuscle(String name) async {
    final id = _newId();
    await _db.catalogueDao.insertSynced(
      _db.muscles,
      MusclesCompanion(
        id: Value(id),
        name: Value(name.trim()),
        position: Value(await _db.catalogueDao.nextMusclePosition()),
      ),
      _clock(),
    );
    return id;
  }

  /// Renames a muscle. Its id is stable, so filters and charts keep working.
  Future<void> renameMuscle(String id, String name) => _db.catalogueDao.patch(
    _db.muscles,
    id,
    MusclesCompanion(name: Value(name.trim()), userModified: const Value(true)),
    _clock(),
  );

  Future<void> setMuscleHidden(String id, {required bool hidden}) =>
      _db.catalogueDao.patch(
        _db.muscles,
        id,
        MusclesCompanion(
          hidden: Value(hidden),
          userModified: const Value(true),
        ),
        _clock(),
      );

  /// Deletes a muscle no exercise uses. One in use can only be hidden.
  Future<void> deleteMuscle(String id) async {
    final counts = await exerciseCountByMuscle();
    if ((counts[id] ?? 0) > 0) {
      throw const InUseException(
        'This muscle is used by exercises; hide it instead.',
      );
    }
    await _db.catalogueDao.softDelete(_db.muscles, id, _clock());
  }

  /// Number of exercises (archived ones included) tagged with each muscle.
  Future<Map<String, int>> exerciseCountByMuscle() async {
    final exerciseIds = {
      for (final e in await _db.catalogueDao.allExercises()) e.id,
    };
    final counts = <String, int>{};
    for (final link in await _db.catalogueDao.muscleLinks()) {
      if (!exerciseIds.contains(link.exerciseId)) continue;
      counts.update(link.muscleId, (c) => c + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Stream<Map<String, int>> watchExerciseCountByMuscle() => _db.catalogueDao
      .watching([_db.exercises, _db.exerciseMuscles], exerciseCountByMuscle);

  // -------------------------------------------------------------- exercises

  /// Every exercise, archived ones included.
  Stream<List<Exercise>> watchExercises() => _db.catalogueDao.watching([
    _db.exercises,
    _db.exerciseMuscles,
  ], getExercises);

  Future<List<Exercise>> getExercises() async {
    final links = await _db.catalogueDao.muscleLinks();
    final byExercise = <String, List<ExerciseMuscleRow>>{};
    for (final link in links) {
      byExercise.putIfAbsent(link.exerciseId, () => []).add(link);
    }
    return [
      for (final row in await _db.catalogueDao.allExercises())
        _exercise(row, byExercise[row.id] ?? const []),
    ];
  }

  Stream<Exercise?> watchExercise(String id) => _db.catalogueDao.watching([
    _db.exercises,
    _db.exerciseMuscles,
  ], () => getExercise(id));

  Future<Exercise?> getExercise(String id) async {
    final row = await _db.catalogueDao.exerciseById(id);
    if (row == null) return null;
    return _exercise(row, await _db.catalogueDao.muscleLinks(exerciseId: id));
  }

  /// Adds one of the user's own exercises.
  Future<String> createExercise(ExerciseDraft draft) async {
    final id = _newId();
    await _db.transaction(() async {
      await _db.catalogueDao.insertSynced(
        _db.exercises,
        ExercisesCompanion(
          id: Value(id),
          name: Value(draft.name.trim()),
          description: Value(draft.description.trim()),
          image: Value(draft.image?.raw),
          measure: Value(draft.measure),
        ),
        _clock(),
      );
      await _setMuscles(id, draft.primaryMuscleIds, draft.secondaryMuscleIds);
    });
    return id;
  }

  /// Edits an exercise. A pre-filled one becomes user-modified, so a seed
  /// update never overwrites it. History follows the id, not the name.
  Future<void> updateExercise(String id, ExerciseDraft draft) =>
      _db.transaction(() async {
        await _db.catalogueDao.patch(
          _db.exercises,
          id,
          ExercisesCompanion(
            name: Value(draft.name.trim()),
            description: Value(draft.description.trim()),
            image: Value(draft.image?.raw),
            measure: Value(draft.measure),
            userModified: const Value(true),
          ),
          _clock(),
        );
        await _setMuscles(id, draft.primaryMuscleIds, draft.secondaryMuscleIds);
      });

  /// Hides an exercise from pickers and the list; history and charts keep it.
  Future<void> archiveExercise(String id) => _db.catalogueDao.patch(
    _db.exercises,
    id,
    ExercisesCompanion(archivedAt: Value(_clock())),
    _clock(),
  );

  Future<void> restoreExercise(String id) => _db.catalogueDao.patch(
    _db.exercises,
    id,
    const ExercisesCompanion(archivedAt: Value(null)),
    _clock(),
  );

  /// Workouts or personal records: either one means the exercise can only
  /// be archived and its measure can't change.
  Future<bool> exerciseHasHistory(String id) async =>
      await _db.historyDao.exerciseHasHistory(id) ||
      await _db.personalDao.exerciseHasPersonalRecords(id);

  /// Deletes an exercise that has never been done (it is also removed from
  /// the sessions that planned it). One with history can only be archived.
  Future<void> deleteExercise(String id) async {
    if (await exerciseHasHistory(id)) {
      throw const InUseException(
        'This exercise has history; archive it instead.',
      );
    }
    final now = _clock();
    await _db.transaction(() async {
      final planned = await (_db.select(
        _db.sessionExercises,
      )..where((t) => t.exerciseId.equals(id) & t.deletedAt.isNull())).get();
      for (final row in planned) {
        await _db.planDao.softDeleteWhere(
          _db.plannedSets,
          (t) => t.sessionExerciseId.equals(row.id),
          now,
        );
        await _db.planDao.softDelete(_db.sessionExercises, row.id, now);
      }
      await _db.catalogueDao.softDeleteWhere(
        _db.exerciseMuscles,
        (t) => t.exerciseId.equals(id),
        now,
      );
      await _db.catalogueDao.softDeleteWhere(
        _db.exerciseNotes,
        (t) => t.exerciseId.equals(id),
        now,
      );
      await _db.catalogueDao.softDelete(_db.exercises, id, now);
    });
  }

  /// Rewrites the muscle links of an exercise, reusing existing rows.
  Future<void> _setMuscles(
    String exerciseId,
    List<String> primary,
    List<String> secondary,
  ) async {
    final now = _clock();
    final wanted = <(String, MuscleRole, int)>[
      for (final (i, m) in primary.indexed) (m, MuscleRole.primary, i),
      for (final (i, m) in secondary.indexed)
        if (!primary.contains(m)) (m, MuscleRole.secondary, i),
    ];
    final slots = await _db.catalogueDao.muscleLinkSlots(exerciseId);
    for (final (i, (muscleId, role, position)) in wanted.indexed) {
      if (i < slots.length) {
        final slot = slots[i];
        final same =
            slot.deletedAt == null &&
            slot.muscleId == muscleId &&
            slot.role == role &&
            slot.position == position;
        if (same) continue;
        await _db.catalogueDao.patch(
          _db.exerciseMuscles,
          slot.id,
          ExerciseMusclesCompanion(
            muscleId: Value(muscleId),
            role: Value(role),
            position: Value(position),
            deletedAt: const Value(null),
          ),
          now,
        );
      } else {
        await _db.catalogueDao.insertSynced(
          _db.exerciseMuscles,
          ExerciseMusclesCompanion(
            id: Value(_newId()),
            exerciseId: Value(exerciseId),
            muscleId: Value(muscleId),
            role: Value(role),
            position: Value(position),
          ),
          now,
        );
      }
    }
    for (final slot in slots.skip(wanted.length)) {
      if (slot.deletedAt == null) {
        await _db.catalogueDao.softDelete(_db.exerciseMuscles, slot.id, now);
      }
    }
  }

  // ------------------------------------------------------------------ notes

  /// The user's notes/setup per exercise id (exercises without notes are
  /// absent). Editing the catalogue never touches them.
  Stream<Map<String, String>> watchNotes() =>
      _db.catalogueDao.watching([_db.exerciseNotes], getNotes);

  Future<Map<String, String>> getNotes() async => {
    for (final row in await _db.catalogueDao.allNotes())
      if (row.notes.trim().isNotEmpty) row.exerciseId: row.notes,
  };

  Future<void> saveNote(String exerciseId, String notes) async {
    final now = _clock();
    final existing = await _db.catalogueDao.noteOf(exerciseId);
    if (existing == null) {
      await _db.catalogueDao.insertSynced(
        _db.exerciseNotes,
        ExerciseNotesCompanion(
          id: Value(_newId()),
          exerciseId: Value(exerciseId),
          notes: Value(notes.trim()),
        ),
        now,
      );
    } else {
      await _db.catalogueDao.patch(
        _db.exerciseNotes,
        existing.id,
        ExerciseNotesCompanion(
          notes: Value(notes.trim()),
          deletedAt: const Value(null),
        ),
        now,
      );
    }
  }

  // ---------------------------------------------------------------- mappers

  Muscle _muscle(MuscleRow row) => Muscle(
    id: row.id,
    name: row.name,
    hidden: row.hidden,
    seedKey: row.seedKey,
    userModified: row.userModified,
    position: row.position,
  );

  Exercise _exercise(ExerciseRow row, List<ExerciseMuscleRow> links) =>
      Exercise(
        id: row.id,
        name: row.name,
        description: row.description,
        image: ExerciseImage.parse(row.image),
        measure: row.measure,
        primaryMuscleIds: [
          for (final l in links)
            if (l.role == MuscleRole.primary) l.muscleId,
        ],
        secondaryMuscleIds: [
          for (final l in links)
            if (l.role == MuscleRole.secondary) l.muscleId,
        ],
        seedKey: row.seedKey,
        userModified: row.userModified,
        archivedAt: row.archivedAt,
      );
}

@Riverpod(keepAlive: true)
CatalogueRepository catalogueRepository(Ref ref) => CatalogueRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
  ref.watch(idGeneratorProvider),
);
