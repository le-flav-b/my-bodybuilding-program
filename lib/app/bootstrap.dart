import 'package:flutter/services.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/db/seed/seed_importer.dart';
import 'package:my_bodybuilding_program/core/images/image_storage.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap.g.dart';

/// Loads the bundled seed file. Tests can override it.
@Riverpod(keepAlive: true)
Future<String> Function() seedLoader(Ref ref) =>
    () => rootBundle.loadString(SeedImporter.assetPath);

/// What must happen before the first screen: open the database, import the
/// catalogue seed (first launch or new seed version), close a workout left
/// idle for more than 12 h, load the settings (theme) and open the photo
/// storage.
@Riverpod(keepAlive: true)
Future<void> appBootstrap(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final importer = SeedImporter(
    db,
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
  await importer.importJson(await ref.watch(seedLoaderProvider)());
  await ref.watch(workoutRepositoryProvider).finishIfStale();
  await ref.watch(appSettingsProvider.future);
  await ref.watch(imageStorageProvider.future);
}
