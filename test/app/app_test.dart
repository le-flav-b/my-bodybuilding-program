import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/app.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/theme_mode_controller.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/profile_screen.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_screen.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_screen.dart';
import 'package:my_bodybuilding_program/features/today/presentation/today_screen.dart';

void main() {
  testWidgets('launches on Today with the four tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

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

  testWidgets('each tab opens its screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

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

  testWidgets('follows the theme mode in light and dark', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    ThemeData theme() => Theme.of(tester.element(find.byType(TodayScreen)));

    container.read(themeModeControllerProvider.notifier).set(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(theme().colorScheme, AppTheme.light.colorScheme);

    container.read(themeModeControllerProvider.notifier).set(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(theme().colorScheme, AppTheme.dark.colorScheme);
  });
}
