import 'package:freezed_annotation/freezed_annotation.dart';

part 'body_weight.freezed.dart';

/// A weigh-in.
@freezed
abstract class BodyWeight with _$BodyWeight {
  const factory({
    required String id,
    required DateTime measuredAt,
    required double weightKg,
    String? note,
  }) = _BodyWeight;
}

/// Trend figures of the bodyweight log.
abstract final class BodyWeightTrend {
  /// The most recent entry, or null.
  static BodyWeight? latest(Iterable<BodyWeight> entries) {
    BodyWeight? latest;
    for (final e in entries) {
      if (latest == null || e.measuredAt.isAfter(latest.measuredAt)) latest = e;
    }
    return latest;
  }

  /// Change of the latest weight compared with [days] days earlier: the
  /// reference is the last entry at least [days] days older than the latest
  /// one, or the oldest entry when the log is shorter than that. Null with
  /// fewer than two entries.
  static double? changeOver(Iterable<BodyWeight> entries, {required int days}) {
    final sorted = entries.toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    if (sorted.length < 2) return null;
    final last = sorted.last;
    final limit = last.measuredAt.subtract(Duration(days: days));
    var reference = sorted.first;
    for (final e in sorted) {
      if (!e.measuredAt.isAfter(limit)) reference = e;
    }
    return _round(last.weightKg - reference.weightKg);
  }

  /// Change of each entry from the previous one (older), keyed by entry id.
  static Map<String, double> changes(Iterable<BodyWeight> entries) {
    final sorted = entries.toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return {
      for (var i = 1; i < sorted.length; i++)
        sorted[i].id: _round(sorted[i].weightKg - sorted[i - 1].weightKg),
    };
  }

  static double _round(double value) => (value * 10).round() / 10;
}
