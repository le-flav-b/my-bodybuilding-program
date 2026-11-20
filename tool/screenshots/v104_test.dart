import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';

import '../../test/helpers/demo_data.dart';
import '../../test/helpers/test_app.dart';
import 'harness.dart';

/// Renders the v1.0.4 screens (Settings › Reminders off / on, the
/// notifications-off dialog, Program empty) in light and dark. Run with
/// `flutter test tool/screenshots`.
void main() {
  setUpAll(loadAppFonts);

  for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
    final theme = mode.name;

    Future<TestApp> start(WidgetTester tester, {bool data = true}) async {
      usePhoneFrame(tester);
      final app = TestApp();
      await tester.runAsync(
        () => app.container.read(settingsRepositoryProvider).setThemeMode(mode),
      );
      await app.pump(tester);
      if (data) {
        await tester.runAsync(DemoData(app.container).create);
        await app.settle(tester);
      }
      return app;
    }

    Future<void> openReminders(WidgetTester tester, TestApp app) async {
      app.container.read(routerProvider).push(Routes.settings).ignore();
      await app.settle(tester);
      await tester.scrollUntilVisible(
        find.text(Strings.version),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await app.settle(tester);
    }

    testWidgets('settings reminders off ($theme)', (tester) async {
      final app = await start(tester);
      await openReminders(tester, app);
      await capture(tester, 'settings_reminders-off_$theme');
    });

    testWidgets('settings reminders on ($theme)', (tester) async {
      final app = await start(tester);
      await tester.runAsync(() async {
        final settings = app.container.read(settingsRepositoryProvider);
        await settings.setTrainingReminder(enabled: true);
        await settings.setTrainingReminderDays([1, 2, 4, 6]);
        await settings.setWeighInReminder(enabled: true);
      });
      await openReminders(tester, app);
      await capture(tester, 'settings_reminders-on_$theme');
    });

    testWidgets('settings notifications off ($theme)', (tester) async {
      final app = await start(tester);
      app.reminders.grantPermission = false;
      await openReminders(tester, app);
      await tester.tap(find.text(Strings.trainingReminder));
      await app.settle(tester);
      await capture(tester, 'settings_notifications-off_$theme');
    });

    testWidgets('program empty ($theme)', (tester) async {
      final app = await start(tester, data: false);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(Strings.tabProgram),
        ),
      );
      await app.settle(tester);
      await capture(tester, 'program_empty_$theme');
    });
  }
}
