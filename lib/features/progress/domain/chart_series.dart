import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';

part 'chart_series.freezed.dart';

/// Time range of a chart.
enum ChartRange {
  oneMonth('1M', 1),
  threeMonths('3M', 3),
  sixMonths('6M', 6),
  oneYear('1Y', 12),
  all('All', null);

  new(this.label, this.months);

  final String label;
  final int? months;

  /// The earliest instant shown, or null for everything.
  DateTime? start(DateTime now) {
    final m = months;
    if (m == null) return null;
    return DateTime.utc(now.year, now.month - m, now.day);
  }
}

/// One point of the timeline: the best set of a workout in one series.
@freezed
abstract class ChartPoint with _$ChartPoint {
  const factory({
    required String workoutId,
    required DateTime date,
    required double value,
    required LoggedSet bestSet,
    @Default(false) bool isRecord,
  }) = _ChartPoint;
}

/// The points of one series (one unit, or reps, or time), oldest first.
@freezed
abstract class ChartSeries with _$ChartSeries {
  const factory({required SeriesKey key, required List<ChartPoint> points}) =
      _ChartSeries;
}

/// Chart data of one exercise.
abstract final class ChartSeriesBuilder {
  /// One point per workout and per series: the best load for loaded sets
  /// (one series per unit), the best reps for sets with no load, the best
  /// time for time-based exercises.
  ///
  /// Series come in order of first use, so each unit keeps its colour. A
  /// point is a record when it beats every earlier point of its series (the
  /// first point is only the baseline). [from] cuts the timeline after the
  /// records are computed, so they stay relative to the whole history.
  static List<ChartSeries> build(Iterable<LoggedSet> sets, {DateTime? from}) {
    final sorted = sets.toList()..sort(LoggedSet.chronological);
    final series = <SeriesKey, List<ChartPoint>>{};
    final best = <SeriesKey, double>{};

    var index = 0;
    while (index < sorted.length) {
      final workoutId = sorted[index].workoutId;
      // Best set of this workout in each series.
      final top = <SeriesKey, (double, LoggedSet)>{};
      while (index < sorted.length && sorted[index].workoutId == workoutId) {
        final set = sorted[index++];
        final keyed = SeriesKey.of(set);
        if (keyed == null) continue;
        final (key, value) = keyed;
        final current = top[key];
        if (current == null || value > current.$1) top[key] = (value, set);
      }
      for (final entry in top.entries) {
        final (value, set) = entry.value;
        final previous = best[entry.key];
        series
            .putIfAbsent(entry.key, () => [])
            .add(
              ChartPoint(
                workoutId: workoutId,
                date: set.workoutStartedAt,
                value: value,
                bestSet: set,
                isRecord: previous != null && value > previous,
              ),
            );
        if (previous == null || value > previous) best[entry.key] = value;
      }
    }

    return [
      for (final entry in series.entries)
        ChartSeries(
          key: entry.key,
          points: from == null
              ? entry.value
              : [
                  for (final p in entry.value)
                    if (!p.date.isBefore(from)) p,
                ],
        ),
    ];
  }

  /// Small trend line of an exercise: the values of its most used series.
  static List<double> sparkline(
    Iterable<LoggedSet> sets, {
    int maxPoints = 12,
  }) {
    final all = build(sets);
    if (all.isEmpty) return const [];
    final main = all.reduce(
      (a, b) => b.points.length > a.points.length ? b : a,
    );
    final values = [for (final p in main.points) p.value];
    return values.length <= maxPoints
        ? values
        : values.sublist(values.length - maxPoints);
  }
}
