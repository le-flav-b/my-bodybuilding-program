import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';

import '../helpers/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('muscles', () {
    test('add, rename and hide keep a stable id', () async {
      final id = await env.catalogue.addMuscle('  Neck ');
      await env.catalogue.renameMuscle(id, 'Neck & traps');
      await env.catalogue.setMuscleHidden(id, hidden: true);
      final muscle = (await env.catalogue.getMuscles()).single;
      expect(muscle.id, id);
      expect(muscle.name, 'Neck & traps');
      expect(muscle.hidden, isTrue);
      expect(muscle.userModified, isTrue);
    });

    test('new muscles go after the existing ones', () async {
      final a = await env.catalogue.addMuscle('A');
      final b = await env.catalogue.addMuscle('B');
      expect((await env.catalogue.getMuscles()).map((m) => m.id), [a, b]);
    });

    test('a muscle in use cannot be deleted, only hidden', () async {
      final chest = await env.catalogue.addMuscle('Chest');
      final unused = await env.catalogue.addMuscle('Unused');
      await env.exercise('Bench', primary: [chest]);
      expect(await env.catalogue.exerciseCountByMuscle(), {chest: 1});
      await expectLater(
        env.catalogue.deleteMuscle(chest),
        throwsA(isA<InUseException>()),
      );
      await env.catalogue.deleteMuscle(unused);
      expect((await env.catalogue.getMuscles()).map((m) => m.id), [chest]);
    });
  });

  group('exercises', () {
    test('creates one of my own exercises with muscles and a photo', () async {
      final chest = await env.catalogue.addMuscle('Chest');
      final triceps = await env.catalogue.addMuscle('Triceps');
      final id = await env.catalogue.createExercise(
        ExerciseDraft(
          name: ' Cable press ',
          description: 'Slow.',
          measure: Measure.reps,
          image: const UserImage('abc.jpg'),
          primaryMuscleIds: [chest],
          secondaryMuscleIds: [triceps],
        ),
      );
      final exercise = (await env.catalogue.getExercise(id))!;
      expect(exercise.name, 'Cable press');
      expect(exercise.image, const UserImage('abc.jpg'));
      expect(exercise.primaryMuscleIds, [chest]);
      expect(exercise.secondaryMuscleIds, [triceps]);
      expect(exercise.isSeeded, isFalse);
      expect(exercise.mainMuscleId, chest);
    });

    test('editing rewrites the muscles without leaving duplicates', () async {
      final a = await env.catalogue.addMuscle('A');
      final b = await env.catalogue.addMuscle('B');
      final c = await env.catalogue.addMuscle('C');
      final id = await env.catalogue.createExercise(
        ExerciseDraft(
          name: 'X',
          measure: Measure.reps,
          primaryMuscleIds: [a],
          secondaryMuscleIds: [b, c],
        ),
      );
      await env.catalogue.updateExercise(
        id,
        ExerciseDraft(
          name: 'X2',
          measure: Measure.time,
          primaryMuscleIds: [c, a],
        ),
      );
      final exercise = (await env.catalogue.getExercise(id))!;
      expect(exercise.name, 'X2');
      expect(exercise.measure, Measure.time);
      expect(exercise.primaryMuscleIds, [c, a]);
      expect(exercise.secondaryMuscleIds, isEmpty);
      expect(await env.catalogue.exerciseCountByMuscle(), {a: 1, c: 1});
      // Three link rows were created, none added by the edit.
      expect(await env.db.select(env.db.exerciseMuscles).get(), hasLength(3));
    });

    test('archive hides and restore brings back', () async {
      final id = await env.exercise('Bench');
      await env.catalogue.archiveExercise(id);
      expect((await env.catalogue.getExercise(id))!.isArchived, isTrue);
      await env.catalogue.restoreExercise(id);
      expect((await env.catalogue.getExercise(id))!.isArchived, isFalse);
    });

    test('an exercise never done can be deleted, also from sessions', () async {
      final bench = await env.exercise('Bench');
      final fly = await env.exercise('Fly');
      final session = await env.session('Push', [
        PlannedExercise(
          exerciseId: bench,
          restSeconds: 90,
          sets: sets(3, SetTarget.defaultReps),
        ),
        PlannedExercise(
          exerciseId: fly,
          restSeconds: 60,
          sets: sets(2, const SetTarget(reps: 12)),
        ),
      ]);
      await env.catalogue.deleteExercise(fly);
      final plan = (await env.program.getSessionPlan(session))!;
      expect(plan.exercises.map((e) => e.exerciseId), [bench]);
      expect(await env.catalogue.getExercise(fly), isNull);
    });

    test('an exercise with history can only be archived', () async {
      final bench = await env.exercise('Bench');
      final session = await env.session('Push', [
        PlannedExercise(
          exerciseId: bench,
          restSeconds: 90,
          sets: sets(1, SetTarget.defaultReps),
        ),
      ]);
      final workout = await env.startFromSession(session);
      await env.logEverything(workout);
      await env.workouts.finish(workout);

      expect(await env.catalogue.exerciseHasHistory(bench), isTrue);
      await expectLater(
        env.catalogue.deleteExercise(bench),
        throwsA(isA<InUseException>()),
      );
      await env.catalogue.archiveExercise(bench);
      // History still shows it.
      expect((await env.history.getLoggedSets()).single.exerciseId, bench);
    });

    test('a discarded workout does not count as history', () async {
      final bench = await env.exercise('Bench');
      final session = await env.session('Push', [
        PlannedExercise(
          exerciseId: bench,
          restSeconds: 90,
          sets: sets(1, SetTarget.defaultReps),
        ),
      ]);
      final workout = await env.startFromSession(session);
      await env.workouts.discard(workout);
      expect(await env.catalogue.exerciseHasHistory(bench), isFalse);
    });

    test('watchExercises emits on changes', () async {
      final names = <List<String>>[];
      final sub = env.catalogue.watchExercises().listen(
        (list) => names.add([for (final e in list) e.name]),
      );
      await pumpEventQueue();
      await env.exercise('Bench');
      await pumpEventQueue();
      await sub.cancel();
      expect(names.first, isEmpty);
      expect(names.last, ['Bench']);
    });
  });

  group('personal notes', () {
    test('are separate from the catalogue entry', () async {
      final id = await env.exercise('Leg press');
      await env.catalogue.saveNote(id, ' seat 4, pin 7 ');
      expect(await env.catalogue.getNotes(), {id: 'seat 4, pin 7'});

      // Editing the catalogue entry never touches the notes…
      await env.catalogue.updateExercise(
        id,
        const ExerciseDraft(name: 'Leg press 45°', measure: Measure.reps),
      );
      expect(await env.catalogue.getNotes(), {id: 'seat 4, pin 7'});

      // …and editing the notes never touches the entry.
      await env.catalogue.saveNote(id, 'seat 5');
      final exercise = (await env.catalogue.getExercise(id))!;
      expect(exercise.name, 'Leg press 45°');
      expect(await env.catalogue.getNotes(), {id: 'seat 5'});
      expect(await env.db.select(env.db.exerciseNotes).get(), hasLength(1));
    });

    test('an emptied note disappears', () async {
      final id = await env.exercise('Leg press');
      await env.catalogue.saveNote(id, 'x');
      await env.catalogue.saveNote(id, '  ');
      expect(await env.catalogue.getNotes(), isEmpty);
    });
  });

  group('load units', () {
    const levelDraft = LoadUnitDraft(name: 'level', step: 1, decimals: 0);

    test('custom units are listed after kg', () async {
      final id = await env.units.createUnit(levelDraft);
      final units = await env.units.getUnits();
      expect(units.map((u) => u.name), ['kg', 'level']);
      expect(units.last.id, id);
      expect(units.last.step, 1);
      expect(units.last.decimals, 0);
    });

    test('kg is locked', () async {
      await expectLater(
        env.units.updateUnit(kgId, levelDraft),
        throwsA(isA<InUseException>()),
      );
      await expectLater(
        env.units.archiveUnit(kgId),
        throwsA(isA<InUseException>()),
      );
      await expectLater(
        env.units.deleteUnit(kgId),
        throwsA(isA<InUseException>()),
      );
    });

    test('an invalid unit is rejected', () async {
      await expectLater(
        env.units.createUnit(
          const LoadUnitDraft(name: '', step: 1, decimals: 0),
        ),
        throwsArgumentError,
      );
    });

    test('edit, archive and restore a custom unit', () async {
      final id = await env.units.createUnit(levelDraft);
      await env.units.updateUnit(
        id,
        const LoadUnitDraft(name: 'plate', step: 0.5, decimals: 1),
      );
      await env.units.archiveUnit(id);
      var unit = (await env.units.getUnits()).last;
      expect(unit.name, 'plate');
      expect(unit.isArchived, isTrue);
      await env.units.restoreUnit(id);
      unit = (await env.units.getUnits()).last;
      expect(unit.isArchived, isFalse);
    });

    test('a unit in use is counted and cannot be deleted', () async {
      final unit = await env.units.createUnit(levelDraft);
      final unused = await env.units.createUnit(
        const LoadUnitDraft(name: 'plate', step: 1, decimals: 0),
      );
      final press = await env.exercise('Leg press');
      final curl = await env.exercise('Leg curl');
      await env.session('Legs', [
        PlannedExercise(
          exerciseId: press,
          restSeconds: 90,
          sets: sets(3, SetTarget(reps: 10, load: 6, unitId: unit)),
        ),
        PlannedExercise(
          exerciseId: curl,
          restSeconds: 90,
          sets: sets(3, SetTarget(reps: 10, load: 4, unitId: unit)),
        ),
      ]);
      expect((await env.units.usageByUnit())[unit], 2);
      await expectLater(
        env.units.deleteUnit(unit),
        throwsA(isA<InUseException>()),
      );
      await env.units.deleteUnit(unused);
      expect((await env.units.getUnits()).map((u) => u.name), ['kg', 'level']);
    });
  });

  group('settings', () {
    test('start with the defaults of the spec', () async {
      expect(await env.settings.getSettings(), const AppSettings());
    });

    test('are stored and read back', () async {
      await env.settings.setThemeMode(AppThemeMode.dark);
      await env.settings.setDefaultRestSeconds(120);
      await env.settings.setTimerSound(enabled: false);
      await env.settings.setTimerVibration(enabled: false);
      await env.settings.setKeepScreenOn(enabled: false);
      await env.settings.setWeeklyTarget(4);
      await env.settings.setWeeklyTarget(5);
      expect(
        await env.settings.getSettings(),
        const AppSettings(
          themeMode: AppThemeMode.dark,
          defaultRestSeconds: 120,
          timerSound: false,
          timerVibration: false,
          keepScreenOn: false,
          weeklyTarget: 5,
        ),
      );
    });

    test('values are clamped to their range', () async {
      await env.settings.setWeeklyTarget(40);
      await env.settings.setDefaultRestSeconds(-5);
      final settings = await env.settings.getSettings();
      expect(settings.weeklyTarget, 7);
      expect(settings.defaultRestSeconds, 0);
    });

    test('watchSettings emits on change', () async {
      final seen = <AppThemeMode>[];
      final sub = env.settings.watchSettings().listen(
        (s) => seen.add(s.themeMode),
      );
      await pumpEventQueue();
      await env.settings.setThemeMode(AppThemeMode.light);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [AppThemeMode.system, AppThemeMode.light]);
    });
  });

  group('bodyweight', () {
    test('add, edit and delete entries, newest first', () async {
      final first = await env.bodyWeights.addEntry(
        measuredAt: DateTime.utc(2026, 11, 1, 7),
        weightKg: 80,
      );
      final second = await env.bodyWeights.addEntry(
        measuredAt: DateTime.utc(2026, 11, 8, 7),
        weightKg: 79.4,
        note: ' after holidays ',
      );
      var entries = await env.bodyWeights.getEntries();
      expect(entries.map((e) => e.id), [second, first]);
      expect(entries.first.note, 'after holidays');
      expect(BodyWeightTrend.changeOver(entries, days: 7), -0.6);

      await env.bodyWeights.updateEntry(
        first,
        measuredAt: DateTime.utc(2026, 11, 1, 7),
        weightKg: 80.5,
        note: '',
      );
      await env.bodyWeights.deleteEntry(second);
      entries = await env.bodyWeights.getEntries();
      expect(entries.single.weightKg, 80.5);
      expect(entries.single.note, isNull);
    });
  });
}
