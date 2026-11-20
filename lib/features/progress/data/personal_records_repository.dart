import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'personal_records_repository.g.dart';

/// Personal records (PRs): logged by hand, apart from the training sets.
class PersonalRecordsRepository {
  new(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  /// Every PR (or only [exerciseId]'s), newest first.
  Stream<List<PersonalRecord>> watchRecords({String? exerciseId}) =>
      _db.personalDao.watching([
        _db.personalRecords,
      ], () => getRecords(exerciseId: exerciseId));

  Future<List<PersonalRecord>> getRecords({String? exerciseId}) async => [
    for (final row in await _db.personalDao.allPersonalRecords(
      exerciseId: exerciseId,
    ))
      _record(row),
  ];

  Future<PersonalRecord?> getRecord(String id) async {
    final row = await _db.personalDao.personalRecordById(id);
    return row == null ? null : _record(row);
  }

  /// Adds a PR to [exerciseId]. Throws [ArgumentError] when [draft] doesn't
  /// fit the exercise's measure.
  Future<String> addRecord(String exerciseId, PersonalRecordDraft draft) async {
    final clean = await _checked(exerciseId, draft);
    final id = _newId();
    await _db.personalDao.insertSynced(
      _db.personalRecords,
      _companion(clean).copyWith(id: Value(id), exerciseId: Value(exerciseId)),
      _clock(),
    );
    return id;
  }

  /// Replaces the values of the PR [id].
  Future<void> updateRecord(String id, PersonalRecordDraft draft) async {
    final row = await _db.personalDao.personalRecordById(id);
    if (row == null) throw ArgumentError('No personal record $id');
    final clean = await _checked(row.exerciseId, draft);
    await _db.personalDao.patch(
      _db.personalRecords,
      id,
      _companion(clean),
      _clock(),
    );
  }

  Future<void> deleteRecord(String id) =>
      _db.personalDao.softDelete(_db.personalRecords, id, _clock());

  Future<PersonalRecordDraft> _checked(
    String exerciseId,
    PersonalRecordDraft draft,
  ) async {
    final exercise = await _db.catalogueDao.exerciseById(exerciseId);
    if (exercise == null) throw ArgumentError('No exercise $exerciseId');
    final clean = draft.normalizedFor(exercise.measure);
    final error = draft.errorFor(exercise.measure);
    if (error != null) throw ArgumentError(error.name);
    return clean;
  }

  PersonalRecordsCompanion _companion(PersonalRecordDraft d) =>
      PersonalRecordsCompanion(
        achievedAt: Value(d.achievedAt.toUtc()),
        load: Value(d.load),
        unitId: Value(d.unitId),
        reps: Value(d.reps),
        seconds: Value(d.seconds),
        note: Value(d.note),
      );

  PersonalRecord _record(PersonalRecordRow row) => PersonalRecord(
    id: row.id,
    exerciseId: row.exerciseId,
    achievedAt: row.achievedAt,
    load: row.load,
    unitId: row.unitId,
    reps: row.reps,
    seconds: row.seconds,
    note: row.note,
  );
}

@Riverpod(keepAlive: true)
PersonalRecordsRepository personalRecordsRepository(Ref ref) =>
    PersonalRecordsRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(clockProvider),
      ref.watch(idGeneratorProvider),
    );
