import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';

part 'records.freezed.dart';

/// The best value of an exercise in one series (per unit for loads).
@freezed
abstract class PersonalRecord with _$PersonalRecord {
  const factory({
    required String exerciseId,
    required SeriesKey series,
    required double value,
    required LoggedSet set,
  }) = _PersonalRecord;
}

/// A set that beat a record when it was logged.
@freezed
abstract class RecordEvent with _$RecordEvent {
  const factory({
    required String exerciseId,
    required SeriesKey series,
    required double value,
    required double previous,
    required LoggedSet set,
  }) = _RecordEvent;
  const new _();

  String get setId => set.setId;
  String get workoutId => set.workoutId;
  DateTime get achievedAt => set.completedAt;
}

/// Personal records, computed from the logged sets and nothing else.
///
/// Per exercise: heaviest load per unit (any reps), most reps on sets with
/// no load, longest hold for time-based exercises.
abstract final class Records {
  /// The current records of every exercise in [sets]. When several sets
  /// share the best value, the earliest holds the record.
  static List<PersonalRecord> current(Iterable<LoggedSet> sets) {
    final best = <(String, SeriesKey), PersonalRecord>{};
    for (final set in _sorted(sets)) {
      final keyed = SeriesKey.of(set);
      if (keyed == null) continue;
      final (series, value) = keyed;
      final key = (set.exerciseId, series);
      final holder = best[key];
      if (holder == null || value > holder.value) {
        best[key] = PersonalRecord(
          exerciseId: set.exerciseId,
          series: series,
          value: value,
          set: set,
        );
      }
    }
    return best.values.toList();
  }

  /// Every set that was a new record when it was logged, oldest first.
  ///
  /// A set is a new record only when a record already existed from an
  /// earlier workout and the set beats it, and beats any earlier set of the
  /// same workout. The first workout of an exercise (or of a unit on that
  /// exercise) sets the baseline without a record.
  static List<RecordEvent> events(Iterable<LoggedSet> sets) {
    final events = <RecordEvent>[];
    // Best value from earlier workouts, and the workout being scanned.
    final baseline = <(String, SeriesKey), double>{};
    final running = <(String, SeriesKey), double>{};
    String? workoutId;

    void closeWorkout() {
      for (final entry in running.entries) {
        final previous = baseline[entry.key];
        if (previous == null || entry.value > previous) {
          baseline[entry.key] = entry.value;
        }
      }
      running.clear();
    }

    for (final set in _sorted(sets)) {
      if (set.workoutId != workoutId) {
        closeWorkout();
        workoutId = set.workoutId;
      }
      final keyed = SeriesKey.of(set);
      if (keyed == null) continue;
      final (series, value) = keyed;
      final key = (set.exerciseId, series);
      final before = baseline[key];
      final inWorkout = running[key];
      if (before != null) {
        final toBeat = inWorkout != null && inWorkout > before
            ? inWorkout
            : before;
        if (value > toBeat) {
          events.add(
            RecordEvent(
              exerciseId: set.exerciseId,
              series: series,
              value: value,
              previous: toBeat,
              set: set,
            ),
          );
        }
      }
      if (inWorkout == null || value > inWorkout) running[key] = value;
    }
    return events;
  }

  /// The records beaten during [workoutId], one per exercise and series:
  /// the best value reached, with the record that stood before the workout.
  static List<RecordEvent> ofWorkout(
    Iterable<RecordEvent> events,
    String workoutId,
  ) {
    final byKey = <(String, SeriesKey), RecordEvent>{};
    for (final event in events) {
      if (event.workoutId != workoutId) continue;
      final key = (event.exerciseId, event.series);
      final first = byKey[key];
      byKey[key] = first == null
          ? event
          : event.copyWith(previous: first.previous);
    }
    return byKey.values.toList();
  }

  /// The most recent record events, newest first.
  static List<RecordEvent> latest(Iterable<RecordEvent> events, int count) {
    final sorted = events.toList()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    return sorted.take(count).toList();
  }

  static List<LoggedSet> _sorted(Iterable<LoggedSet> sets) =>
      sets.toList()..sort(LoggedSet.chronological);
}
