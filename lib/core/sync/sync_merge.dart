import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_merge.freezed.dart';

/// The version of a row on one side (local database or cloud mirror).
@freezed
abstract class RowVersion with _$RowVersion {
  const factory({
    required String id,
    required DateTime updatedAt,

    /// Local only: changed since the last push.
    @Default(false) bool dirty,
  }) = _RowVersion;
}

/// What a sync of one table has to do.
@freezed
abstract class SyncPlan with _$SyncPlan {
  const factory({
    /// Row ids to upload.
    required Set<String> push,

    /// Row ids to download and write locally.
    required Set<String> pull,
  }) = _SyncPlan;
}

/// The merge rule of the cloud mirror (used from v1.1): last write wins per
/// row, by `updated_at`. Deletions are rows too (soft delete), so they merge
/// the same way and nothing is ever lost.
abstract final class SyncMerge {
  /// Decides what to push and pull for one table.
  ///
  /// - only on one side: copied to the other;
  /// - on both sides: the newer `updated_at` wins; when equal, a dirty local
  ///   row is pushed and otherwise nothing happens.
  static SyncPlan plan({
    required Iterable<RowVersion> local,
    required Iterable<RowVersion> remote,
  }) {
    final remoteById = {for (final r in remote) r.id: r};
    final localIds = <String>{};
    final push = <String>{};
    final pull = <String>{};

    for (final row in local) {
      localIds.add(row.id);
      final other = remoteById[row.id];
      if (other == null) {
        push.add(row.id);
      } else if (row.updatedAt.isAfter(other.updatedAt)) {
        push.add(row.id);
      } else if (other.updatedAt.isAfter(row.updatedAt)) {
        pull.add(row.id);
      } else if (row.dirty) {
        push.add(row.id);
      }
    }
    for (final row in remote) {
      if (!localIds.contains(row.id)) pull.add(row.id);
    }
    return SyncPlan(push: push, pull: pull);
  }
}
