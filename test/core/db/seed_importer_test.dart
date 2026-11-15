import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/seed_merge.dart';

import '../../helpers/test_env.dart';

Map<String, dynamic> _exercise(
  String key, {
  String? name,
  String description = 'Do it well.',
  String measure = 'reps',
  List<String> primary = const ['chest'],
  List<String> secondary = const [],
  String? image,
}) => {
  'key': key,
  'name': name ?? 'Exercise $key',
  'description': description,
  'measure': measure,
  'primary_muscles': primary,
  'secondary_muscles': secondary,
  'image': image,
};

String _seed(int version, List<Map<String, dynamic>> exercises) => jsonEncode({
  'version': version,
  'muscles': [
    {'key': 'chest', 'name': 'Chest'},
    {'key': 'triceps', 'name': 'Triceps'},
  ],
  'exercises': exercises,
});

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<Exercise> byKey(String key) async =>
      (await env.catalogue.getExercises()).firstWhere((e) => e.seedKey == key);

  group('the shipped seed', () {
    final json = File('assets/seed/catalogue.json').readAsStringSync();
    bool imageExists(String file) =>
        File('assets/seed/images/$file').existsSync();

    test('imports on first launch with every reference valid', () async {
      expect(await env.seed.importJson(json, imageExists: imageExists), isTrue);

      final muscles = await env.catalogue.getMuscles();
      final exercises = await env.catalogue.getExercises();
      expect(muscles, hasLength(13));
      expect(exercises, hasLength(82));
      expect(exercises.where((e) => e.image != null), hasLength(44));
      expect(muscles.first.name, 'Chest');
      expect(muscles.map((m) => m.position), List.generate(13, (i) => i));

      final muscleIds = {for (final m in muscles) m.id};
      for (final e in exercises) {
        expect(e.seedKey, isNotNull);
        expect(e.userModified, isFalse);
        expect(e.primaryMuscleIds, isNotEmpty, reason: e.name);
        expect(
          muscleIds.containsAll([
            ...e.primaryMuscleIds,
            ...e.secondaryMuscleIds,
          ]),
          isTrue,
          reason: e.name,
        );
        if (e.image case final SeedImage image) {
          expect(File(image.assetPath).existsSync(), isTrue, reason: e.name);
        }
      }

      final bench = await byKey('barbell_bench_press');
      final chest = muscles.firstWhere((m) => m.seedKey == 'chest');
      expect(bench.name, 'Barbell bench press');
      expect(bench.measure, Measure.reps);
      expect(bench.primaryMuscleIds, [chest.id]);
      expect(bench.secondaryMuscleIds, hasLength(2));
      expect(bench.image, const SeedImage('barbell_bench_press.webp'));
      expect((await byKey('plank')).measure, Measure.time);
    });

    test('importing the same version again changes nothing', () async {
      await env.seed.importJson(json);
      final before = await env.db.select(env.db.exercises).get();
      env.clock.advance(const Duration(days: 1));
      expect(await env.seed.importJson(json), isFalse);
      final after = await env.db.select(env.db.exercises).get();
      expect(after.length, before.length);
      expect(after.every((row) => row.updatedAt != env.clock.now), isTrue);
    });

    test('no program is seeded', () async {
      await env.seed.importJson(json);
      expect((await env.program.getOverview()).isEmpty, isTrue);
    });
  });

  group('update with a new seed', () {
    setUp(() async {
      await env.seed.importJson(
        _seed(1, [
          _exercise('bench', secondary: ['triceps']),
          _exercise('fly'),
          _exercise('dip'),
        ]),
      );
      env.clock.advance(const Duration(days: 30));
    });

    test('adds new seed keys', () async {
      await env.seed.importJson(
        _seed(2, [
          _exercise('bench', secondary: ['triceps']),
          _exercise('fly'),
          _exercise('dip'),
          _exercise('pushup'),
        ]),
      );
      final exercises = await env.catalogue.getExercises();
      expect(exercises.map((e) => e.seedKey), contains('pushup'));
      expect(exercises, hasLength(4));
    });

    test('updates rows the user never edited', () async {
      await env.seed.importJson(
        _seed(2, [
          _exercise(
            'bench',
            name: 'Barbell bench press',
            description: 'Better cues.',
            primary: ['chest', 'triceps'],
            image: 'bench.webp',
          ),
          _exercise('fly'),
          _exercise('dip'),
        ]),
      );
      final bench = await byKey('bench');
      expect(bench.name, 'Barbell bench press');
      expect(bench.description, 'Better cues.');
      expect(bench.image, const SeedImage('bench.webp'));
      expect(bench.primaryMuscleIds, hasLength(2));
      expect(bench.secondaryMuscleIds, isEmpty);
      expect(bench.userModified, isFalse);
    });

    test('never overwrites an exercise the user edited', () async {
      final bench = await byKey('bench');
      await env.catalogue.updateExercise(
        bench.id,
        ExerciseDraft(
          name: 'My bench',
          measure: bench.measure,
          description: 'My cues',
          image: const UserImage('mine.jpg'),
          primaryMuscleIds: bench.primaryMuscleIds,
        ),
      );
      await env.seed.importJson(
        _seed(2, [
          _exercise('bench', name: 'Renamed by the seed', image: 'b.webp'),
          _exercise('fly', name: 'Chest fly'),
          _exercise('dip'),
        ]),
      );
      final after = await byKey('bench');
      expect(after.name, 'My bench');
      expect(after.description, 'My cues');
      expect(after.image, const UserImage('mine.jpg'));
      expect(after.userModified, isTrue);
      // The untouched one still follows the seed.
      expect((await byKey('fly')).name, 'Chest fly');
    });

    test('never re-creates an exercise the user deleted', () async {
      final dip = await byKey('dip');
      await env.catalogue.deleteExercise(dip.id);
      await env.seed.importJson(
        _seed(2, [_exercise('bench'), _exercise('fly'), _exercise('dip')]),
      );
      final keys = (await env.catalogue.getExercises()).map((e) => e.seedKey);
      expect(keys, isNot(contains('dip')));
    });

    test(
      'still does not re-create it after the deleted row is purged',
      () async {
        final dip = await byKey('dip');
        await env.catalogue.deleteExercise(dip.id);
        // What the 90-day purge will do once sync exists.
        await (env.db.delete(
          env.db.exerciseMuscles,
        )..where((t) => t.exerciseId.equals(dip.id))).go();
        await (env.db.delete(
          env.db.exercises,
        )..where((t) => t.id.equals(dip.id))).go();
        await env.seed.importJson(
          _seed(2, [_exercise('bench'), _exercise('fly'), _exercise('dip')]),
        );
        final keys = (await env.catalogue.getExercises()).map((e) => e.seedKey);
        expect(keys, isNot(contains('dip')));
      },
    );

    test('keeps a renamed or hidden muscle as the user left it', () async {
      final muscles = await env.catalogue.getMuscles();
      final chest = muscles.firstWhere((m) => m.seedKey == 'chest');
      await env.catalogue.renameMuscle(chest.id, 'Pecs');
      await env.seed.importJson(
        jsonEncode({
          'version': 2,
          'muscles': [
            {'key': 'chest', 'name': 'Chest (seed rename)'},
            {'key': 'triceps', 'name': 'Tris'},
            {'key': 'back', 'name': 'Back'},
          ],
          'exercises': [
            _exercise('bench'),
            _exercise('row', primary: ['back']),
          ],
        }),
      );
      final after = await env.catalogue.getMuscles();
      expect(after.map((m) => m.name), ['Pecs', 'Tris', 'Back']);
    });

    test("keeps the user's own exercises, notes and plans untouched", () async {
      final own = await env.exercise('My cable thing');
      final bench = await byKey('bench');
      await env.catalogue.saveNote(bench.id, 'seat 4, pin 7');
      await env.seed.importJson(
        _seed(2, [_exercise('bench', name: 'Bench v2'), _exercise('fly')]),
      );
      expect((await env.catalogue.getExercise(own))!.name, 'My cable thing');
      expect((await env.catalogue.getNotes())[bench.id], 'seat 4, pin 7');
      // "dip" left the seed: the row stays (never deleted by an import).
      expect((await byKey('dip')).name, 'Exercise dip');
    });

    test('an older or equal version is ignored', () async {
      expect(
        await env.seed.importJson(_seed(1, [_exercise('other')])),
        isFalse,
      );
      expect(await env.catalogue.getExercises(), hasLength(3));
    });
  });

  test(
    'a seed with a broken reference is rejected and imports nothing',
    () async {
      final broken = _seed(1, [
        _exercise('curl', primary: ['biceps']),
      ]);
      await expectLater(
        env.seed.importJson(broken),
        throwsA(isA<SeedFormatException>()),
      );
      expect(await env.catalogue.getExercises(), isEmpty);
    },
  );
}
