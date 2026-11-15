import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/app.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/theme_mode_controller.dart';

import 'harness.dart';

/// Renders the M0 shell. Run with `flutter test tool/screenshots`.
void main() {
  setUpAll(loadAppFonts);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('tabs (${mode.name})', (tester) async {
      usePhoneFrame(tester);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeControllerProvider.notifier).set(mode);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
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
