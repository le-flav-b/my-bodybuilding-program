import 'package:freezed_annotation/freezed_annotation.dart';

part 'set_target.freezed.dart';
part 'set_target.g.dart';

/// What one set aims for: reps or time (a number or "max") and an optional
/// load with its unit. No load = bodyweight, negative load = assisted.
@freezed
abstract class SetTarget with _$SetTarget {
  const factory({
    int? reps,
    int? seconds,
    @Default(false) bool isMax,
    double? load,
    String? unitId,
  }) = _SetTarget;
  const new _();

  factory fromJson(Map<String, dynamic> json) => _$SetTargetFromJson(json);

  /// Default first set of a rep-based exercise.
  static const SetTarget defaultReps = SetTarget(reps: 10);

  /// Default first set of a time-based exercise.
  static const SetTarget defaultTime = SetTarget(seconds: 30);

  bool get hasLoad => load != null;

  /// Same reps/time goal, ignoring the load.
  bool sameGoal(SetTarget other) =>
      reps == other.reps && seconds == other.seconds && isMax == other.isMax;

  /// Same load and unit.
  bool sameLoad(SetTarget other) =>
      load == other.load && (load == null || unitId == other.unitId);

  /// A load always comes with a unit; a set without load has none.
  SetTarget normalized({required String defaultUnitId}) {
    if (load == null) return copyWith(unitId: null);
    return unitId == null ? copyWith(unitId: defaultUnitId) : this;
  }
}

/// One exercise of a plan, without row ids: used for workout drafts, the
/// plan snapshot kept on a workout and "Update the program?".
@freezed
abstract class PlannedExercise with _$PlannedExercise {
  const factory({
    required String exerciseId,
    required int restSeconds,
    required List<SetTarget> sets,
  }) = _PlannedExercise;

  factory fromJson(Map<String, dynamic> json) =>
      _$PlannedExerciseFromJson(json);
}
