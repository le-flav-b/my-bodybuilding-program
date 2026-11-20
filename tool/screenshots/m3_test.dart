import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';

import '../../test/helpers/demo_data.dart';
import '../../test/helpers/test_app.dart';
import '../../test/helpers/workout_data.dart';
import 'harness.dart';

/// Renders the M3 screens (Today, preview, player, list, summary) in light
/// and dark. Run with `flutter test tool/screenshots`.
void main() {
  setUpAll(loadAppFonts);

  for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
    final theme = mode.name;

    Future<(TestApp, DemoData, WorkoutData)> start(
      WidgetTester tester, {
      bool history = true,
    }) async {
      usePhoneFrame(tester);
      final app = TestApp();
      await tester.runAsync(
        () => app.container.read(settingsRepositoryProvider).setThemeMode(mode),
      );
      await app.pump(tester);
      final demo = DemoData(app.container);
      await tester.runAsync(demo.create);
      await app.settle(tester);
      final data = WorkoutData(app, demo);
      if (history) {
        await tester.runAsync(data.pastWorkouts);
        await app.settle(tester);
      }
      return (app, demo, data);
    }

    Future<void> go(WidgetTester tester, TestApp app, String location) async {
      app.container.read(routerProvider).push(location).ignore();
      await app.settle(tester);
    }

    /// Push A started 12:40 ago with two bench sets logged.
    Future<String> pushInProgress(
      WidgetTester tester,
      TestApp app,
      WorkoutData data,
    ) async {
      final id = (await tester.runAsync(() async {
        final id = await data.startPush();
        await data.logFirstSets(id, 2);
        app.clock.advance(const Duration(minutes: 10));
        await app.container.read(workoutRepositoryProvider).endRest(id);
        return id;
      }))!;
      await app.settle(tester);
      return id;
    }

    testWidgets('today normal ($theme)', (tester) async {
      final (app, _, _) = await start(tester);
      await capture(tester, 'today_normal_$theme');
      await tester.tap(find.text(Strings.otherSession));
      await app.settle(tester);
      await capture(tester, 'today_pick-session_$theme');
    });

    testWidgets('today empty ($theme)', (tester) async {
      usePhoneFrame(tester);
      final app = TestApp();
      await tester.runAsync(
        () => app.container.read(settingsRepositoryProvider).setThemeMode(mode),
      );
      await app.pump(tester);
      await capture(tester, 'today_empty_$theme');
    });

    testWidgets('session preview ($theme)', (tester) async {
      final (app, demo, _) = await start(tester);
      await go(tester, app, Routes.sessionPreview(demo.pushId));
      await capture(tester, 'preview_default_$theme');
    });

    testWidgets('player reps ($theme)', (tester) async {
      final (app, _, data) = await start(tester);
      await pushInProgress(tester, app, data);
      await capture(tester, 'today_in-progress_$theme');
      await go(tester, app, Routes.workout);
      await capture(tester, 'player_reps_$theme');
    });

    testWidgets('player resting and trophy ($theme)', (tester) async {
      final (app, _, data) = await start(tester);
      await pushInProgress(tester, app, data);
      await go(tester, app, Routes.workout);
      // 42.5 kg beats the 40 kg record.
      await tester.tap(find.byTooltip('${Strings.load} +'));
      await tester.pump();
      await tester.tap(find.text(Strings.done));
      await app.settle(tester);
      await capture(tester, 'player_trophy_$theme');
      await tester.tap(find.text(Strings.nice));
      app.clock.advance(const Duration(seconds: 48));
      await tester.pump(const Duration(seconds: 1));
      await app.settle(tester);
      await capture(tester, 'player_resting_$theme');
    });

    testWidgets('player timed ($theme)', (tester) async {
      final (app, _, data) = await start(tester);
      final id = await pushInProgress(tester, app, data);
      await tester.runAsync(() => data.goToPlank(id));
      await app.settle(tester);
      await go(tester, app, Routes.workout);
      await capture(tester, 'player_timed-ready_$theme');
      await tester.tap(find.text(Strings.start));
      app.clock.advance(const Duration(seconds: 21));
      await tester.pump(const Duration(milliseconds: 200));
      await capture(tester, 'player_timed_$theme');
      await tester.tap(find.text(Strings.stop));
      await app.settle(tester);
    });

    testWidgets('player paused ($theme)', (tester) async {
      final (app, _, data) = await start(tester);
      await pushInProgress(tester, app, data);
      await go(tester, app, Routes.workout);
      await tester.tap(find.byTooltip(Strings.pause));
      await app.settle(tester);
      await capture(tester, 'player_paused_$theme');
    });

    testWidgets('workout list ($theme)', (tester) async {
      final (app, _, data) = await start(tester);
      final id = await pushInProgress(tester, app, data);
      await tester.runAsync(() => data.listState(id));
      await app.settle(tester);
      await go(tester, app, Routes.workout);
      await go(tester, app, Routes.workoutList);
      await capture(tester, 'workout-list_default_$theme');
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      await app.settle(tester);
      await capture(tester, 'workout-list_menu_$theme');
    });

    testWidgets('summary ($theme)', (tester) async {
      final (app, _, data) = await start(tester);
      final id = await pushInProgress(tester, app, data);
      await tester.runAsync(() => data.finishState(id));
      await app.settle(tester);
      await go(tester, app, Routes.workout);
      await go(tester, app, Routes.workoutList);
      await tester.tap(find.text(Strings.finishWorkout));
      await app.settle(tester);
      await capture(tester, 'summary_update-prompt_$theme');
      await tester.tap(find.text(Strings.keepProgram));
      await app.settle(tester);
      await capture(tester, 'summary_default_$theme');
      await tester.tap(find.text(Strings.done));
      await app.settle(tester);
      await capture(tester, 'today_after-workout_$theme');
    });
  }
}
