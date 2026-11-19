import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';

import '../../test/helpers/demo_data.dart';
import '../../test/helpers/test_app.dart';
import '../../test/helpers/workout_data.dart';
import 'harness.dart';

/// Renders the M5 screens (Profile, Bodyweight, Settings) in light and
/// dark. Run with `flutter test tool/screenshots`.
void main() {
  setUpAll(loadAppFonts);

  for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
    final theme = mode.name;

    Future<TestApp> start(WidgetTester tester) async {
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
      await tester.runAsync(() async {
        await data.richHistory(weeks: 8);
        await data.bodyWeights();
      });
      await app.settle(tester);
      return app;
    }

    Future<void> go(WidgetTester tester, TestApp app, String location) async {
      app.container.read(routerProvider).push(location).ignore();
      await app.settle(tester);
    }

    testWidgets('profile ($theme)', (tester) async {
      final app = await start(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(Strings.tabProfile),
        ),
      );
      await app.settle(tester);
      await capture(tester, 'profile_default_$theme');
    });

    testWidgets('bodyweight ($theme)', (tester) async {
      final app = await start(tester);
      await go(tester, app, Routes.bodyweight);
      await capture(tester, 'bodyweight_default_$theme');
    });

    testWidgets('settings ($theme)', (tester) async {
      final app = await start(tester);
      await go(tester, app, Routes.settings);
      await capture(tester, 'settings_default_$theme');
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await app.settle(tester);
      await capture(tester, 'settings_bottom_$theme');
    });
  }
}
