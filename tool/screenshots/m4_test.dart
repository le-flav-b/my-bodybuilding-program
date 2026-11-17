import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/progress/data/history_repository.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';

import '../../test/helpers/demo_data.dart';
import '../../test/helpers/test_app.dart';
import '../../test/helpers/workout_data.dart';
import 'harness.dart';

/// Renders the M4 screens (Progress tabs, exercise progress, workout
/// detail) in light and dark. Run with `flutter test tool/screenshots`.
void main() {
  setUpAll(loadAppFonts);

  for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
    final theme = mode.name;

    Future<(TestApp, DemoData)> start(WidgetTester tester) async {
      usePhoneFrame(tester);
      final app = TestApp();
      await tester.runAsync(
        () => app.container.read(settingsRepositoryProvider).setThemeMode(mode),
      );
      await app.pump(tester);
      final demo = DemoData(app.container);
      await tester.runAsync(demo.create);
      await app.settle(tester);
      await tester.runAsync(WorkoutData(app, demo).richHistory);
      await app.settle(tester);
      return (app, demo);
    }

    Future<void> go(WidgetTester tester, TestApp app, String location) async {
      app.container.read(routerProvider).push(location).ignore();
      await app.settle(tester);
    }

    Future<void> tab(WidgetTester tester, TestApp app, String label) async {
      await tester.tap(find.text(label).last);
      await app.settle(tester);
    }

    testWidgets('progress tabs ($theme)', (tester) async {
      final (app, _) = await start(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(Strings.tabProgress),
        ),
      );
      await app.settle(tester);
      await capture(tester, 'progress_calendar_$theme');
      await tab(tester, app, Strings.exercisesTab);
      await capture(tester, 'progress_exercises_$theme');
      await tab(tester, app, Strings.historyTab);
      await capture(tester, 'progress_history_$theme');
    });

    testWidgets('exercise progress ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(tester, app, Routes.exerciseProgress(demo.ex('leg_curl')));
      await capture(tester, 'exercise-progress_default_$theme');
      app.container.read(routerProvider).pop();
      await go(
        tester,
        app,
        Routes.exerciseProgress(demo.ex('barbell_bench_press')),
      );
      await capture(tester, 'exercise-progress_bench_$theme');
    });

    testWidgets('workout detail ($theme)', (tester) async {
      final (app, _) = await start(tester);
      final summaries = (await tester.runAsync(
        () =>
            app.container.read(historyRepositoryProvider).getWorkoutSummaries(),
      ))!;
      await go(tester, app, Routes.workoutDetail(summaries[1].id));
      await capture(tester, 'workout-detail_default_$theme');
    });

    testWidgets('exercise detail with progress ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(tester, app, Routes.exercise(demo.ex('barbell_bench_press')));
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await app.settle(tester);
      await capture(tester, 'exercise-detail_progress_$theme');
    });
  }
}
