import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// The app's database. Tests override it with an in-memory one.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.onDevice();
  ref.onDispose(db.close);
  return db;
}
