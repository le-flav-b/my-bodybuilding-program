import 'package:intl/intl.dart';
import 'package:my_bodybuilding_program/app/strings.dart';

/// Dates as the app shows them. Inputs may be UTC; everything is displayed
/// in local time.
abstract final class DateText {
  static DateTime _day(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Whole calendar days from [date] to [now] (0 = same day).
  static int daysBetween(DateTime date, DateTime now) {
    final a = _day(date);
    final b = _day(now);
    return DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
  }

  /// "today", "yesterday", "4 days ago".
  static String relativeDay(DateTime date, DateTime now) =>
      switch (daysBetween(date, now)) {
        <= 0 => Strings.today,
        1 => Strings.yesterday,
        final n => Strings.daysAgo(n),
      };

  /// "Sunday 15 November".
  static String longDay(DateTime date) =>
      DateFormat('EEEE d MMMM', 'en').format(date.toLocal());

  /// "Sunday 15 Nov".
  static String mediumDay(DateTime date) =>
      DateFormat('EEEE d MMM', 'en').format(date.toLocal());

  /// "18:04".
  static String time(DateTime date) =>
      DateFormat('HH:mm', 'en').format(date.toLocal());

  /// "Mon", "Tue"…
  static String weekdayShort(DateTime date) =>
      DateFormat('EEE', 'en').format(date);
}
