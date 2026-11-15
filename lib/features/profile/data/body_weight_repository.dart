import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'body_weight_repository.g.dart';

/// The bodyweight log.
class BodyWeightRepository {
  new(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  /// Every entry, newest first.
  Stream<List<BodyWeight>> watchEntries() =>
      _db.personalDao.watching([_db.bodyWeights], getEntries);

  Future<List<BodyWeight>> getEntries() async => [
    for (final row in await _db.personalDao.allBodyWeights())
      BodyWeight(
        id: row.id,
        measuredAt: row.measuredAt,
        weightKg: row.weightKg,
        note: row.note,
      ),
  ];

  Future<String> addEntry({
    required DateTime measuredAt,
    required double weightKg,
    String? note,
  }) async {
    final id = _newId();
    await _db.personalDao.insertSynced(
      _db.bodyWeights,
      BodyWeightsCompanion(
        id: Value(id),
        measuredAt: Value(measuredAt.toUtc()),
        weightKg: Value(weightKg),
        note: Value(_clean(note)),
      ),
      _clock(),
    );
    return id;
  }

  Future<void> updateEntry(
    String id, {
    required DateTime measuredAt,
    required double weightKg,
    String? note,
  }) => _db.personalDao.patch(
    _db.bodyWeights,
    id,
    BodyWeightsCompanion(
      measuredAt: Value(measuredAt.toUtc()),
      weightKg: Value(weightKg),
      note: Value(_clean(note)),
    ),
    _clock(),
  );

  Future<void> deleteEntry(String id) =>
      _db.personalDao.softDelete(_db.bodyWeights, id, _clock());

  String? _clean(String? note) {
    final text = note?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

@Riverpod(keepAlive: true)
BodyWeightRepository bodyWeightRepository(Ref ref) => BodyWeightRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
  ref.watch(idGeneratorProvider),
);
