import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';

import '../../test/helpers/demo_data.dart';
import '../../test/helpers/test_app.dart';
import 'harness.dart';

/// Renders the M2 screens (catalogue & program) in light and dark.
/// Run with `flutter test tool/screenshots`.
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
      return (app, demo);
    }

    Future<void> go(WidgetTester tester, TestApp app, String location) async {
      app.container.read(routerProvider).push(location).ignore();
      await app.settle(tester);
    }

    testWidgets('program ($theme)', (tester) async {
      final (app, _) = await start(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(Strings.tabProgram),
        ),
      );
      await app.settle(tester);
      await capture(tester, 'program_default_$theme');
    });

    testWidgets('session editor ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(tester, app, Routes.session(demo.pushId));
      await tester.tap(find.byIcon(Symbols.keyboard_arrow_down_rounded).at(1));
      await app.settle(tester);
      await capture(tester, 'session-editor_default_$theme');
    });

    testWidgets('catalogue ($theme)', (tester) async {
      final (app, _) = await start(tester);
      await go(tester, app, Routes.exercises);
      await tester.tap(find.widgetWithText(FilterChip, 'Chest').first);
      await app.settle(tester);
      await capture(tester, 'catalogue_default_$theme');
    });

    testWidgets('exercise detail ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(tester, app, Routes.exercise(demo.ex('barbell_bench_press')));
      await capture(tester, 'exercise-detail_default_$theme');
    });

    testWidgets('exercise edit ($theme)', (tester) async {
      final (app, _) = await start(tester);
      final repository = app.container.read(catalogueRepositoryProvider);
      final muscles = (await tester.runAsync(repository.getMuscles))!;
      final id = await tester.runAsync(
        () => repository.createExercise(
          ExerciseDraft(
            name: 'Cable crossover',
            measure: Measure.reps,
            primaryMuscleIds: [muscles[0].id],
            secondaryMuscleIds: [muscles[2].id],
          ),
        ),
      );
      await app.settle(tester);
      await go(tester, app, Routes.editExercise(id!));
      await capture(tester, 'exercise-edit_default_$theme');
    });

    testWidgets('exercise picker ($theme)', (tester) async {
      final (app, demo) = await start(tester);
      await go(tester, app, Routes.session(demo.legsId));
      await tester.scrollUntilVisible(
        find.text(Strings.addExercise),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(Strings.addExercise));
      await app.settle(tester);
      await capture(tester, 'exercise-picker_default_$theme');
    });

    testWidgets('settings, load units, muscles ($theme)', (tester) async {
      final (app, _) = await start(tester);
      await go(tester, app, Routes.settings);
      await capture(tester, 'settings_default_$theme');
      await go(tester, app, Routes.loadUnits);
      await capture(tester, 'load-units_default_$theme');
      await tester.tap(find.byIcon(Symbols.edit_rounded).first);
      await app.settle(tester);
      await capture(tester, 'load-units_editor_$theme');
      await tester.tap(find.text(Strings.cancel));
      await app.settle(tester);
      await go(tester, app, Routes.muscles);
      await capture(tester, 'muscles_default_$theme');
    });
  }
}
