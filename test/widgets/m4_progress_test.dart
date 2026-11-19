import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/progress/data/history_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/stats.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';

import '../helpers/demo_data.dart';
import '../helpers/test_app.dart';
import '../helpers/workout_data.dart';

void main() {
  late TestApp app;
  late DemoData demo;

  Future<void> start(WidgetTester tester, {int weeks = 4}) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    app = TestApp();
    demo = DemoData(app.container);
    await app.pump(tester);
    await tester.runAsync(demo.create);
    await app.settle(tester);
    if (weeks > 0) {
      await tester.runAsync(
        () => WorkoutData(app, demo).richHistory(weeks: weeks),
      );
      await app.settle(tester);
    }
  }

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

  Future<void> openProgress(WidgetTester tester) => tapAndSettle(
    tester,
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(Strings.tabProgress),
    ),
  );

  Future<List<WorkoutSummary>> summaries(WidgetTester tester) => db(
    tester,
    () => app.container.read(historyRepositoryProvider).getWorkoutSummaries(),
  );

  testWidgets('no workout yet: empty state', (tester) async {
    await start(tester, weeks: 0);
    await openProgress(tester);
    expect(find.text(Strings.progressEmptyTitle), findsOneWidget);
  });

  testWidgets('calendar: trained days, streak, month totals, day → detail', (
    tester,
  ) async {
    await start(tester);
    await openProgress(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text(Strings.streakLong(4)), findsOneWidget);
    expect(find.text(Strings.workoutsIn('November')), findsOneWidget);
    // Friday 13 November was trained (Legs).
    await tapAndSettle(tester, find.text('13'));
    expect(find.text('Legs'), findsWidgets);
    expect(find.text(Strings.workoutNote.toUpperCase()), findsOneWidget);
    app.container.read(routerProvider).pop();
    await app.settle(tester);
    await tapAndSettle(tester, find.byTooltip(Strings.previousMonth));
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('exercises: sorted by last done, search, → progress', (
    tester,
  ) async {
    await start(tester);
    await openProgress(tester);
    await tapAndSettle(tester, find.text(Strings.exercisesTab).last);
    expect(find.text(Strings.sortedByLastDone), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'curl');
    await app.settle(tester);
    expect(find.text('Leg curl'), findsOneWidget);
    expect(find.text('Barbell bench press'), findsNothing);
    await tapAndSettle(tester, find.text('Leg curl'));
    // Two units: two record tiles and two legend chips.
    expect(find.text(Strings.heaviestIn('kg')), findsOneWidget);
    expect(find.text(Strings.heaviestIn('level')), findsOneWidget);
    expect(find.text(Strings.allSets(4).toUpperCase()), findsOneWidget);
  });

  testWidgets('history: grouped by month with totals → detail', (tester) async {
    await start(tester);
    await openProgress(tester);
    await tapAndSettle(tester, find.text(Strings.historyTab).last);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.textContaining('6 workouts'), findsWidgets);
    await tapAndSettle(tester, find.text('Push A').first);
    expect(find.text('Barbell bench press'), findsOneWidget);
  });

  testWidgets('workout detail: edit and delete a set, note, delete workout', (
    tester,
  ) async {
    await start(tester, weeks: 1);
    final workouts = await summaries(tester);
    final push = workouts.firstWhere((w) => w.sessionName == 'Push A');
    await go(tester, Routes.workoutDetail(push.id));
    Future<WorkoutDetail> load() async => (await db<WorkoutDetail?>(
      tester,
      () => app.container.read(workoutRepositoryProvider).getWorkout(push.id),
    ))!;
    // Edit the first bench set: one more rep.
    await tapAndSettle(tester, find.byTooltip(Strings.editSet).first);
    await tester.tap(find.byTooltip('${Strings.reps} +'));
    await tester.pump();
    await tapAndSettle(tester, find.text(Strings.save));
    var bench = (await load()).exercises.first;
    expect(bench.sets.first.reps, 11);

    // Delete it.
    await tapAndSettle(tester, find.byTooltip(Strings.editSet).first);
    await tapAndSettle(tester, find.text(Strings.deleteSet));
    bench = (await load()).exercises.first;
    expect(bench.doneCount, 3);

    // Note (back at the top of the list).
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await app.settle(tester);
    await tapAndSettle(tester, find.byTooltip(Strings.editNote));
    await tester.enterText(find.byType(TextField), 'Grip felt weak');
    await tester.pump();
    await tapAndSettle(tester, find.text(Strings.save));
    expect((await load()).workout.notes, 'Grip felt weak');
    expect(find.text('Grip felt weak'), findsOneWidget);

    // Delete the workout.
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Symbols.more_vert_rounded),
      ),
    );
    await tapAndSettle(tester, find.text(Strings.deleteWorkout));
    await tapAndSettle(tester, find.text(Strings.delete));
    expect((await summaries(tester)).where((w) => w.id == push.id), isEmpty);
    expect(find.text(Strings.workoutDeleted), findsOneWidget);
  });

  testWidgets('Today last workout and exercise detail link to progress', (
    tester,
  ) async {
    await start(tester, weeks: 1);
    final last = (await summaries(tester)).first;
    await tapAndSettle(tester, find.byIcon(Symbols.chevron_right_rounded).last);
    expect(find.text(last.sessionName), findsWidgets);
    expect(find.text(Strings.workoutNote.toUpperCase()), findsOneWidget);
    app.container.read(routerProvider).pop();
    await app.settle(tester);

    await go(tester, Routes.exercise(demo.ex('barbell_bench_press')));
    await tapAndSettle(tester, find.text(Strings.seeProgress));
    expect(find.textContaining('Heaviest'), findsOneWidget);
  });
}
