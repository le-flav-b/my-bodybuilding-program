import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_list.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/settings/data/units_repository.dart';

import '../helpers/demo_data.dart';
import '../helpers/test_app.dart';

void main() {
  late TestApp app;

  Future<DemoData> start(WidgetTester tester, {bool demo = true}) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    app = TestApp();
    await app.pump(tester);
    final data = DemoData(app.container);
    if (demo) {
      await tester.runAsync(data.create);
      await app.settle(tester);
    }
    return data;
  }

  Future<void> go(WidgetTester tester, String location) async {
    app.container.read(routerProvider).push(location).ignore();
    await app.settle(tester);
  }

  Future<T> db<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await app.settle(tester);
  }

  group('Program tab', () {
    testWidgets('lists the loop with the next session marked', (tester) async {
      await start(tester);
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(Strings.tabProgram),
        ),
      );
      expect(find.text('Pull A'), findsOneWidget);
      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text(Strings.programNext.toUpperCase()), findsOneWidget);
      expect(find.text(Strings.programLoop(3).toUpperCase()), findsOneWidget);
      expect(
        find.text(Strings.programLoopNote('Legs', 'Pull A')),
        findsOneWidget,
      );
      expect(find.text(Strings.programCatalogueCount(82)), findsOneWidget);
    });

    testWidgets('Create your first session opens its editor', (tester) async {
      await start(tester, demo: false);
      await tapAndSettle(tester, find.text(Strings.todayCreateFirstSession));
      await tester.enterText(find.byType(TextField), 'Full body');
      await tester.pump();
      await tapAndSettle(tester, find.text(Strings.create));
      expect(find.text(Strings.editSession), findsOneWidget);
      final overview = await db(
        tester,
        app.container.read(programRepositoryProvider).getOverview,
      );
      expect(overview.sessions.single.session.name, 'Full body');
      expect(overview.nextSessionId, overview.sessions.single.session.id);
    });
  });

  group('Session editor', () {
    Future<List<PlannedExercise>> planOf(
      WidgetTester tester,
      String id,
    ) async => (await db(
      tester,
      () => app.container.read(programRepositoryProvider).getSessionPlan(id),
    ))!.toPlan();

    testWidgets('shows each exercise with its summary', (tester) async {
      final demo = await start(tester);
      await go(tester, Routes.session(demo.pushId));
      expect(find.text('Barbell bench press'), findsOneWidget);
      expect(find.text('4 × 10 · 40 kg · rest 2:00'), findsOneWidget);
      expect(find.text('12, 10, 8 · 5–7 level · rest 1:30'), findsOneWidget);
      expect(find.text('3 × 0:45 · rest 1:00'), findsOneWidget);
    });

    testWidgets('renames the session', (tester) async {
      final demo = await start(tester);
      await go(tester, Routes.session(demo.pushId));
      await tester.enterText(find.byType(TextField).first, 'Push B');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await app.settle(tester);
      final plan = await db(
        tester,
        () => app.container
            .read(programRepositoryProvider)
            .getSessionPlan(demo.pushId),
      );
      expect(plan!.session.name, 'Push B');
    });

    testWidgets('expands a card, adds and removes sets', (tester) async {
      final demo = await start(tester);
      await go(tester, Routes.session(demo.pushId));
      await tapAndSettle(tester, find.text('Barbell bench press'));
      expect(find.text(Strings.addSet), findsOneWidget);
      expect(find.text('40'), findsNWidgets(4));

      await tapAndSettle(tester, find.text(Strings.addSet));
      var plan = await planOf(tester, demo.pushId);
      expect(plan.first.sets, hasLength(5));
      // "Add set" copies the previous one.
      expect(plan.first.sets.last, plan.first.sets.first);

      await tapAndSettle(tester, find.byTooltip(Strings.removeSet).first);
      plan = await planOf(tester, demo.pushId);
      expect(plan.first.sets, hasLength(4));
    });

    testWidgets('edits a target and a load with the dialogs', (tester) async {
      final demo = await start(tester);
      await go(tester, Routes.session(demo.pushId));
      await tapAndSettle(tester, find.text('Barbell bench press'));

      await tapAndSettle(
        tester,
        find.bySemanticsLabel('${Strings.targetReps}: 10').first,
      );
      await tapAndSettle(tester, find.byTooltip('+1'));
      await tapAndSettle(tester, find.text(Strings.ok));
      var plan = await planOf(tester, demo.pushId);
      expect(plan.first.sets.first.reps, 11);

      await tapAndSettle(
        tester,
        find.bySemanticsLabel('${Strings.load}: 40').first,
      );
      await tapAndSettle(tester, find.byTooltip('+0.5'));
      await tapAndSettle(tester, find.text(Strings.ok));
      plan = await planOf(tester, demo.pushId);
      expect(plan.first.sets.first.load, 40.5);
      expect(plan.first.sets.first.unitId, FixedIds.kgUnit);

      // A set can be made "max" and bodyweight.
      await tapAndSettle(
        tester,
        find.bySemanticsLabel('${Strings.targetReps}: 10').first,
      );
      await tapAndSettle(tester, find.byType(Switch));
      await tapAndSettle(tester, find.text(Strings.ok));
      await tapAndSettle(
        tester,
        find.bySemanticsLabel('${Strings.load}: 40').first,
      );
      await tapAndSettle(tester, find.text(Strings.noLoad));
      plan = await planOf(tester, demo.pushId);
      expect(plan.first.sets[1], const SetTarget(isMax: true));
    });

    testWidgets('changes the rest time', (tester) async {
      final demo = await start(tester);
      await go(tester, Routes.session(demo.pushId));
      await tapAndSettle(tester, find.text('Barbell bench press'));
      await tapAndSettle(tester, find.text(Strings.restChip('2:00')));
      await tapAndSettle(tester, find.text('3:00'));
      await tapAndSettle(tester, find.text(Strings.ok));
      final plan = await planOf(tester, demo.pushId);
      expect(plan.first.restSeconds, 180);
    });

    testWidgets('adds an exercise from the picker', (tester) async {
      final demo = await start(tester);
      await go(tester, Routes.session(demo.legsId));
      await tester.scrollUntilVisible(
        find.text(Strings.addExercise),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapAndSettle(tester, find.text(Strings.addExercise));
      await tester.enterText(
        find.descendant(
          of: find.byType(CatalogueList),
          matching: find.byType(TextField),
        ),
        'hip thrust',
      );
      await tester.pump();
      await app.settle(tester);
      await tapAndSettle(tester, find.text('Hip thrust'));
      final plan = await planOf(tester, demo.legsId);
      expect(plan, hasLength(6));
      expect(plan.last.exerciseId, demo.ex('hip_thrust'));
      expect(plan.last.sets, List.filled(3, SetTarget.defaultReps));
      expect(plan.last.restSeconds, 90);
    });

    testWidgets('removes an exercise and deletes the session', (tester) async {
      final demo = await start(tester);
      await go(tester, Routes.session(demo.legsId));
      await tapAndSettle(tester, find.text('Back squat'));
      await tapAndSettle(tester, find.byTooltip(Strings.removeExercise));
      expect(await planOf(tester, demo.legsId), hasLength(4));

      await tapAndSettle(tester, find.byTooltip(Strings.more));
      await tapAndSettle(tester, find.text(Strings.deleteSession));
      await tapAndSettle(tester, find.text(Strings.delete));
      final overview = await db(
        tester,
        app.container.read(programRepositoryProvider).getOverview,
      );
      expect(overview.sessions.map((s) => s.session.name), [
        'Pull A',
        'Push A',
      ]);
      expect(find.text(Strings.editSession), findsNothing);
    });
  });

  group('Catalogue', () {
    testWidgets('searches and filters by muscle', (tester) async {
      await start(tester, demo: false);
      await go(tester, Routes.exercises);
      expect(find.text(Strings.searchExercises(82)), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'curl');
      await tester.pump();
      await app.settle(tester);
      expect(find.text('Barbell curl'), findsOneWidget);
      expect(find.text('Back squat'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await app.settle(tester);
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Back'));
      final rows = tester.widgetList<CatalogueRow>(find.byType(CatalogueRow));
      expect(rows, isNotEmpty);
      final calves = (await db(
        tester,
        app.container.read(catalogueRepositoryProvider).getMuscles,
      )).firstWhere((m) => m.name == 'Back');
      expect(rows.every((r) => r.exercise.targets(calves.id)), isTrue);
    });

    testWidgets('no match offers to create the exercise', (tester) async {
      await start(tester, demo: false);
      await go(tester, Routes.exercises);
      await tester.enterText(find.byType(TextField), 'Sled push');
      await tester.pump();
      await app.settle(tester);
      expect(find.text(Strings.noExerciseMatches('Sled push')), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.createNamed('Sled push')));
      expect(find.text(Strings.newExercise), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Sled push'), findsOneWidget);
    });

    testWidgets('creates an exercise with primary and secondary muscles', (
      tester,
    ) async {
      await start(tester, demo: false);
      await go(tester, Routes.newExercise());
      await tester.enterText(
        find.widgetWithText(TextField, Strings.exerciseName),
        'Sled push',
      );
      await tester.pump();
      await tapAndSettle(tester, find.text('Time'));
      await tapAndSettle(tester, find.text('Quads'));
      await tapAndSettle(tester, find.text('Glutes'));
      await tapAndSettle(tester, find.text('Glutes'));
      await tapAndSettle(tester, find.text(Strings.save));

      final exercises = await db(
        tester,
        app.container.read(catalogueRepositoryProvider).getExercises,
      );
      final created = exercises.firstWhere((e) => e.name == 'Sled push');
      final muscles = {
        for (final m in await db(
          tester,
          app.container.read(catalogueRepositoryProvider).getMuscles,
        ))
          m.id: m.name,
      };
      expect(created.measure, Measure.time);
      expect(created.primaryMuscleIds.map((id) => muscles[id]), ['Quads']);
      expect(created.secondaryMuscleIds.map((id) => muscles[id]), ['Glutes']);
      expect(find.text(Strings.newExercise), findsNothing);
    });

    testWidgets('detail edits my notes in place', (tester) async {
      final demo = await start(tester);
      final id = demo.ex('leg_extension');
      await go(tester, Routes.exercise(id));
      expect(find.text('Leg extension'), findsOneWidget);
      await tapAndSettle(tester, find.byTooltip(Strings.editNotes));
      await tester.enterText(find.byType(TextField), 'seat 4, pin 7');
      await tester.pump();
      await tapAndSettle(tester, find.byTooltip(Strings.save));
      expect(find.text('seat 4, pin 7'), findsOneWidget);
      final notes = await db(
        tester,
        app.container.read(catalogueRepositoryProvider).getNotes,
      );
      expect(notes[id], 'seat 4, pin 7');
    });

    testWidgets('a never-used exercise can be deleted', (tester) async {
      final demo = await start(tester);
      final id = demo.ex('wrist_curl');
      await go(tester, Routes.exercise(id));
      await tapAndSettle(tester, find.byTooltip(Strings.editExercise));
      expect(find.text(Strings.neverUsedCanDelete), findsOneWidget);
      await tester.ensureVisible(find.text(Strings.delete));
      await app.settle(tester);
      await tapAndSettle(tester, find.text(Strings.delete));
      await tapAndSettle(
        tester,
        find.widgetWithText(TextButton, Strings.delete).last,
      );
      final exercise = await db(
        tester,
        () => app.container.read(catalogueRepositoryProvider).getExercise(id),
      );
      expect(exercise, isNull);
    });

    testWidgets('a planned exercise keeps its measure', (tester) async {
      final demo = await start(tester);
      await go(tester, Routes.editExercise(demo.ex('plank')));
      expect(find.text(Strings.measureLocked), findsOneWidget);
    });
  });

  group('Settings', () {
    testWidgets('opens from the Profile gear', (tester) async {
      await start(tester, demo: false);
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(Strings.tabProfile),
        ),
      );
      await tapAndSettle(tester, find.byTooltip(Strings.settings));
      expect(find.text(Strings.loadUnits), findsOneWidget);
      expect(find.text(Strings.muscles), findsOneWidget);
    });

    testWidgets('adds a load unit with a live preview', (tester) async {
      await start(tester, demo: false);
      await go(tester, Routes.loadUnits);
      expect(find.byIcon(Symbols.lock_rounded), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.addUnit));
      await tester.enterText(
        find.widgetWithText(TextField, Strings.unitName),
        'level',
      );
      await tester.pump();
      await app.settle(tester);
      expect(find.text(Strings.unitPreview('5 → 6 → 7 level')), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.save));
      final units = await db(
        tester,
        app.container.read(unitsRepositoryProvider).getUnits,
      );
      expect(units.map((u) => u.name), ['kg', 'level']);
      expect(find.text('level'), findsOneWidget);
    });

    testWidgets('an unused unit is deleted, a used one archived', (
      tester,
    ) async {
      final demo = await start(tester);
      await go(tester, Routes.loadUnits);
      // "plates" is not used: Delete.
      await tapAndSettle(tester, find.byTooltip(Strings.editUnit).last);
      await tapAndSettle(tester, find.text(Strings.delete));
      // "level" is used: Archive.
      await tapAndSettle(tester, find.byTooltip(Strings.editUnit).last);
      await tapAndSettle(tester, find.text(Strings.archive));
      final units = await db(
        tester,
        app.container.read(unitsRepositoryProvider).getUnits,
      );
      expect(units.map((u) => u.name), ['kg', 'level']);
      expect(units.last.id, demo.levelUnitId);
      expect(units.last.isArchived, isTrue);
      expect(find.text(Strings.restore), findsOneWidget);
    });

    testWidgets('adds, renames and hides muscles', (tester) async {
      await start(tester, demo: false);
      await go(tester, Routes.muscles);
      await tapAndSettle(tester, find.text(Strings.addMuscle));
      await tester.enterText(find.byType(TextField), 'Neck');
      await tester.pump();
      await tapAndSettle(tester, find.text(Strings.add));
      await tester.scrollUntilVisible(
        find.text('Neck'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(Strings.exerciseCount(0)), findsOneWidget);

      // Calves is used: its dialog offers Hide.
      await tester.scrollUntilVisible(
        find.text('Calves'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      final calvesTile = find.ancestor(
        of: find.text('Calves'),
        matching: find.byType(ListTile),
      );
      await tapAndSettle(
        tester,
        find.descendant(of: calvesTile, matching: find.byType(IconButton)),
      );
      await tester.enterText(find.byType(TextField), 'Calf');
      await tester.pump();
      await tapAndSettle(tester, find.text(Strings.save));
      expect(find.text('Calf'), findsOneWidget);

      final muscles = await db(
        tester,
        app.container.read(catalogueRepositoryProvider).getMuscles,
      );
      expect(muscles.map((m) => m.name), contains('Calf'));
      expect(muscles.last.name, 'Neck');
    });
  });
}
