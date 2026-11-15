import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';

part 'plan_diff.freezed.dart';

/// One difference between the session's plan and what the workout became.
@freezed
sealed class PlanChange with _$PlanChange {
  /// [fromExerciseId] was replaced by [toExerciseId].
  const factory swapped({
    required String fromExerciseId,
    required String toExerciseId,
  }) = PlanSwapped;

  /// An exercise was added during the workout.
  const factory added({required String exerciseId}) = PlanAdded;

  /// A planned exercise was removed.
  const factory removed({required String exerciseId}) = PlanRemoved;

  /// Sets or loads of an exercise changed.
  const factory setsChanged({
    required String exerciseId,
    required List<SetTarget> before,
    required List<SetTarget> after,
  }) = PlanSetsChanged;

  /// The exercises were done in another order.
  const factory reordered() = PlanReordered;

  /// An exercise was skipped. Informational: it stays in the program.
  const factory skipped({required String exerciseId}) = PlanSkipped;
}

/// The plan a workout would write back, with what is needed to describe the
/// changes.
@freezed
abstract class EffectiveExercise with _$EffectiveExercise {
  const factory({
    required PlannedExercise plan,
    String? swappedFrom,
    @Default(false) bool skipped,
  }) = _EffectiveExercise;
}

/// "Update the program?" rules.
abstract final class PlanDiff {
  /// The plan a workout stands for.
  ///
  /// Each set keeps its target; its load and unit are the ones actually
  /// logged when the set was done (lifting 42.5 instead of 40 is a plan
  /// change, doing 9 reps instead of 10 is not). Sets left undone and
  /// skipped exercises keep their plan. Exercises without any set are
  /// dropped.
  static List<EffectiveExercise> effectivePlan(WorkoutDetail detail) {
    // Sets already done on an exercise before it was swapped mid-way: their
    // goals go back in front of the replacement's sets, without the loads.
    final remainders = <String, List<SetTarget>>{};
    final result = <EffectiveExercise>[];
    for (final e in detail.exercises) {
      if (e.sets.isEmpty) continue;
      if (e.isSwapRemainder) {
        remainders[e.exerciseId] = [
          for (final s in e.sets)
            SetTarget(
              reps: s.target.reps,
              seconds: s.target.seconds,
              isMax: s.target.isMax,
            ),
        ];
        continue;
      }
      final carried = e.swappedFrom == null
          ? null
          : remainders.remove(e.swappedFrom);
      result.add(
        EffectiveExercise(
          swappedFrom: e.swappedFrom,
          skipped: e.isSkipped,
          plan: PlannedExercise(
            exerciseId: e.exerciseId,
            restSeconds: e.restSeconds,
            sets: [
              ...?carried,
              for (final s in e.sets)
                if (s.isDone)
                  s.target.copyWith(
                    load: s.load,
                    unitId: s.load == null ? null : s.unitId,
                  )
                else
                  s.target,
            ],
          ),
        ),
      );
    }
    return result;
  }

  /// The differences between the plan at start ([original]) and the
  /// workout's [current] plan, in display order: swaps, additions,
  /// removals, set changes, order, then skipped exercises.
  static List<PlanChange> diff(
    List<PlannedExercise> original,
    List<EffectiveExercise> current,
  ) {
    final matched = List<int?>.filled(current.length, null);
    final taken = List<bool>.filled(original.length, false);

    int? claim(String exerciseId) {
      for (var i = 0; i < original.length; i++) {
        if (!taken[i] && original[i].exerciseId == exerciseId) {
          taken[i] = true;
          return i;
        }
      }
      return null;
    }

    // Exercises still in the plan first, so a swap cannot steal their slot.
    for (var i = 0; i < current.length; i++) {
      if (current[i].swappedFrom == null) {
        matched[i] = claim(current[i].plan.exerciseId);
      }
    }
    final swaps = <PlanChange>[];
    for (var i = 0; i < current.length; i++) {
      final from = current[i].swappedFrom;
      if (from == null) continue;
      final index = claim(from);
      if (index != null) {
        matched[i] = index;
        if (from != current[i].plan.exerciseId) {
          swaps.add(
            PlanChange.swapped(
              fromExerciseId: from,
              toExerciseId: current[i].plan.exerciseId,
            ),
          );
        }
      } else {
        matched[i] = claim(current[i].plan.exerciseId);
      }
    }

    final added = <PlanChange>[];
    final setChanges = <PlanChange>[];
    for (var i = 0; i < current.length; i++) {
      final entry = current[i];
      final index = matched[i];
      if (index == null) {
        added.add(PlanChange.added(exerciseId: entry.plan.exerciseId));
        continue;
      }
      final before = original[index];
      final swapped = before.exerciseId != entry.plan.exerciseId;
      if (!swapped && !_sameSets(before.sets, entry.plan.sets)) {
        setChanges.add(
          PlanChange.setsChanged(
            exerciseId: entry.plan.exerciseId,
            before: before.sets,
            after: entry.plan.sets,
          ),
        );
      }
    }

    final removed = [
      for (var i = 0; i < original.length; i++)
        if (!taken[i]) PlanChange.removed(exerciseId: original[i].exerciseId),
    ];

    final order = [for (final index in matched) ?index];
    var reordered = false;
    for (var i = 1; i < order.length; i++) {
      if (order[i] < order[i - 1]) reordered = true;
    }

    return [
      ...swaps,
      ...added,
      ...removed,
      ...setChanges,
      if (reordered) const PlanChange.reordered(),
      for (final entry in current)
        if (entry.skipped)
          PlanChange.skipped(exerciseId: entry.plan.exerciseId),
    ];
  }

  /// Whether applying the changes would modify the program (skipped
  /// exercises alone do not).
  static bool changesProgram(List<PlanChange> changes) =>
      changes.any((c) => c is! PlanSkipped);

  /// The plan to write back to the session.
  static List<PlannedExercise> planToSave(List<EffectiveExercise> current) => [
    for (final e in current) e.plan,
  ];

  static bool _sameSets(List<SetTarget> a, List<SetTarget> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!a[i].sameGoal(b[i]) || !a[i].sameLoad(b[i])) return false;
    }
    return true;
  }
}
