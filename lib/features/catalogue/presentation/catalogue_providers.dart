import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogue_providers.g.dart';

/// Every exercise, archived ones included.
@Riverpod(keepAlive: true)
Stream<List<Exercise>> exercises(Ref ref) =>
    ref.watch(catalogueRepositoryProvider).watchExercises();

/// Exercises by id (empty while loading).
@Riverpod(keepAlive: true)
Map<String, Exercise> exercisesById(Ref ref) => {
  for (final e in ref.watch(exercisesProvider).value ?? const <Exercise>[])
    e.id: e,
};

/// Every muscle, hidden ones included, in display order.
@Riverpod(keepAlive: true)
Stream<List<Muscle>> muscles(Ref ref) =>
    ref.watch(catalogueRepositoryProvider).watchMuscles();

@Riverpod(keepAlive: true)
Map<String, Muscle> musclesById(Ref ref) => {
  for (final m in ref.watch(musclesProvider).value ?? const <Muscle>[]) m.id: m,
};

/// The muscles offered in filters and pickers (hidden ones left out).
@Riverpod(keepAlive: true)
List<Muscle> visibleMuscles(Ref ref) => [
  for (final m in ref.watch(musclesProvider).value ?? const <Muscle>[])
    if (!m.hidden) m,
];

/// Number of exercises tagged with each muscle.
@riverpod
Stream<Map<String, int>> muscleExerciseCounts(Ref ref) =>
    ref.watch(catalogueRepositoryProvider).watchExerciseCountByMuscle();

/// The user's notes/setup per exercise id.
@Riverpod(keepAlive: true)
Stream<Map<String, String>> exerciseNotes(Ref ref) =>
    ref.watch(catalogueRepositoryProvider).watchNotes();

/// One exercise, live (null once deleted).
@riverpod
Exercise? exercise(Ref ref, String id) => ref.watch(exercisesByIdProvider)[id];

/// "Chest · Triceps · Shoulders": primary muscles first.
@riverpod
String exerciseMuscleNames(Ref ref, String exerciseId) {
  final exercise = ref.watch(exerciseProvider(exerciseId));
  if (exercise == null) return '';
  final muscles = ref.watch(musclesByIdProvider);
  return [
    for (final id in [
      ...exercise.primaryMuscleIds,
      ...exercise.secondaryMuscleIds,
    ])
      if (muscles[id] case final muscle?) muscle.name,
  ].join(' · ');
}
