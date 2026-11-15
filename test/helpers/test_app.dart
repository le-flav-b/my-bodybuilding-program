import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/app.dart';
import 'package:my_bodybuilding_program/app/bootstrap.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';

import 'test_env.dart';

/// The whole app on an in-memory database, for widget tests.
class TestApp {
  new({FakeClock? clock}) : clock = clock ?? FakeClock() {
    db = AppDatabase(NativeDatabase.memory(), clock: this.clock.call);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(this.clock.call),
      ],
    );
  }

  final FakeClock clock;
  late final AppDatabase db;
  late final ProviderContainer container;

  Widget get widget =>
      UncontrolledProviderScope(container: container, child: const App());

  /// Pumps the app until the bootstrap (seed import) is done and the first
  /// screen is settled.
  Future<void> pump(WidgetTester tester) async {
    addTearDown(() => dispose(tester));
    // The bootstrap does real I/O (asset + database): run it for real first.
    await tester.runAsync(() => container.read(appBootstrapProvider.future));
    await tester.pumpWidget(widget);
    await settle(tester);
  }

  /// Lets database work (real async) finish, then settles the UI.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.runAsync(db.close);
    await tester.pump(const Duration(seconds: 1));
  }
}
