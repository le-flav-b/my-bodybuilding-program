import 'package:my_bodybuilding_program/features/progress/domain/streak.dart';

/// Whether a week reached the weekly target (calendar's week column).
enum WeekStatus {
  /// The target was reached.
  reached,

  /// The week is over and the target was missed.
  missed,

  /// The current week, target not reached yet.
  current,

  /// A week that has not started yet.
  future,
}

/// One row of the calendar: a Monday-to-Sunday week.
class CalendarWeek {
  const new({required this.monday, required this.days, required this.status});

  final DateTime monday;

  /// The 7 days, Monday first (some belong to the next/previous month).
  final List<DateTime> days;
  final WeekStatus status;
}

/// The month view of the Progress calendar. Dates are local.
abstract final class CalendarRule {
  /// The weeks shown for [month] (any day of it): from the week of its
  /// first day to the week of its last day.
  static List<CalendarWeek> weeks(
    DateTime month, {
    required Iterable<DateTime> workoutDates,
    required int weeklyTarget,
    required DateTime today,
  }) {
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    final counts = StreakRule.perWeek(workoutDates);
    final thisMonday = StreakRule.weekStart(today);
    final target = weeklyTarget < 1 ? 1 : weeklyTarget;
    final weeks = <CalendarWeek>[];
    for (
      var monday = StreakRule.weekStart(first);
      !monday.isAfter(last);
      monday = StreakRule.shiftWeek(monday, 1)
    ) {
      final reached = (counts[monday] ?? 0) >= target;
      final status = reached
          ? WeekStatus.reached
          : monday == thisMonday
          ? WeekStatus.current
          : monday.isAfter(thisMonday)
          ? WeekStatus.future
          : WeekStatus.missed;
      weeks.add(
        CalendarWeek(
          monday: monday,
          days: [
            for (var i = 0; i < 7; i++)
              DateTime(monday.year, monday.month, monday.day + i),
          ],
          status: status,
        ),
      );
    }
    return weeks;
  }

  /// Workouts per day (local midnight → count).
  static Map<DateTime, int> perDay(Iterable<DateTime> workoutDates) {
    final counts = <DateTime, int>{};
    for (final date in workoutDates) {
      counts.update(StreakRule.dayOf(date), (c) => c + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}
