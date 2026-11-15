import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';

part 'seed_merge.freezed.dart';
part 'seed_merge.g.dart';

/// The bundled catalogue file (`assets/seed/catalogue.json`).
@freezed
abstract class SeedFile with _$SeedFile {
  const factory({
    required int version,
    required List<SeedMuscle> muscles,
    required List<SeedExercise> exercises,
  }) = _SeedFile;

  factory fromJson(Map<String, dynamic> json) => _$SeedFileFromJson(json);
}

@freezed
abstract class SeedMuscle with _$SeedMuscle {
  const factory({required String key, required String name}) = _SeedMuscle;

  factory fromJson(Map<String, dynamic> json) => _$SeedMuscleFromJson(json);
}

@freezed
abstract class SeedExercise with _$SeedExercise {
  const factory({
    required String key,
    required String name,
    required String description,
    required Measure measure,
    @JsonKey(name: 'primary_muscles') required List<String> primaryMuscles,
    @JsonKey(name: 'secondary_muscles')
    @Default(<String>[])
    List<String> secondaryMuscles,
    String? image,
  }) = _SeedExercise;

  factory fromJson(Map<String, dynamic> json) => _$SeedExerciseFromJson(json);
}

/// What the database already knows about a seeded row.
@freezed
abstract class SeededRowState with _$SeededRowState {
  const factory({
    required String seedKey,
    required bool userModified,
    required bool deleted,
  }) = _SeededRowState;
}

/// What an import has to do.
@freezed
abstract class SeedMergePlan with _$SeedMergePlan {
  const factory({
    required List<SeedMuscle> musclesToInsert,
    required List<SeedMuscle> musclesToUpdate,
    required List<SeedExercise> exercisesToInsert,
    required List<SeedExercise> exercisesToUpdate,
  }) = _SeedMergePlan;
  const new _();

  bool get isEmpty =>
      musclesToInsert.isEmpty &&
      musclesToUpdate.isEmpty &&
      exercisesToInsert.isEmpty &&
      exercisesToUpdate.isEmpty;
}

/// Thrown when the seed file is inconsistent.
class SeedFormatException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'SeedFormatException: $message';
}

/// Checks keys and references of [seed]. [imageExists] tells whether a
/// bundled image file is present.
void validateSeed(SeedFile seed, {bool Function(String file)? imageExists}) {
  final muscleKeys = <String>{};
  for (final m in seed.muscles) {
    if (!muscleKeys.add(m.key)) {
      throw SeedFormatException('Duplicate muscle key "${m.key}"');
    }
    if (m.name.trim().isEmpty) {
      throw SeedFormatException('Muscle "${m.key}" has no name');
    }
  }
  final exerciseKeys = <String>{};
  for (final e in seed.exercises) {
    if (!exerciseKeys.add(e.key)) {
      throw SeedFormatException('Duplicate exercise key "${e.key}"');
    }
    if (e.name.trim().isEmpty) {
      throw SeedFormatException('Exercise "${e.key}" has no name');
    }
    if (e.primaryMuscles.isEmpty) {
      throw SeedFormatException('Exercise "${e.key}" has no primary muscle');
    }
    for (final m in [...e.primaryMuscles, ...e.secondaryMuscles]) {
      if (!muscleKeys.contains(m)) {
        throw SeedFormatException(
          'Exercise "${e.key}" references unknown muscle "$m"',
        );
      }
    }
    if (e.primaryMuscles.toSet().intersection(e.secondaryMuscles.toSet())
        case final both when both.isNotEmpty) {
      throw SeedFormatException(
        'Exercise "${e.key}" has ${both.join(', ')} as primary and secondary',
      );
    }
    final image = e.image;
    if (image != null && imageExists != null && !imageExists(image)) {
      throw SeedFormatException(
        'Exercise "${e.key}" references missing image "$image"',
      );
    }
  }
}

/// The seed import rule (Notion > Data & Sync > Pre-filled catalogue):
///
/// - a seed_key never seen before is inserted;
/// - an existing seeded row is updated only if the user never edited it;
/// - a row the user deleted is never re-created ([knownKeys] remembers every
///   key ever imported, even after the deleted row is purged).
SeedMergePlan planSeedMerge({
  required SeedFile seed,
  required Map<String, SeededRowState> muscles,
  required Map<String, SeededRowState> exercises,
  required Set<String> knownKeys,
}) {
  List<T> toInsert<T>(
    Iterable<T> items,
    String Function(T) key,
    Map<String, SeededRowState> existing,
    String prefix,
  ) => [
    for (final item in items)
      if (!existing.containsKey(key(item)) &&
          !knownKeys.contains('$prefix${key(item)}'))
        item,
  ];

  List<T> toUpdate<T>(
    Iterable<T> items,
    String Function(T) key,
    Map<String, SeededRowState> existing,
  ) => [
    for (final item in items)
      if (existing[key(item)] case final row?
          when !row.deleted && !row.userModified)
        item,
  ];

  return SeedMergePlan(
    musclesToInsert: toInsert(
      seed.muscles,
      (m) => m.key,
      muscles,
      muscleKeyPrefix,
    ),
    musclesToUpdate: toUpdate(seed.muscles, (m) => m.key, muscles),
    exercisesToInsert: toInsert(
      seed.exercises,
      (e) => e.key,
      exercises,
      exerciseKeyPrefix,
    ),
    exercisesToUpdate: toUpdate(seed.exercises, (e) => e.key, exercises),
  );
}

/// Prefixes used in the "known keys" set, since muscles and exercises have
/// separate key spaces.
const String muscleKeyPrefix = 'm:';
const String exerciseKeyPrefix = 'e:';

/// Every key of [seed], prefixed, to add to the known keys after an import.
Set<String> seedKeysOf(SeedFile seed) => {
  for (final m in seed.muscles) '$muscleKeyPrefix${m.key}',
  for (final e in seed.exercises) '$exerciseKeyPrefix${e.key}',
};
