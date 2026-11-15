import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';

import '../../test/helpers/test_app.dart';
import 'harness.dart';

/// Renders the app shell. Run with `flutter test tool/screenshots`.
void main() {
  setUpAll(loadAppFonts);

  for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
    testWidgets('tabs (${mode.name})', (tester) async {
      usePhoneFrame(tester);
      final app = TestApp();
      await tester.runAsync(
        () => app.container.read(settingsRepositoryProvider).setThemeMode(mode),
      );
      await app.pump(tester);
      await capture(tester, 'today_empty_${mode.name}');

      for (final tab in [
        Strings.tabProgram,
        Strings.tabProgress,
        Strings.tabProfile,
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, '${tab.toLowerCase()}_empty_${mode.name}');
      }
    });
  }
}
