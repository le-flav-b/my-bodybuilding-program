import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/profile_screen.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';

import '../../test/helpers/demo_data.dart';
import '../../test/helpers/test_app.dart';
import '../../test/helpers/workout_data.dart';
import 'harness.dart';

/// Renders the v1.0.1 screens (personal records, Bests, Profile's latest
/// PRs, Today empty) in light and dark. Run with `flutter test
/// tool/screenshots`.
void main() {
  setUpAll(loadAppFonts);

  for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
    final theme = mode.name;

    Future<(TestApp, DemoData)> start(
      WidgetTester tester, {
      bool data = true,
    }) async {
      usePhoneFrame(tester);
      final app = TestApp();
      await tester.runAsync(
        () => app.container.read(settingsRepositoryProvider).setThemeMode(mode),
      );
      await app.pump(tester);
      final demo = DemoData(app.container);
      if (!data) return (app, demo);
      await tester.runAsync(demo.create);
      await app.settle(tester);
      final workouts = WorkoutData(app, demo);
      await tester.runAsync(() async {
        await workouts.richHistory(weeks: 8);
        await workouts.bodyWeights();
        await workouts.personalRecords();
      });
      await app.settle(tester);
      return (app, demo);
    }

    Future<void> go(WidgetTester tester, TestApp app, String location) async {
      app.container.read(routerProvider).push(location).ignore();
      await app.settle(tester);
    }

    testWidgets('personal records ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(
        tester,
        app,
        Routes.exerciseRecords(demo.ex('barbell_bench_press')),
      );
      await capture(tester, 'personal-records_default_$theme');
      await tester.tap(find.text(Strings.addPr));
      await app.settle(tester);
      await capture(tester, 'personal-records_add_$theme');
    });

    testWidgets('personal records empty ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(tester, app, Routes.exerciseRecords(demo.ex('lat_pulldown')));
      await capture(tester, 'personal-records_empty_$theme');
    });

    testWidgets('exercise progress with PR card ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(
        tester,
        app,
        Routes.exerciseProgress(demo.ex('barbell_bench_press')),
      );
      await capture(tester, 'exercise-progress_default_$theme');
    });

    testWidgets('exercise detail with PR card ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(tester, app, Routes.exercise(demo.ex('barbell_bench_press')));
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
      await app.settle(tester);
      await capture(tester, 'exercise-detail_bottom_$theme');
    });

    testWidgets('profile latest PRs ($theme)', (tester) async {
      final (app, _) = await start(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(Strings.tabProfile),
        ),
      );
      await app.settle(tester);
      await tester.drag(
        find
            .descendant(
              of: find.byType(ProfileScreen),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, -800),
      );
      await app.settle(tester);
      await capture(tester, 'profile_latest-prs_$theme');
    });

    testWidgets('today empty ($theme)', (tester) async {
      final (app, _) = await start(tester, data: false);
      await app.settle(tester);
      await capture(tester, 'today_empty_$theme');
    });
  }
}
