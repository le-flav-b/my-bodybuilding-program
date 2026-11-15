import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak.freezed.dart';

/// Weekly streak figures.
@freezed
abstract class Streak with _$Streak {
  const factory({
    /// Consecutive weeks that reached the target, up to now.
    required int current,

    /// Longest run ever.
    required int best,

    /// Workouts done in the current week.
    required int thisWeek,
    required int weeklyTarget,
  }) = _Streak;
  const new _();

  bool get weekReached => thisWeek >= weeklyTarget;
}

/// Calendar helpers and the streak rule. All dates are local.
abstract final class StreakRule {
  /// Midnight of [date]'s day.
  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Monday of [date]'s week (weeks run Monday to Sunday).
  static DateTime weekStart(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  /// The Monday [weeks] weeks before/after [monday].
  static DateTime shiftWeek(DateTime monday, int weeks) =>
      DateTime(monday.year, monday.month, monday.day + 7 * weeks);

  /// Workouts per week, keyed by the Monday of the week.
  static Map<DateTime, int> perWeek(Iterable<DateTime> workoutDates) {
    final counts = <DateTime, int>{};
    for (final date in workoutDates) {
      counts.update(weekStart(date), (c) => c + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// The streak: consecutive Monday-to-Sunday weeks with at least
  /// [weeklyTarget] completed workouts.
  ///
  /// Rest days never break it. The current week counts as soon as its
  /// target is reached; until then it neither counts nor breaks the streak.
  static Streak compute(
    Iterable<DateTime> workoutDates, {
    required int weeklyTarget,
    required DateTime today,
  }) {
    final target = weeklyTarget < 1 ? 1 : weeklyTarget;
    final counts = perWeek(workoutDates);
    final thisMonday = weekStart(today);
    final thisWeek = counts[thisMonday] ?? 0;
    bool reached(DateTime monday) => (counts[monday] ?? 0) >= target;

    var current = 0;
    var cursor = reached(thisMonday) ? thisMonday : shiftWeek(thisMonday, -1);
    while (reached(cursor)) {
      current++;
      cursor = shiftWeek(cursor, -1);
    }

    var best = 0;
    final mondays = counts.keys.where(reached).toList()..sort();
    var run = 0;
    DateTime? previous;
    for (final monday in mondays) {
      run = previous != null && shiftWeek(previous, 1) == monday ? run + 1 : 1;
      if (run > best) best = run;
      previous = monday;
    }
    if (current > best) best = current;

    return Streak(
      current: current,
      best: best,
      thisWeek: thisWeek,
      weeklyTarget: target,
    );
  }
}
