import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';

part 'personal_record.freezed.dart';

/// A personal record (PR): an attempt made on purpose, logged by hand and
/// kept apart from the training sets (which give the training bests).
@freezed
abstract class PersonalRecord with _$PersonalRecord {
  const factory({
    required String id,
    required String exerciseId,
    required DateTime achievedAt,
    double? load,
    String? unitId,
    int? reps,
    int? seconds,
    String? note,
  }) = _PersonalRecord;
  const new _();

  /// The values as a draft, to edit them.
  PersonalRecordDraft toDraft() => PersonalRecordDraft(
    achievedAt: achievedAt,
    load: load,
    unitId: unitId,
    reps: reps,
    seconds: seconds,
    note: note,
  );
}

/// The fields of a PR the user fills in.
@freezed
abstract class PersonalRecordDraft with _$PersonalRecordDraft {
  const factory({
    required DateTime achievedAt,
    double? load,
    String? unitId,
    int? reps,
    int? seconds,
    String? note,
  }) = _PersonalRecordDraft;
  const new _();

  /// Why this draft can't be saved for an exercise measured by [measure],
  /// or null when it can.
  ///
  /// Reps exercise: a load (with its unit) and/or reps, no time. Time
  /// exercise: a time, and optionally a load (with its unit), no reps.
  PrDraftError? errorFor(Measure measure) {
    if (load != null && unitId == null) return PrDraftError.unitMissing;
    if (reps != null && reps! < 1) return PrDraftError.repsInvalid;
    if (seconds != null && seconds! < 1) return PrDraftError.timeInvalid;
    switch (measure) {
      case Measure.reps:
        if (seconds != null) return PrDraftError.timeNotAllowed;
        if (load == null && reps == null) return PrDraftError.repsOrLoadNeeded;
      case Measure.time:
        if (reps != null) return PrDraftError.repsNotAllowed;
        if (seconds == null) return PrDraftError.timeNeeded;
    }
    return null;
  }

  /// The same draft with the values that don't apply to [measure] dropped,
  /// an empty note removed and a unit only when there is a load.
  PersonalRecordDraft normalizedFor(Measure measure) {
    final text = note?.trim() ?? '';
    return copyWith(
      reps: measure == Measure.reps ? reps : null,
      seconds: measure == Measure.time ? seconds : null,
      unitId: load == null ? null : unitId,
      note: text.isEmpty ? null : text,
    );
  }
}

enum PrDraftError {
  unitMissing,
  repsInvalid,
  timeInvalid,
  timeNotAllowed,
  repsNotAllowed,
  repsOrLoadNeeded,
  timeNeeded,
}

/// The best PR of one series of an exercise: PRs with a load, per unit
/// (units are never converted), or PRs with no load.
typedef PrBest = ({String? unitId, PersonalRecord record});

/// Rules of the personal records. Pure Dart; PRs never read training sets.
abstract final class PrRule {
  /// The best PR of each series of one exercise's [records], the series of
  /// the most recent PR first, then the others by their latest PR.
  ///
  /// Reps exercise: loaded PRs rank by load, then reps (a load alone counts
  /// as 1 rep); PRs with no load rank by reps. Time exercise: by time, then
  /// load. Ties keep the earliest PR.
  static List<PrBest> bests(Iterable<PersonalRecord> records, Measure measure) {
    final sorted = records.toList()
      ..sort((a, b) => a.achievedAt.compareTo(b.achievedAt));
    final best = <String?, PersonalRecord>{};
    final latest = <String?, DateTime>{};
    for (final r in sorted) {
      final key = r.load == null ? null : r.unitId;
      latest[key] = r.achievedAt;
      final holder = best[key];
      if (holder == null || compare(r, holder, measure) > 0) best[key] = r;
    }
    final keys = best.keys.toList()
      ..sort((a, b) => latest[b]!.compareTo(latest[a]!));
    return [for (final k in keys) (unitId: k, record: best[k]!)];
  }

  /// The current best PR (the first of [bests]), or null with no PR.
  static PersonalRecord? currentBest(
    Iterable<PersonalRecord> records,
    Measure measure,
  ) {
    final all = bests(records, measure);
    return all.isEmpty ? null : all.first.record;
  }

  /// Positive when [a] is better than [b] (same series).
  static int compare(PersonalRecord a, PersonalRecord b, Measure measure) {
    int by(num? x, num? y) => (x ?? 0).compareTo(y ?? 0);
    switch (measure) {
      case Measure.reps:
        final byLoad = by(a.load, b.load);
        if (byLoad != 0) return byLoad;
        return by(a.reps ?? 1, b.reps ?? 1);
      case Measure.time:
        final byTime = by(a.seconds, b.seconds);
        if (byTime != 0) return byTime;
        return by(a.load, b.load);
    }
  }

  /// The [count] most recent PRs, newest first.
  static List<PersonalRecord> latest(
    Iterable<PersonalRecord> records,
    int count,
  ) {
    final sorted = records.toList()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    return sorted.take(count).toList();
  }
}
