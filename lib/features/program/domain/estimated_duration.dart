import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';

/// Estimated duration of a session or of what is left of a workout.
abstract final class EstimatedDuration {
  /// Seconds spent per repetition.
  static const int secondsPerRep = 3;

  /// Work time assumed for a "max" set.
  static const int maxSetSeconds = 40;

  /// Time to move to the next exercise and set it up.
  static const int changeoverSeconds = 60;

  /// How many past workouts of the session are averaged.
  static const int historyDepth = 3;

  /// Work time of one set.
  static int setSeconds(SetTarget target) {
    if (target.isMax) return maxSetSeconds;
    if (target.seconds case final s?) return s;
    if (target.reps case final r?) return r * secondsPerRep;
    return maxSetSeconds;
  }

  /// Duration computed from the plan: work, the rest after every set and
  /// the change of exercise.
  static int fromPlan(Iterable<PlannedExercise> plan) {
    var total = 0;
    for (final exercise in plan) {
      if (exercise.sets.isEmpty) continue;
      total += changeoverSeconds;
      for (final set in exercise.sets) {
        total += setSeconds(set) + exercise.restSeconds;
      }
    }
    return total;
  }

  /// Estimated duration of a session, in seconds: the average of the last
  /// [historyDepth] completed workouts of that session when there are any
  /// ([pastDurations], most recent first), otherwise [fromPlan].
  static int ofSession(
    Iterable<PlannedExercise> plan, {
    List<int> pastDurations = const [],
  }) {
    final recent = pastDurations.where((d) => d > 0).take(historyDepth);
    if (recent.isEmpty) return fromPlan(plan);
    return (recent.reduce((a, b) => a + b) / recent.length).round();
  }

  /// Rounds to whole minutes for display ("~55 min"); at least 1.
  static int minutes(int seconds) {
    final m = (seconds / 60).round();
    return m < 1 ? 1 : m;
  }
}
