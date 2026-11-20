import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/progress/data/personal_records_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/pr_dialog.dart';

import '../helpers/demo_data.dart';
import '../helpers/test_app.dart';
import '../helpers/workout_data.dart';

/// v1.0.1: personal records (PRs), apart from the training bests.
void main() {
  late TestApp app;
  late DemoData demo;
  late WorkoutData data;

  Future<void> start(WidgetTester tester, {bool history = false}) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    app = TestApp();
    demo = DemoData(app.container);
    data = WorkoutData(app, demo);
    await app.pump(tester);
    await tester.runAsync(demo.create);
    await app.settle(tester);
    if (history) {
      await tester.runAsync(() => data.richHistory(weeks: 2));
      await app.settle(tester);
    }
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

  Future<List<PersonalRecord>> records(WidgetTester tester, String id) async {
    final result = await tester.runAsync(
      () => app.container
          .read(personalRecordsRepositoryProvider)
          .getRecords(exerciseId: id),
    );
    await app.settle(tester);
    return result!;
  }

  Finder field(String key) => find.byKey(ValueKey(key));
  Finder dialogSave() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, Strings.save),
  );

  test('parsePrTime and parsePrLoad', () {
    expect(parsePrTime('1:20'), 80);
    expect(parsePrTime(' 95 '), 95);
    expect(parsePrTime('1:02:03'), 3723);
    expect(parsePrTime(''), isNull);
    expect(parsePrTime('1:75'), -1);
    expect(parsePrTime('abc'), -1);
    expect(parsePrLoad('102,5'), 102.5);
    expect(parsePrLoad('−10'), -10);
    expect(parsePrLoad(''), isNull);
    expect(parsePrLoad('x')!.isNaN, isTrue);
  });

  testWidgets('add a PR from the exercise detail', (tester) async {
    await start(tester);
    final bench = demo.ex('barbell_bench_press');
    await go(tester, Routes.exercise(bench));
    await tester.ensureVisible(find.text(Strings.noPrYet));
    expect(find.text(Strings.personalRecord.toUpperCase()), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip(Strings.addPr));
    expect(find.text(Strings.addPr), findsWidgets);
    // Nothing filled in: an error, nothing saved.
    await tapAndSettle(tester, dialogSave());
    expect(find.text(Strings.prRepsOrLoadNeeded), findsOneWidget);

    await tester.enterText(field('pr-load'), '100');
    await tester.enterText(field('pr-note'), 'belt');
    await tester.pump();
    await tapAndSettle(tester, dialogSave());
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('100 kg'), findsOneWidget);

    final saved = await records(tester, bench);
    expect(saved.single.load, 100);
    expect(saved.single.reps, isNull);
    expect(saved.single.note, 'belt');
  });

  testWidgets('a time PR on a time exercise', (tester) async {
    await start(tester);
    final plank = demo.ex('plank');
    await go(tester, Routes.exerciseRecords(plank));
    expect(find.text(Strings.noPrYet), findsOneWidget);
    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, Strings.addPr),
    );
    expect(field('pr-reps'), findsNothing);
    await tester.enterText(field('pr-time'), '1:2x');
    await tester.pump();
    await tapAndSettle(tester, dialogSave());
    expect(find.text(Strings.prTimeInvalid), findsOneWidget);
    await tester.enterText(field('pr-time'), '1:20');
    await tester.pump();
    await tapAndSettle(tester, dialogSave());
    expect(find.text('1:20'), findsNWidgets(2));
    expect((await records(tester, plank)).single.seconds, 80);
  });

  testWidgets('history: best card, edit and delete a PR', (tester) async {
    await start(tester);
    await tester.runAsync(data.personalRecords);
    await app.settle(tester);
    final bench = demo.ex('barbell_bench_press');
    await go(tester, Routes.exerciseRecords(bench));

    expect(find.text(Strings.personalRecords), findsOneWidget);
    expect(find.text(Strings.prHistory(2).toUpperCase()), findsOneWidget);
    // 100 kg (a load alone = 1 rep) beats 5 × 90 kg: heaviest load first.
    expect(find.text(Strings.bestPr), findsNWidgets(2));
    expect(find.text('100 kg'), findsNWidgets(2));
    expect(find.text('5 × 90 kg'), findsOneWidget);

    // Edit the 5 × 90 kg PR into 2 × 105 kg: the new best.
    await tapAndSettle(tester, find.text('5 × 90 kg'));
    expect(find.text(Strings.editPr), findsOneWidget);
    await tester.enterText(field('pr-load'), '105');
    await tester.enterText(field('pr-reps'), '2');
    await tester.pump();
    await tapAndSettle(tester, dialogSave());
    expect(find.text('2 × 105 kg'), findsNWidgets(2));
    expect(find.text('100 kg'), findsOneWidget);

    // Delete it from its ⋮ menu: 100 kg is the best again.
    final row = find.ancestor(
      of: find.text('2 × 105 kg').last,
      matching: find.byType(InkWell),
    );
    await tapAndSettle(
      tester,
      find.descendant(
        of: row.first,
        matching: find.byIcon(Symbols.more_vert_rounded),
      ),
    );
    await tapAndSettle(tester, find.text(Strings.deletePr));
    expect(find.text(Strings.deletePrTitle), findsOneWidget);
    await tapAndSettle(
      tester,
      find.widgetWithText(TextButton, Strings.delete).last,
    );
    expect(find.text('2 × 105 kg'), findsNothing);
    expect(find.text('100 kg'), findsNWidgets(2));
    final left = await records(tester, bench);
    expect(left.single.load, 100);

    // Delete the last one: the empty state comes back.
    await tapAndSettle(tester, find.byIcon(Symbols.more_vert_rounded));
    await tapAndSettle(tester, find.text(Strings.deletePr));
    await tapAndSettle(
      tester,
      find.widgetWithText(TextButton, Strings.delete).last,
    );
    expect(find.text(Strings.noPrYet), findsOneWidget);
  });

  testWidgets('exercise progress: PR card above the training bests', (
    tester,
  ) async {
    await start(tester, history: true);
    await tester.runAsync(data.personalRecords);
    await app.settle(tester);
    await go(tester, Routes.exerciseProgress(demo.ex('barbell_bench_press')));
    expect(find.text(Strings.personalRecord.toUpperCase()), findsOneWidget);
    expect(find.text(Strings.bests.toUpperCase()), findsOneWidget);
    final prY = tester.getTopLeft(find.text('100 kg')).dy;
    final bestsY = tester.getTopLeft(find.text(Strings.bests.toUpperCase())).dy;
    expect(prY, lessThan(bestsY));
    // The PR card leads to the PR screen.
    await tapAndSettle(tester, find.text('100 kg'));
    expect(find.text(Strings.personalRecords), findsOneWidget);
  });

  testWidgets('exercise progress without training still offers PRs', (
    tester,
  ) async {
    await start(tester);
    await go(tester, Routes.exerciseProgress(demo.ex('pull_up')));
    expect(find.text(Strings.noPrYet), findsOneWidget);
    expect(find.text(Strings.notDoneYet), findsOneWidget);
    expect(find.text(Strings.bests.toUpperCase()), findsNothing);
    await tapAndSettle(tester, find.byTooltip(Strings.addPr));
    await tester.enterText(field('pr-reps'), '15');
    await tester.pump();
    await tapAndSettle(tester, dialogSave());
    expect(find.text('15 reps'), findsOneWidget);
  });
}
