import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/seed_merge.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';

/// Imports the bundled catalogue (`assets/seed/catalogue.json`) on first
/// launch and after an app update that ships a new seed version.
///
/// The decision of what to insert or update is the pure rule
/// [planSeedMerge]; this class only reads and writes rows.
class SeedImporter {
  new(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  static const String assetPath = 'assets/seed/catalogue.json';

  /// Imports [json]. Returns false when this seed version was already
  /// imported. [imageExists] validates image references (tests).
  Future<bool> importJson(
    String json, {
    bool Function(String file)? imageExists,
  }) async {
    final seed = SeedFile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    validateSeed(seed, imageExists: imageExists);

    final stored = int.tryParse(
      await _db.personalDao.setting(SettingKeys.seedVersion) ?? '',
    );
    if (stored != null && stored >= seed.version) return false;

    await _db.transaction(() async {
      final now = _clock();
      final knownKeys = _decodeKeys(
        await _db.personalDao.setting(SettingKeys.seedKnownKeys),
      );
      final muscleRows = await _db.catalogueDao.seededMuscles();
      final exerciseRows = await _db.catalogueDao.seededExercises();
      final plan = planSeedMerge(
        seed: seed,
        knownKeys: knownKeys,
        muscles: {
          for (final m in muscleRows)
            m.seedKey!: SeededRowState(
              seedKey: m.seedKey!,
              userModified: m.userModified,
              deleted: m.deletedAt != null,
            ),
        },
        exercises: {
          for (final e in exerciseRows)
            e.seedKey!: SeededRowState(
              seedKey: e.seedKey!,
              userModified: e.userModified,
              deleted: e.deletedAt != null,
            ),
        },
      );

      await _importMuscles(seed, plan, muscleRows, now);
      await _importExercises(plan, exerciseRows, now);

      await _db.personalDao.putSetting(
        SettingKeys.seedKnownKeys,
        jsonEncode({...knownKeys, ...seedKeysOf(seed)}.toList()..sort()),
        now,
      );
      await _db.personalDao.putSetting(
        SettingKeys.seedVersion,
        '${seed.version}',
        now,
      );
    });
    return true;
  }

  Future<void> _importMuscles(
    SeedFile seed,
    SeedMergePlan plan,
    List<MuscleRow> existing,
    DateTime now,
  ) async {
    final order = {for (final (i, m) in seed.muscles.indexed) m.key: i};
    for (final muscle in plan.musclesToInsert) {
      await _db.catalogueDao.insertSynced(
        _db.muscles,
        MusclesCompanion(
          id: Value(_newId()),
          name: Value(muscle.name),
          seedKey: Value(muscle.key),
          position: Value(order[muscle.key]!),
        ),
        now,
      );
    }
    final rows = {for (final m in existing) m.seedKey!: m};
    for (final muscle in plan.musclesToUpdate) {
      final row = rows[muscle.key]!;
      if (row.name == muscle.name) continue;
      await _db.catalogueDao.patch(
        _db.muscles,
        row.id,
        MusclesCompanion(name: Value(muscle.name)),
        now,
      );
    }
  }

  Future<void> _importExercises(
    SeedMergePlan plan,
    List<ExerciseRow> existing,
    DateTime now,
  ) async {
    // Seed key → id of the muscles that still exist.
    final muscleIds = {
      for (final m in await _db.catalogueDao.seededMuscles())
        if (m.deletedAt == null) m.seedKey!: m.id,
    };

    for (final exercise in plan.exercisesToInsert) {
      final id = _newId();
      await _db.catalogueDao.insertSynced(
        _db.exercises,
        ExercisesCompanion(
          id: Value(id),
          name: Value(exercise.name),
          description: Value(exercise.description),
          image: Value(_image(exercise)),
          measure: Value(exercise.measure),
          seedKey: Value(exercise.key),
        ),
        now,
      );
      await _writeLinks(id, exercise, muscleIds, const [], now);
    }

    final rows = {for (final e in existing) e.seedKey!: e};
    for (final exercise in plan.exercisesToUpdate) {
      final row = rows[exercise.key]!;
      final image = _image(exercise);
      final changed =
          row.name != exercise.name ||
          row.description != exercise.description ||
          row.measure != exercise.measure ||
          row.image != image;
      if (changed) {
        await _db.catalogueDao.patch(
          _db.exercises,
          row.id,
          ExercisesCompanion(
            name: Value(exercise.name),
            description: Value(exercise.description),
            image: Value(image),
            measure: Value(exercise.measure),
          ),
          now,
        );
      }
      await _writeLinks(
        row.id,
        exercise,
        muscleIds,
        await _db.catalogueDao.muscleLinkSlots(row.id),
        now,
      );
    }
  }

  /// Writes the muscle links of a seeded exercise, reusing [slots].
  Future<void> _writeLinks(
    String exerciseId,
    SeedExercise exercise,
    Map<String, String> muscleIds,
    List<ExerciseMuscleRow> slots,
    DateTime now,
  ) async {
    final wanted = <(String, MuscleRole, int)>[
      for (final (i, key) in exercise.primaryMuscles.indexed)
        if (muscleIds[key] case final id?) (id, MuscleRole.primary, i),
      for (final (i, key) in exercise.secondaryMuscles.indexed)
        if (muscleIds[key] case final id?) (id, MuscleRole.secondary, i),
    ];
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

  String? _image(SeedExercise exercise) {
    final file = exercise.image;
    return file == null ? null : SeedImage(file).raw;
  }

  Set<String> _decodeKeys(String? json) {
    if (json == null || json.isEmpty) return {};
    return {for (final key in jsonDecode(json) as List<dynamic>) key as String};
  }
}
