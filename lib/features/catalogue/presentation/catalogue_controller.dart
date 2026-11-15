import 'package:my_bodybuilding_program/core/images/image_storage.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogue_controller.g.dart';

/// How an exercise is used, which decides what can be done with it.
typedef ExerciseUsage = ({bool hasHistory, bool isPlanned});

/// Actions of the catalogue screens.
class CatalogueController {
  new(this._ref);

  final Ref _ref;

  CatalogueRepository get _catalogue => _ref.read(catalogueRepositoryProvider);

  Future<ExerciseUsage> usageOf(String exerciseId) async {
    final overview = await _ref.read(programRepositoryProvider).getOverview();
    return (
      hasHistory: await _catalogue.exerciseHasHistory(exerciseId),
      isPlanned: overview.sessions.any(
        (s) => s.exercises.any((e) => e.exerciseId == exerciseId),
      ),
    );
  }

  /// Creates ([exerciseId] null) or updates an exercise. Returns its id.
  Future<String> save(String? exerciseId, ExerciseDraft draft) async {
    if (exerciseId == null) return await _catalogue.createExercise(draft);
    final before = await _catalogue.getExercise(exerciseId);
    await _catalogue.updateExercise(exerciseId, draft);
    await _deleteIfReplaced(before?.image, draft.image);
    return exerciseId;
  }

  Future<void> archive(String exerciseId) =>
      _catalogue.archiveExercise(exerciseId);

  Future<void> restore(String exerciseId) =>
      _catalogue.restoreExercise(exerciseId);

  Future<void> delete(String exerciseId) async {
    final before = await _catalogue.getExercise(exerciseId);
    await _catalogue.deleteExercise(exerciseId);
    await _deleteIfReplaced(before?.image, null);
  }

  Future<void> saveNote(String exerciseId, String notes) =>
      _catalogue.saveNote(exerciseId, notes);

  // Muscles

  Future<void> addMuscle(String name) => _catalogue.addMuscle(name);

  Future<void> renameMuscle(String id, String name) =>
      _catalogue.renameMuscle(id, name);

  Future<void> setMuscleHidden(String id, {required bool hidden}) =>
      _catalogue.setMuscleHidden(id, hidden: hidden);

  /// Only for a muscle no exercise uses.
  Future<void> deleteMuscle(String id) => _catalogue.deleteMuscle(id);

  /// Takes or picks a photo and stores it privately. Null when cancelled.
  Future<UserImage?> pickPhoto({required bool fromCamera}) async {
    final path = await _ref
        .read(photoPickerProvider)
        .pick(fromCamera: fromCamera);
    if (path == null) return null;
    final storage = await _ref.read(imageStorageProvider.future);
    return await storage.import(path);
  }

  /// Removes photos picked during an edit that was not saved.
  Future<void> discardPhotos(Iterable<UserImage> images) async {
    final storage = await _ref.read(imageStorageProvider.future);
    for (final image in images) {
      await storage.delete(image);
    }
  }

  Future<void> _deleteIfReplaced(
    ExerciseImage? before,
    ExerciseImage? after,
  ) async {
    if (before is UserImage && before != after) {
      final storage = await _ref.read(imageStorageProvider.future);
      await storage.delete(before);
    }
  }
}

@Riverpod(keepAlive: true)
CatalogueController catalogueController(Ref ref) => CatalogueController(ref);
