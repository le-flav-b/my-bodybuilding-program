import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalogue.freezed.dart';

/// How an exercise is measured.
enum Measure { reps, time }

/// How much a muscle is involved in an exercise.
enum MuscleRole { primary, secondary }

/// An entry of the muscle list used to tag exercises.
@freezed
abstract class Muscle with _$Muscle {
  const factory({
    required String id,
    required String name,
    @Default(false) bool hidden,
    String? seedKey,
    @Default(false) bool userModified,
    @Default(0) int position,
  }) = _Muscle;
}

/// Where an exercise picture comes from.
@immutable
sealed class ExerciseImage {
  const new(this.file);

  /// Parses the stored form (`seed:<file>` or `user:<file>`).
  static ExerciseImage? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith(_seedPrefix)) {
      return SeedImage(raw.substring(_seedPrefix.length));
    }
    if (raw.startsWith(_userPrefix)) {
      return UserImage(raw.substring(_userPrefix.length));
    }
    return null;
  }

  static const String _seedPrefix = 'seed:';
  static const String _userPrefix = 'user:';

  final String file;

  /// The stored form.
  String get raw => switch (this) {
    SeedImage() => '$_seedPrefix$file',
    UserImage() => '$_userPrefix$file',
  };

  @override
  bool operator ==(Object other) =>
      other is ExerciseImage &&
      other.runtimeType == runtimeType &&
      other.file == file;

  @override
  int get hashCode => Object.hash(runtimeType, file);

  @override
  String toString() => raw;
}

/// An illustration bundled with the app (`assets/seed/images/<file>`).
final class SeedImage extends ExerciseImage {
  const new(super.file);

  String get assetPath => 'assets/seed/images/$file';
}

/// A photo taken or picked by the user, in private app storage.
final class UserImage extends ExerciseImage {
  const new(super.file);
}

/// A movement of the catalogue. Holds none of the user's numbers.
@freezed
abstract class Exercise with _$Exercise {
  const factory({
    required String id,
    required String name,
    required Measure measure,
    @Default('') String description,
    ExerciseImage? image,
    @Default(<String>[]) List<String> primaryMuscleIds,
    @Default(<String>[]) List<String> secondaryMuscleIds,
    String? seedKey,
    @Default(false) bool userModified,
    DateTime? archivedAt,
  }) = _Exercise;
  const new _();

  bool get isArchived => archivedAt != null;
  bool get isSeeded => seedKey != null;

  /// The muscle that picks the placeholder image, if any.
  String? get mainMuscleId =>
      primaryMuscleIds.isEmpty ? null : primaryMuscleIds.first;

  /// Whether [muscleId] is tagged on this exercise (any role).
  bool targets(String muscleId) =>
      primaryMuscleIds.contains(muscleId) ||
      secondaryMuscleIds.contains(muscleId);
}

/// The fields of an exercise the user edits (create or update).
@freezed
abstract class ExerciseDraft with _$ExerciseDraft {
  const factory({
    required String name,
    required Measure measure,
    @Default('') String description,
    ExerciseImage? image,
    @Default(<String>[]) List<String> primaryMuscleIds,
    @Default(<String>[]) List<String> secondaryMuscleIds,
  }) = _ExerciseDraft;
}

/// Filters the catalogue: name search, muscle filter, archived toggle.
List<Exercise> filterExercises(
  Iterable<Exercise> exercises, {
  String query = '',
  Set<String> muscleIds = const {},
  bool archived = false,
}) {
  final needle = query.trim().toLowerCase();
  final result =
      exercises.where((e) {
          if (e.isArchived != archived) return false;
          if (needle.isNotEmpty && !e.name.toLowerCase().contains(needle)) {
            return false;
          }
          if (muscleIds.isNotEmpty && !muscleIds.any(e.targets)) return false;
          return true;
        }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}
