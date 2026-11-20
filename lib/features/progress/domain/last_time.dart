import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';

/// "Last time": what was done on an exercise in the most recent completed
/// workout that contains it.
abstract final class LastTime {
  /// The sets of the most recent workout in [sets] (all of one exercise),
  /// in the order they were done. [excludeWorkoutId] leaves a workout out.
  static List<LoggedSet> sets(
    Iterable<LoggedSet> sets, {
    String? excludeWorkoutId,
  }) {
    final candidates = [
      for (final s in sets)
        if (s.workoutId != excludeWorkoutId) s,
    ]..sort(LoggedSet.chronological);
    if (candidates.isEmpty) return const [];
    final lastWorkoutId = candidates.last.workoutId;
    return [
      for (final s in candidates)
        if (s.workoutId == lastWorkoutId) s,
    ];
  }

  /// The set to compare set number [index] (0-based) with: the same set
  /// number last time, or the last set done when there were fewer.
  static LoggedSet? forSetIndex(List<LoggedSet> lastSets, int index) {
    if (lastSets.isEmpty) return null;
    return index < lastSets.length ? lastSets[index] : lastSets.last;
  }
}
