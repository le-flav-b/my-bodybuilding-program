import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';

/// Time rules of a workout: duration without pauses, auto-finish, rest.
abstract final class WorkoutClock {
  /// A workout with no action for this long is finished automatically.
  static const Duration autoFinishAfter = Duration(hours: 12);

  /// Seconds trained so far (or in total once ended), pauses excluded.
  static int elapsedSeconds(Workout workout, DateTime now) {
    final end = workout.endedAt ?? workout.pausedAt ?? now;
    final seconds =
        end.difference(workout.startedAt).inSeconds - workout.pausedSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  /// Whether an in-progress workout has been idle for more than 12 h
  /// (paused or not).
  static bool shouldAutoFinish(Workout workout, DateTime now) =>
      workout.isInProgress &&
      now.difference(workout.lastActivityAt) > autoFinishAfter;

  /// When an auto-finished workout is considered to have ended: its last
  /// activity (which is the pause time when it was left paused).
  static DateTime autoFinishEnd(Workout workout) {
    final paused = workout.pausedAt;
    if (paused != null && paused.isBefore(workout.lastActivityAt)) {
      return paused;
    }
    return workout.lastActivityAt;
  }

  /// Seconds of rest left; 0 when no rest is running or it is over. While
  /// paused the rest is frozen at the pause time.
  static int restRemainingSeconds(Workout workout, DateTime now) {
    final endsAt = workout.restEndsAt;
    if (endsAt == null) return 0;
    final reference = workout.pausedAt ?? now;
    final ms = endsAt.difference(reference).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// New end of the rest after resuming from a pause that started at
  /// [pausedAt]: the rest is pushed back by the paused time.
  static DateTime? restEndAfterResume(
    DateTime? restEndsAt,
    DateTime pausedAt,
    DateTime now,
  ) => restEndsAt?.add(now.difference(pausedAt));

  /// Whole seconds between [pausedAt] and [now], never negative.
  static int pauseLength(DateTime pausedAt, DateTime now) {
    final seconds = now.difference(pausedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }
}
