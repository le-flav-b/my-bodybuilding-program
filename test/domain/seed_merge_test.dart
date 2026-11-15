import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/seed_merge.dart';

void main() {
  SeedExercise exercise(String key, {List<String> primary = const ['chest']}) =>
      SeedExercise(
        key: key,
        name: 'Name of $key',
        description: 'How to do $key',
        measure: Measure.reps,
        primaryMuscles: primary,
      );

  SeedFile seed({int version = 1, List<SeedExercise>? exercises}) => SeedFile(
    version: version,
    muscles: const [
      SeedMuscle(key: 'chest', name: 'Chest'),
      SeedMuscle(key: 'back', name: 'Back'),
    ],
    exercises: exercises ?? [exercise('bench'), exercise('row')],
  );

  SeededRowState row(
    String key, {
    bool userModified = false,
    bool deleted = false,
  }) => SeededRowState(
    seedKey: key,
    userModified: userModified,
    deleted: deleted,
  );

  group('planSeedMerge', () {
    test('first launch imports everything', () {
      final plan = planSeedMerge(
        seed: seed(),
        muscles: const {},
        exercises: const {},
        knownKeys: const {},
      );
      expect(plan.musclesToInsert.map((m) => m.key), ['chest', 'back']);
      expect(plan.exercisesToInsert.map((e) => e.key), ['bench', 'row']);
      expect(plan.musclesToUpdate, isEmpty);
      expect(plan.exercisesToUpdate, isEmpty);
    });

    test('an update adds only the new seed keys', () {
      final plan = planSeedMerge(
        seed: seed(
          version: 2,
          exercises: [exercise('bench'), exercise('row'), exercise('dip')],
        ),
        muscles: {'chest': row('chest'), 'back': row('back')},
        exercises: {'bench': row('bench'), 'row': row('row')},
        knownKeys: const {'m:chest', 'm:back', 'e:bench', 'e:row'},
      );
      expect(plan.exercisesToInsert.map((e) => e.key), ['dip']);
      expect(plan.musclesToInsert, isEmpty);
    });

    test('rows the user never edited are updated', () {
      final plan = planSeedMerge(
        seed: seed(version: 2),
        muscles: {'chest': row('chest'), 'back': row('back')},
        exercises: {'bench': row('bench'), 'row': row('row')},
        knownKeys: const {},
      );
      expect(plan.exercisesToUpdate.map((e) => e.key), ['bench', 'row']);
      expect(plan.musclesToUpdate.map((m) => m.key), ['chest', 'back']);
    });

    test('rows the user edited are never overwritten', () {
      final plan = planSeedMerge(
        seed: seed(version: 2),
        muscles: {
          'chest': row('chest', userModified: true),
          'back': row('back'),
        },
        exercises: {
          'bench': row('bench', userModified: true),
          'row': row('row'),
        },
        knownKeys: const {},
      );
      expect(plan.exercisesToUpdate.map((e) => e.key), ['row']);
      expect(plan.musclesToUpdate.map((m) => m.key), ['back']);
    });

    test('rows the user deleted are neither re-created nor updated', () {
      final plan = planSeedMerge(
        seed: seed(version: 2),
        muscles: {'chest': row('chest'), 'back': row('back', deleted: true)},
        exercises: {'bench': row('bench', deleted: true), 'row': row('row')},
        knownKeys: const {},
      );
      expect(plan.exercisesToInsert, isEmpty);
      expect(plan.exercisesToUpdate.map((e) => e.key), ['row']);
      expect(plan.musclesToInsert, isEmpty);
      expect(plan.musclesToUpdate.map((m) => m.key), ['chest']);
    });

    test('a purged deleted row is still not re-created (known keys)', () {
      final plan = planSeedMerge(
        seed: seed(version: 2),
        muscles: {'chest': row('chest'), 'back': row('back')},
        // "bench" was deleted and its row purged: only the key remembers it.
        exercises: {'row': row('row')},
        knownKeys: const {'e:bench', 'e:row', 'm:chest', 'm:back'},
      );
      expect(plan.exercisesToInsert, isEmpty);
    });

    test('muscle and exercise keys do not collide in the known keys', () {
      final plan = planSeedMerge(
        seed: seed(exercises: [exercise('chest')]),
        muscles: {'chest': row('chest'), 'back': row('back')},
        exercises: const {},
        knownKeys: const {'m:chest', 'm:back'},
      );
      expect(plan.exercisesToInsert.map((e) => e.key), ['chest']);
    });

    test('seedKeysOf lists every key with its prefix', () {
      expect(seedKeysOf(seed()), {'m:chest', 'm:back', 'e:bench', 'e:row'});
    });
  });

  group('validateSeed', () {
    test('accepts a consistent file', () {
      expect(() => validateSeed(seed()), returnsNormally);
    });

    test('rejects duplicate keys', () {
      expect(
        () => validateSeed(
          seed(exercises: [exercise('bench'), exercise('bench')]),
        ),
        throwsA(isA<SeedFormatException>()),
      );
    });

    test('rejects an unknown muscle', () {
      expect(
        () => validateSeed(
          seed(
            exercises: [
              exercise('curl', primary: ['biceps']),
            ],
          ),
        ),
        throwsA(isA<SeedFormatException>()),
      );
    });

    test('rejects an exercise without primary muscle', () {
      expect(
        () => validateSeed(seed(exercises: [exercise('x', primary: [])])),
        throwsA(isA<SeedFormatException>()),
      );
    });

    test('rejects a muscle that is both primary and secondary', () {
      expect(
        () => validateSeed(
          seed(
            exercises: [
              exercise('bench').copyWith(secondaryMuscles: ['chest']),
            ],
          ),
        ),
        throwsA(isA<SeedFormatException>()),
      );
    });

    test('rejects a missing image file', () {
      final withImage = seed(
        exercises: [exercise('bench').copyWith(image: 'bench.webp')],
      );
      expect(
        () => validateSeed(withImage, imageExists: (_) => false),
        throwsA(isA<SeedFormatException>()),
      );
      expect(
        () => validateSeed(withImage, imageExists: (_) => true),
        returnsNormally,
      );
    });
  });

  test('parses the seed file format', () {
    final file = SeedFile.fromJson({
      'version': 3,
      'muscles': [
        {'key': 'chest', 'name': 'Chest'},
      ],
      'exercises': [
        {
          'key': 'plank',
          'name': 'Plank',
          'description': 'Hold.',
          'measure': 'time',
          'primary_muscles': ['chest'],
          'secondary_muscles': <String>[],
          'image': null,
        },
      ],
    });
    expect(file.version, 3);
    expect(file.exercises.single.measure, Measure.time);
    expect(file.exercises.single.image, isNull);
  });
}
