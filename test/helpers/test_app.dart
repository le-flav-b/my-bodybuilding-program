import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/app.dart';
import 'package:my_bodybuilding_program/app/bootstrap.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/images/image_storage.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';

import 'test_env.dart';

/// The whole app on an in-memory database, for widget tests.
class TestApp {
  new({FakeClock? clock, List<Override> overrides = const []})
    : clock = clock ?? FakeClock() {
    images = ImageStorage(Directory.systemTemp.createTempSync('mbp_images'));
    db = AppDatabase(NativeDatabase.memory(), clock: this.clock.call);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(this.clock.call),
        imageStorageProvider.overrideWith((ref) async => images),
        ...overrides,
      ],
    );
  }

  final FakeClock clock;
  late final AppDatabase db;
  late final ImageStorage images;
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
    // Database streams reload with several queries, each needing a turn of
    // the real event loop followed by a pump.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
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
