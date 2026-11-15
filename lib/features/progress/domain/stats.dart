import 'package:freezed_annotation/freezed_annotation.dart';

part 'stats.freezed.dart';

/// A completed workout as lists and stats need it.
@freezed
abstract class WorkoutSummary with _$WorkoutSummary {
  const factory({
    required String id,
    required String sessionName,
    required DateTime startedAt,
    required int durationSeconds,
    required int setCount,
    required int exerciseCount,
    String? sessionId,
    DateTime? endedAt,
    @Default(0) int recordCount,
  }) = _WorkoutSummary;
}

/// Workouts and time trained over a period.
@freezed
abstract class PeriodTotals with _$PeriodTotals {
  const factory({
    @Default(0) int workouts,
    @Default(0) int seconds,
    @Default(0) int sets,
  }) = _PeriodTotals;
}

/// The numbers of the Profile.
@freezed
abstract class Stats with _$Stats {
  const factory({
    @Default(PeriodTotals()) PeriodTotals total,
    @Default(PeriodTotals()) PeriodTotals thisMonth,
    @Default(PeriodTotals()) PeriodTotals lastMonth,
  }) = _Stats;
}

/// Totals and month comparison, computed from the completed workouts.
abstract final class StatsRule {
  /// [now] is local; workouts are bucketed by their local start month.
  static Stats compute(Iterable<WorkoutSummary> workouts, DateTime now) {
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    var total = const PeriodTotals();
    var current = const PeriodTotals();
    var previous = const PeriodTotals();

    PeriodTotals add(PeriodTotals totals, WorkoutSummary w) => PeriodTotals(
      workouts: totals.workouts + 1,
      seconds: totals.seconds + w.durationSeconds,
      sets: totals.sets + w.setCount,
    );

    for (final workout in workouts) {
      total = add(total, workout);
      final local = workout.startedAt.toLocal();
      final month = DateTime(local.year, local.month);
      if (month == thisMonth) current = add(current, workout);
      if (month == lastMonth) previous = add(previous, workout);
    }
    return Stats(total: total, thisMonth: current, lastMonth: previous);
  }

  /// Totals of the workouts started in the month of [month] (local).
  static PeriodTotals ofMonth(
    Iterable<WorkoutSummary> workouts,
    DateTime month,
  ) {
    var totals = const PeriodTotals();
    for (final w in workouts) {
      final local = w.startedAt.toLocal();
      if (local.year == month.year && local.month == month.month) {
        totals = PeriodTotals(
          workouts: totals.workouts + 1,
          seconds: totals.seconds + w.durationSeconds,
          sets: totals.sets + w.setCount,
        );
      }
    }
    return totals;
  }
}
