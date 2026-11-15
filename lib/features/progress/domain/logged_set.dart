import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';

part 'logged_set.freezed.dart';

/// A completed set of a completed workout, flattened for the derived data
/// (records, charts, last time, stats). Everything is computed from these.
@freezed
abstract class LoggedSet with _$LoggedSet {
  const factory({
    required String setId,
    required String workoutId,
    required DateTime workoutStartedAt,
    required String exerciseId,
    required Measure measure,
    required DateTime completedAt,
    @Default('') String sessionName,

    /// Order of the set inside its workout (exercise, then set position).
    @Default(0) int order,
    int? reps,
    int? seconds,
    double? load,
    String? unitId,
  }) = _LoggedSet;
  const new _();

  /// Chronological order: workout, then order inside the workout.
  static int chronological(LoggedSet a, LoggedSet b) {
    final byWorkout = a.workoutStartedAt.compareTo(b.workoutStartedAt);
    if (byWorkout != 0) return byWorkout;
    final byId = a.workoutId.compareTo(b.workoutId);
    if (byId != 0) return byId;
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) return byOrder;
    return a.completedAt.compareTo(b.completedAt);
  }
}

/// What a set is measured by, which decides its record and chart series:
/// loaded sets by load (one series per unit), sets with no load by reps,
/// time-based exercises by time.
@freezed
sealed class SeriesKey with _$SeriesKey {
  const factory load({required String unitId}) = LoadSeries;
  const factory reps() = RepsSeries;
  const factory time() = TimeSeries;

  const new _();

  /// The series a set belongs to, with its value; null when the set has no
  /// usable value.
  static (SeriesKey, double)? of(LoggedSet set) {
    switch (set.measure) {
      case Measure.time:
        final seconds = set.seconds;
        return seconds == null ? null : (const TimeSeries(), seconds * 1.0);
      case Measure.reps:
        final load = set.load;
        final unitId = set.unitId;
        if (load != null && unitId != null) {
          return (LoadSeries(unitId: unitId), load);
        }
        final reps = set.reps;
        return reps == null ? null : (const RepsSeries(), reps * 1.0);
    }
  }
}
