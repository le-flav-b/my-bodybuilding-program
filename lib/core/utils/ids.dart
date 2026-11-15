import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'ids.g.dart';

/// Creates the id of a new row.
typedef IdGenerator = String Function();

const _uuid = Uuid();

/// UUID v7: time-ordered, so ids sort by creation and sync well.
String newId() => _uuid.v7();

/// Fixed ids of the rows every installation has, so a restore from the cloud
/// merges them instead of duplicating them.
abstract final class FixedIds {
  /// The built-in `kg` load unit.
  static const String kgUnit = '00000000-0000-7000-8000-000000000001';

  /// The single program.
  static const String program = '00000000-0000-7000-8000-000000000002';
}

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => newId;
