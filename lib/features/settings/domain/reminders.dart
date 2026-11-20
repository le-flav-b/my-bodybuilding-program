import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:timezone/timezone.dart' as tz;

part 'reminders.freezed.dart';

/// The two reminders of Settings › Reminders.
enum ReminderKind { training, weighIn }

/// Reminder preferences, stored as settings rows. Both reminders are off by
/// default.
@freezed
abstract class ReminderSettings with _$ReminderSettings {
  const factory({
    @Default(false) bool trainingEnabled,

    /// ISO weekdays (1 = Monday … 7 = Sunday), sorted, never empty.
    @Default(ReminderSettings.defaultTrainingDays) List<int> trainingDays,

    /// Local time of day, in minutes after midnight.
    @Default(ReminderSettings.defaultTrainingMinutes) int trainingMinutes,
    @Default(false) bool weighInEnabled,

    /// "Remind me after N days without a weigh-in".
    @Default(ReminderSettings.defaultWeighInAfterDays) int weighInAfterDays,
    @Default(ReminderSettings.defaultWeighInMinutes) int weighInMinutes,
  }) = _ReminderSettings;
  const new _();

  static const List<int> defaultTrainingDays = [1, 3, 5];
  static const int defaultTrainingMinutes = 18 * 60;
  static const int defaultWeighInAfterDays = 14;
  static const int defaultWeighInMinutes = 8 * 60;
  static const int minAfterDays = 1;
  static const int maxAfterDays = 60;
  static const int minutesPerDay = 24 * 60;

  bool get anyEnabled => trainingEnabled || weighInEnabled;

  /// Parses "1,3,5" into sorted, distinct ISO weekdays; the default when
  /// nothing valid is left.
  static List<int> parseDays(String? raw) {
    final days = {
      for (final part in (raw ?? '').split(','))
        if (int.tryParse(part.trim()) case final d?)
          if (d >= DateTime.monday && d <= DateTime.sunday) d,
    }.toList()..sort();
    return days.isEmpty ? defaultTrainingDays : days;
  }

  /// A time of day kept inside one day.
  static int clampMinutes(int minutes) => minutes.clamp(0, minutesPerDay - 1);

  static int clampAfterDays(int days) => days.clamp(minAfterDays, maxAfterDays);
}

/// What the reminders depend on, read from the database.
@freezed
abstract class ReminderFacts with _$ReminderFacts {
  const factory({
    /// Name of the next session of the program; null when it is empty.
    String? nextSessionName,
    @Default(false) bool workoutInProgress,

    /// End of the most recent completed workout.
    DateTime? lastWorkoutEndedAt,

    /// Time of the most recent bodyweight entry.
    DateTime? lastWeighInAt,
  }) = _ReminderFacts;
}

/// One reminder to show at [at].
@freezed
abstract class ReminderOccurrence with _$ReminderOccurrence {
  const factory({
    required ReminderKind kind,

    /// The local calendar day it belongs to (a date at midnight UTC).
    required DateTime day,

    /// The instant it fires (UTC).
    required DateTime at,

    /// Weigh-in only: whole days since the last weigh-in, null when there
    /// is none yet.
    int? daysSinceWeighIn,
  }) = _ReminderOccurrence;
  const new _();

  /// Stable notification id: one per kind and day, so a re-plan only
  /// touches what changed.
  int get id =>
      (kind == ReminderKind.training ? trainingIdBase : weighInIdBase) +
      day.year * 10000 +
      day.month * 100 +
      day.day;

  static const int trainingIdBase = 100000000;
  static const int weighInIdBase = 200000000;

  /// True for the ids of reminders (the workout notifications use small
  /// ids).
  static bool isReminderId(int id) => id >= trainingIdBase;
}

/// Turns the reminder settings and facts into the reminders to schedule.
///
/// Each reminder is a one-shot notification planned [horizonDays] ahead and
/// planned again whenever its inputs change or the app opens. Times are
/// local wall-clock times in [tz.Location], so they stay right across
/// daylight-saving changes.
abstract final class ReminderPlanner {
  /// Eight weeks.
  static const int horizonDays = 56;

  static List<ReminderOccurrence> plan({
    required ReminderSettings settings,
    required ReminderFacts facts,
    required DateTime now,
    required tz.Location location,
  }) => [
    if (settings.trainingEnabled)
      ...training(
        settings: settings,
        facts: facts,
        now: now,
        location: location,
      ),
    if (settings.weighInEnabled)
      ...weighIn(
        settings: settings,
        facts: facts,
        now: now,
        location: location,
      ),
  ]..sort((a, b) => a.at.compareTo(b.at));

  /// On each chosen weekday at the chosen time, except today when a workout
  /// already ended today or one is in progress.
  static List<ReminderOccurrence> training({
    required ReminderSettings settings,
    required ReminderFacts facts,
    required DateTime now,
    required tz.Location location,
  }) {
    final today = localDay(now, location);
    final trainedToday =
        facts.workoutInProgress ||
        (facts.lastWorkoutEndedAt != null &&
            localDay(facts.lastWorkoutEndedAt!, location) == today);
    return [
      for (final (day, at) in _slots(now, location, settings.trainingMinutes))
        if (settings.trainingDays.contains(day.weekday) &&
            !(day == today && trainedToday))
          ReminderOccurrence(kind: ReminderKind.training, day: day, at: at),
    ];
  }

  /// Every day at the chosen time once the last weigh-in is
  /// [ReminderSettings.weighInAfterDays] days old or more (or there is
  /// none), until a new weight is logged.
  static List<ReminderOccurrence> weighIn({
    required ReminderSettings settings,
    required ReminderFacts facts,
    required DateTime now,
    required tz.Location location,
  }) {
    final last = facts.lastWeighInAt == null
        ? null
        : localDay(facts.lastWeighInAt!, location);
    return [
      for (final (day, at) in _slots(now, location, settings.weighInMinutes))
        if (last == null || daysBetween(last, day) >= settings.weighInAfterDays)
          ReminderOccurrence(
            kind: ReminderKind.weighIn,
            day: day,
            at: at,
            daysSinceWeighIn: last == null ? null : daysBetween(last, day),
          ),
    ];
  }

  /// The local day of [instant], as a date at midnight UTC.
  static DateTime localDay(DateTime instant, tz.Location location) {
    final local = tz.TZDateTime.from(instant, location);
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Whole calendar days from [from] to [to] (dates from [localDay]).
  static int daysBetween(DateTime from, DateTime to) =>
      to.difference(from).inDays;

  /// The instant of [minutes] after midnight on [day] in [location]. A
  /// time that doesn't exist that day (clocks going forward) moves forward
  /// by the gap.
  static DateTime instantOf(DateTime day, int minutes, tz.Location location) =>
      tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
        minutes ~/ 60,
        minutes % 60,
      ).toUtc();

  /// Each day of the horizon with its instant at [minutes], from the first
  /// one still to come.
  static Iterable<(DateTime, DateTime)> _slots(
    DateTime now,
    tz.Location location,
    int minutes,
  ) sync* {
    final today = localDay(now, location);
    for (var i = 0; i < horizonDays; i++) {
      final day = DateTime.utc(today.year, today.month, today.day + i);
      final at = instantOf(day, minutes, location);
      if (at.isAfter(now)) yield (day, at);
    }
  }
}
