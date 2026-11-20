import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/bootstrap.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/core/notifications/workout_notifier.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/progress/data/history_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/bests.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';

import '../helpers/demo_data.dart';
import '../helpers/test_app.dart';
import '../helpers/workout_data.dart';

void main() {
  late TestApp app;
  late DemoData demo;
  late WorkoutData data;

  Future<void> start(
    WidgetTester tester, {
    bool program = true,
    bool history = true,
    Future<void> Function()? beforeLaunch,
  }) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    app = TestApp();
    demo = DemoData(app.container);
    data = WorkoutData(app, demo);
    if (beforeLaunch != null) {
      // Set up the database before the first screen (resume at launch).
      await tester.runAsync(
        () => app.container.read(appBootstrapProvider.future),
      );
      await tester.runAsync(demo.create);
      await tester.runAsync(beforeLaunch);
      await app.pump(tester);
      return;
    }
    await app.pump(tester);
    if (program) {
      await tester.runAsync(demo.create);
      await app.settle(tester);
      if (history) {
        await tester.runAsync(data.pastWorkouts);
        await app.settle(tester);
      }
    }
  }

  /// Runs database work for real, then lets the UI catch up (a write run
  /// while widget queries are pending in the fake zone would deadlock).
  Future<T> db<T>(WidgetTester tester, Future<T> Function() f) async {
    final result = (await tester.runAsync(f)) as T;
    await app.settle(tester);
    return result;
  }

  Future<void> go(WidgetTester tester, String location) async {
    app.container.read(routerProvider).push(location).ignore();
    await app.settle(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await app.settle(tester);
  }

  WorkoutRepository workouts() => app.container.read(workoutRepositoryProvider);

  Future<WorkoutDetail?> active(WidgetTester tester) =>
      db(tester, () => workouts().getInProgress());

  /// Today → Start → preview → Start workout → player.
  Future<void> startPushFromToday(WidgetTester tester) async {
    await tapAndSettle(tester, find.text(Strings.start));
    expect(find.text(Strings.previewInfo), findsOneWidget);
    await tapAndSettle(tester, find.text(Strings.startWorkout));
  }

  group('Today', () {
    testWidgets('normal: next session card with Start', (tester) async {
      await start(tester);
      expect(find.text('Push A'), findsWidgets);
      expect(find.text(Strings.start), findsOneWidget);
      expect(find.text(Strings.otherSession), findsOneWidget);
    });

    testWidgets('empty program: welcome', (tester) async {
      await start(tester, program: false);
      expect(find.text(Strings.todayWelcomeTitle), findsOneWidget);
      expect(find.text(Strings.todayCreateFirstSession), findsOneWidget);
      // v1.0.1: no illustration, no example in the text.
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Symbols.fitness_center_rounded), findsWidgets);
      expect(find.textContaining('Push'), findsNothing);
      // The new-session name field has no example either.
      await tester.tap(find.text(Strings.todayCreateFirstSession));
      await app.settle(tester);
      expect(find.text(Strings.newSessionTitle), findsOneWidget);
      expect(find.textContaining('e.g.'), findsNothing);
    });

    testWidgets('in progress: resume banner opens the player', (tester) async {
      await start(tester);
      final id = await db(tester, data.startPush);
      await db(tester, () => data.logFirstSets(id, 1));
      await app.settle(tester);
      expect(
        find.text(Strings.upNextIn('Push A').toUpperCase()),
        findsOneWidget,
      );
      await tapAndSettle(tester, find.text('Push A').first);
      expect(find.byTooltip(Strings.leaveWorkout), findsOneWidget);
    });
  });

  group('Player', () {
    testWidgets('logs a set in one tap and starts the rest', (tester) async {
      await start(tester);
      await startPushFromToday(tester);
      expect(find.text('Barbell bench press'), findsWidgets);
      expect(find.text(Strings.target('10 × 40 kg')), findsOneWidget);
      // The setup note and last time.
      expect(find.textContaining('Bench 3rd hole'), findsOneWidget);
      expect(find.text(Strings.lastLong('10 × 40 kg')), findsOneWidget);

      await tapAndSettle(tester, find.text(Strings.done));
      final detail = (await active(tester))!;
      final set = detail.exercises.first.sets.first;
      expect(set.isDone, isTrue);
      expect(set.reps, 10);
      expect(set.load, 40);
      expect(detail.workout.isResting, isTrue);
      expect(find.text(Strings.restLabel.toUpperCase()), findsOneWidget);
      expect(find.text('2:00'), findsOneWidget);
      expect(app.notifier.status, isA<RestNotice>());

      // Skip → back to the sets, set 2 is current.
      await tapAndSettle(tester, find.text(Strings.skip));
      expect((await active(tester))!.workout.isResting, isFalse);
      expect(find.text(Strings.done), findsOneWidget);
    });

    testWidgets('changed values are logged; a record shows the trophy', (
      tester,
    ) async {
      await start(tester);
      await startPushFromToday(tester);
      await tester.tap(find.byTooltip('${Strings.reps} −'));
      await tester.tap(find.byTooltip('${Strings.load} +'));
      await tester.pump();
      await tapAndSettle(tester, find.text(Strings.done));
      final set = (await active(tester))!.exercises.first.sets.first;
      expect(set.reps, 9);
      expect(set.load, 40.5);
      expect(find.text(Strings.newBest.toUpperCase()), findsOneWidget);
      expect(find.text('40.5 kg × 9'), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.nice));
      expect(find.text(Strings.newBest.toUpperCase()), findsNothing);
    });

    testWidgets('the rest timer ends by itself with a beep', (tester) async {
      await start(tester);
      await startPushFromToday(tester);
      await tapAndSettle(tester, find.text(Strings.done));
      await tapAndSettle(tester, find.text('+15'));
      expect(find.text('2:15'), findsOneWidget);
      app.clock.advance(const Duration(seconds: 136));
      await tester.pump(const Duration(seconds: 136));
      await app.settle(tester);
      expect((await active(tester))!.workout.isResting, isFalse);
      expect(app.feedback.beeps, 1);
      expect(app.feedback.vibrations, 1);
      expect(find.text(Strings.done), findsOneWidget);
    });

    testWidgets('timed set: lead-in, countdown, logged at zero', (
      tester,
    ) async {
      await start(tester);
      final id = await db(tester, data.startPush);
      await db(tester, () => data.goToPlank(id));
      await go(tester, Routes.workout);
      expect(find.text('Plank'), findsWidgets);
      await tester.tap(find.text(Strings.start));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(Strings.getReady.toUpperCase()), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        app.clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text(Strings.hold.toUpperCase()), findsOneWidget);
      expect(find.text('0:45'), findsWidgets);
      app.clock.advance(const Duration(seconds: 45));
      await tester.pump(const Duration(milliseconds: 200));
      await app.settle(tester);
      final plank = (await active(tester))!.exercises
          .firstWhere((e) => e.exerciseId == demo.ex('plank'));
      expect(plank.sets[1].isDone, isTrue);
      expect(plank.sets[1].seconds, 45);
      expect(app.feedback.ticks, greaterThanOrEqualTo(3));
      expect(app.feedback.beeps, greaterThanOrEqualTo(2));
    });

    testWidgets('timed set: Stop logs the time held', (tester) async {
      await start(tester);
      final id = await db(tester, data.startPush);
      await db(tester, () => data.goToPlank(id));
      await go(tester, Routes.workout);
      await tester.tap(find.text(Strings.start));
      app.clock.advance(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 200));
      app.clock.advance(const Duration(seconds: 20));
      await tester.pump(const Duration(milliseconds: 200));
      await tapAndSettle(tester, find.text(Strings.stop));
      final plank = (await active(tester))!.exercises
          .firstWhere((e) => e.exerciseId == demo.ex('plank'));
      expect(plank.sets[1].seconds, 20);
    });

    testWidgets('pause freezes the workout and resumes', (tester) async {
      await start(tester);
      await startPushFromToday(tester);
      await tapAndSettle(tester, find.byTooltip(Strings.pause));
      expect(find.text(Strings.paused.toUpperCase()), findsOneWidget);
      expect((await active(tester))!.workout.isPaused, isTrue);
      expect(app.notifier.status, isA<PausedNotice>());
      await tapAndSettle(tester, find.text(Strings.resume));
      expect((await active(tester))!.workout.isPaused, isFalse);
    });

    testWidgets('swap from the ⋮ menu keeps the logged sets', (tester) async {
      await start(tester);
      await startPushFromToday(tester);
      await tapAndSettle(tester, find.text(Strings.done));
      await tapAndSettle(tester, find.text(Strings.skip));
      await tapAndSettle(tester, find.byIcon(Symbols.more_vert_rounded).first);
      await tapAndSettle(tester, find.text(Strings.swap).last);
      expect(find.text(Strings.swapExercise), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Dumbbell bench');
      await app.settle(tester);
      await tapAndSettle(tester, find.text('Dumbbell bench press').last);
      final detail = (await active(tester))!;
      expect(detail.exercises.first.exerciseId, demo.ex('barbell_bench_press'));
      expect(detail.exercises.first.doneCount, 1);
      expect(detail.exercises[1].exerciseId, demo.ex('dumbbell_bench_press'));
      expect(detail.currentExercise!.id, detail.exercises[1].id);
      expect(find.text('Dumbbell bench press'), findsWidgets);
    });

    testWidgets('leave: discard returns to Today with nothing saved', (
      tester,
    ) async {
      await start(tester);
      await startPushFromToday(tester);
      await tapAndSettle(tester, find.text(Strings.done));
      await tapAndSettle(tester, find.byTooltip(Strings.leaveWorkout));
      expect(find.text(Strings.leaveTitle), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.discardWorkout));
      expect(await active(tester), isNull);
      expect(find.text(Strings.start), findsOneWidget);
      expect(app.notifier.status, isNull);
    });
  });

  group('List view and summary', () {
    testWidgets('list shows the statuses and the menu', (tester) async {
      await start(tester);
      final id = await db(tester, data.startPush);
      await db(tester, () => data.listState(id));
      await go(tester, Routes.workout);
      await go(tester, Routes.workoutList);
      expect(find.text(Strings.exercisesOf('Push A')), findsOneWidget);
      expect(find.text(Strings.skippedLabel), findsOneWidget);
      await tapAndSettle(tester, find.text('Leg curl'));
      await tapAndSettle(tester, find.text(Strings.goToExercise));
      final detail = (await active(tester))!;
      expect(detail.currentExercise!.exerciseId, demo.ex('leg_curl'));
      expect(find.byTooltip(Strings.leaveWorkout), findsOneWidget);
    });

    testWidgets('finish → update the program → summary → Today', (
      tester,
    ) async {
      await start(tester);
      final id = await db(tester, data.startPush);
      await db(tester, () => data.finishState(id));
      await go(tester, Routes.workout);
      await go(tester, Routes.workoutList);
      await tapAndSettle(tester, find.text(Strings.finishWorkout));
      expect(find.text(Strings.updateProgramTitle), findsOneWidget);
      expect(find.text('Leg curl → Leg extension'), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.update));
      final plan = (await db(
        tester,
        () => app.container
            .read(programRepositoryProvider)
            .getSessionPlan(demo.pushId),
      ))!;
      expect(
        plan.exercises.map((e) => e.exerciseId),
        contains(demo.ex('leg_extension')),
      );
      expect(find.text(Strings.workoutComplete.toUpperCase()), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Felt strong');
      await tapAndSettle(tester, find.text(Strings.done));
      final summaries = await db(
        tester,
        () =>
            app.container.read(historyRepositoryProvider).getWorkoutSummaries(),
      );
      expect(summaries.first.id, id);
      expect(find.text(Strings.start), findsOneWidget);
      expect(find.text('Legs'), findsWidgets);
    });

    testWidgets('resume prompt at launch', (tester) async {
      await start(
        tester,
        beforeLaunch: () async {
          final id = await data.startPush();
          await data.logFirstSets(id, 2);
        },
      );
      expect(find.text(Strings.resumeTitle), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.resume));
      expect(find.byTooltip(Strings.leaveWorkout), findsOneWidget);
    });
  });

  testWidgets(
    'integration: next session → log all sets → finish → history, PRs '
    'and next session updated',
    (tester) async {
      await start(tester);
      // A one-exercise session makes the whole run short.
      final program = app.container.read(programRepositoryProvider);
      await db(
        tester,
        () => program.savePlan(demo.pushId, [
          DemoData.plan(
            demo.ex('barbell_bench_press'),
            DemoData.straight(2, reps: 10, load: 42.5),
          ),
        ]),
      );
      await app.settle(tester);
      await startPushFromToday(tester);
      await tapAndSettle(tester, find.text(Strings.done));
      await tapAndSettle(tester, find.text(Strings.nice));
      await tapAndSettle(tester, find.text(Strings.skip));
      await tapAndSettle(tester, find.text(Strings.done));
      // All logged: the player offers to finish.
      expect(find.text(Strings.allDoneTitle), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.finishWorkout));
      expect(find.text(Strings.updateProgramTitle), findsNothing);
      expect(find.text(Strings.newBests(1).toUpperCase()), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.done));

      final history = app.container.read(historyRepositoryProvider);
      final sets = await db(
        tester,
        () => history.getLoggedSets(exerciseId: demo.ex('barbell_bench_press')),
      );
      expect(sets.where((s) => s.load == 42.5), hasLength(2));
      final records = Bests.current(sets);
      expect(records.single.value, 42.5);
      final overview = await db(tester, program.getOverview);
      expect(overview.nextSession!.session.id, demo.legsId);
      expect(await active(tester), isNull);
    },
  );
}
