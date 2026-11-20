import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/app_info.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/profile/data/body_weight_repository.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/body_weight_dialog.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/profile_screen.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';

import '../helpers/demo_data.dart';
import '../helpers/test_app.dart';
import '../helpers/workout_data.dart';

void main() {
  late TestApp app;
  late WorkoutData data;

  Future<void> start(
    WidgetTester tester, {
    int weeks = 2,
    bool weights = true,
    bool prs = true,
  }) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    app = TestApp();
    final demo = DemoData(app.container);
    data = WorkoutData(app, demo);
    await app.pump(tester);
    await tester.runAsync(demo.create);
    await app.settle(tester);
    if (weeks > 0) {
      await tester.runAsync(() => data.richHistory(weeks: weeks));
      await app.settle(tester);
    }
    if (weights) {
      await tester.runAsync(() => data.bodyWeights(days: 30));
      await app.settle(tester);
    }
    if (prs) {
      await tester.runAsync(data.personalRecords);
      await app.settle(tester);
    }
  }

  Future<T> db<T>(WidgetTester tester, Future<T> Function() f) async {
    final result = (await tester.runAsync(f)) as T;
    await app.settle(tester);
    return result;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await app.settle(tester);
  }

  Future<void> openProfile(WidgetTester tester) => tapAndSettle(
    tester,
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(Strings.tabProfile),
    ),
  );

  Future<List<BodyWeight>> weights(WidgetTester tester) => db(
    tester,
    () => app.container.read(bodyWeightRepositoryProvider).getEntries(),
  );

  Future<AppSettings> settings(WidgetTester tester) => db(
    tester,
    () => app.container.read(settingsRepositoryProvider).getSettings(),
  );

  test('parseWeight accepts commas and rejects nonsense', () {
    expect(parseWeight('78,4'), 78.4);
    expect(parseWeight(' 80 '), 80);
    expect(parseWeight('7'), isNull);
    expect(parseWeight('abc'), isNull);
  });

  testWidgets('profile: bodyweight card, stats and latest PRs', (tester) async {
    await start(tester);
    await openProfile(tester);
    expect(
      find.textContaining(Strings.bodyweightTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(Strings.workoutsTile), findsOneWidget);
    expect(find.text(Strings.timeTrained), findsOneWidget);
    expect(find.text(Strings.streakBest), findsOneWidget);
    expect(find.text(Strings.latestPrs.toUpperCase()), findsOneWidget);
    // The PRs, newest first; nothing computed from the training sets.
    await tester.scrollUntilVisible(
      find.text('100 kg'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await app.settle(tester);
    final values = ['1:30', '15 reps', '5 × 90 kg', '100 kg'];
    for (final v in values) {
      expect(find.text(v), findsOneWidget);
    }
    final ys = [for (final v in values) tester.getTopLeft(find.text(v)).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('Barbell bench press'), findsNWidgets(2));
    // A row opens that exercise's personal records.
    await tapAndSettle(tester, find.text('Pull-up'));
    expect(find.text(Strings.personalRecords), findsOneWidget);
    expect(find.text(Strings.bestPr), findsWidgets);
  });

  testWidgets('profile with nothing logged', (tester) async {
    await start(tester, weeks: 0, weights: false, prs: false);
    await openProfile(tester);
    expect(find.text(Strings.noWeighIn), findsOneWidget);
    expect(find.text(Strings.noPrsYet), findsOneWidget);
  });

  testWidgets('log a weight from the profile card', (tester) async {
    await start(tester, weeks: 0, weights: false);
    await openProfile(tester);
    await tapAndSettle(tester, find.byTooltip(Strings.logWeight));
    await tester.enterText(find.byType(TextField).first, '12');
    await tester.pump();
    await tapAndSettle(tester, find.text(Strings.save));
    expect(find.text(Strings.weightInvalid), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '81,3');
    await tester.enterText(find.byType(TextField).last, 'morning');
    await tester.pump();
    await tapAndSettle(tester, find.text(Strings.save));
    final entries = await weights(tester);
    expect(entries.single.weightKg, 81.3);
    expect(entries.single.note, 'morning');
    expect(find.textContaining('81.3', findRichText: true), findsOneWidget);
  });

  testWidgets('bodyweight screen: chart, change, edit and delete', (
    tester,
  ) async {
    await start(tester, weeks: 0);
    app.container.read(routerProvider).push(Routes.bodyweight).ignore();
    await app.settle(tester);
    expect(find.textContaining('in 30 days'), findsOneWidget);
    final before = await weights(tester);
    final latest = BodyWeightTrend.latest(before)!;

    await tapAndSettle(tester, find.byIcon(Symbols.more_vert_rounded).first);
    await tapAndSettle(tester, find.text(Strings.edit));
    await tester.enterText(find.byType(TextField).first, '77.9');
    await tester.pump();
    await tapAndSettle(tester, find.text(Strings.save));
    var after = await weights(tester);
    expect(after.firstWhere((e) => e.id == latest.id).weightKg, 77.9);

    await tapAndSettle(tester, find.byIcon(Symbols.more_vert_rounded).first);
    await tapAndSettle(tester, find.text(Strings.delete).last);
    await tapAndSettle(tester, find.text(Strings.delete).last);
    after = await weights(tester);
    expect(after, hasLength(before.length - 1));
    expect(after.where((e) => e.id == latest.id), isEmpty);
  });

  testWidgets('settings: workout switches, weekly target, version', (
    tester,
  ) async {
    await start(tester, weeks: 0, weights: false);
    app.container.read(routerProvider).push(Routes.settings).ignore();
    await app.settle(tester);
    await tapAndSettle(tester, find.text(Strings.timerSound));
    await tapAndSettle(tester, find.text(Strings.keepScreenOn));
    await tapAndSettle(tester, find.byTooltip('${Strings.weeklyTarget} +'));
    var s = await settings(tester);
    expect(s.timerSound, isFalse);
    expect(s.keepScreenOn, isFalse);
    expect(s.weeklyTarget, AppSettings.defaultWeeklyTarget + 1);
    expect(find.text(AppInfo.version), findsOneWidget);

    await tapAndSettle(tester, find.text(Strings.defaultRest));
    await tapAndSettle(tester, find.byTooltip('+0:15'));
    await tapAndSettle(tester, find.text(Strings.ok));
    s = await settings(tester);
    expect(s.defaultRestSeconds, AppSettings.defaultRest + 15);
  });
}
