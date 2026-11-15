import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/profile_screen.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_screen.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_screen.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:my_bodybuilding_program/features/today/presentation/today_screen.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('launches on Today with the four tabs', (tester) async {
    final app = TestApp();
    await app.pump(tester);

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text(Strings.appName), findsOneWidget);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(4));
    for (final label in [
      Strings.tabToday,
      Strings.tabProgram,
      Strings.tabProgress,
      Strings.tabProfile,
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('imports the catalogue seed on first launch', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    final repository = app.container.read(catalogueRepositoryProvider);
    final exercises = await tester.runAsync(repository.getExercises);
    final muscles = await tester.runAsync(repository.getMuscles);
    expect(exercises, hasLength(82));
    expect(muscles, hasLength(13));
  });

  testWidgets('each tab opens its screen', (tester) async {
    final app = TestApp();
    await app.pump(tester);

    Future<void> open(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open(Strings.tabProgram);
    expect(find.byType(ProgramScreen), findsOneWidget);
    await open(Strings.tabProgress);
    expect(find.byType(ProgressScreen), findsOneWidget);
    await open(Strings.tabProfile);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await open(Strings.tabToday);
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('follows the theme setting in light and dark', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    final settings = app.container.read(settingsRepositoryProvider);

    ThemeData theme() => Theme.of(tester.element(find.byType(TodayScreen)));

    await tester.runAsync(() => settings.setThemeMode(AppThemeMode.light));
    await app.settle(tester);
    expect(theme().colorScheme, AppTheme.light.colorScheme);

    await tester.runAsync(() => settings.setThemeMode(AppThemeMode.dark));
    await app.settle(tester);
    expect(theme().colorScheme, AppTheme.dark.colorScheme);
  });
}
