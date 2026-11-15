import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';

part 'workout_draft.freezed.dart';

/// An exercise of a workout about to start: the session's plan, possibly
/// edited in the preview (changes apply to this workout only).
@freezed
abstract class WorkoutDraftExercise with _$WorkoutDraftExercise {
  const factory({
    required PlannedExercise plan,

    /// The planned exercise this one replaces, if it was swapped.
    String? swappedFrom,

    /// False when it was added in the preview.
    @Default(true) bool fromPlan,
  }) = _WorkoutDraftExercise;
}

/// Set targets when an exercise is swapped or added.
abstract final class SwapRule {
  /// Targets of the replacement exercise.
  ///
  /// Loads are not comparable between exercises, so they come from what was
  /// last done on the new exercise ([lastLoads], per set, may be shorter or
  /// empty) and are otherwise dropped. The goals are kept when both
  /// exercises are measured the same way, and reset to a default otherwise.
  static List<SetTarget> targets({
    required List<SetTarget> current,
    required Measure from,
    required Measure to,
    List<({double? load, String? unitId})> lastLoads = const [],
  }) {
    final fallback = to == Measure.reps
        ? SetTarget.defaultReps
        : SetTarget.defaultTime;
    final count = current.isEmpty ? 1 : current.length;
    return [
      for (var i = 0; i < count; i++)
        () {
          final goal = from == to && i < current.length ? current[i] : fallback;
          final last = lastLoads.isEmpty
              ? null
              : lastLoads[i < lastLoads.length ? i : lastLoads.length - 1];
          return SetTarget(
            reps: goal.reps,
            seconds: goal.seconds,
            isMax: goal.isMax,
            load: last?.load,
            unitId: last?.load == null ? null : last?.unitId,
          );
        }(),
    ];
  }
}
