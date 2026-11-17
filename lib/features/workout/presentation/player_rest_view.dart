import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/big_button.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_parts.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_widgets.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// The set logged last in [detail], with its exercise.
(WorkoutExercise, WorkoutSet)? lastLoggedSet(WorkoutDetail detail) {
  (WorkoutExercise, WorkoutSet)? best;
  for (final e in detail.exercises) {
    for (final s in e.doneSets) {
      if (best == null || s.completedAt!.isAfter(best.$2.completedAt!)) {
        best = (e, s);
      }
    }
  }
  return best;
}

/// What comes after the rest: the next set of the current exercise, or the
/// first set of the next exercise.
(WorkoutExercise, WorkoutSet)? nextUp(WorkoutDetail detail) {
  final current = detail.currentExercise;
  if (current == null) return null;
  if (!current.isSkipped) {
    if (current.nextSet case final set?) return (current, set);
  }
  final next = detail.nextUnfinishedAfter(current.id);
  final set = next?.nextSet;
  return next == null || set == null ? null : (next, set);
}

/// Between two sets: what was just logged (with Edit), the rest ring with
/// −15 / Skip / +15, and what comes next.
class RestView extends ConsumerWidget {
  const new({required this.detail, super.key});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final workout = detail.workout;
    final now = ref.watch(nowProvider);
    final remaining = WorkoutClock.restRemainingSeconds(workout, now);
    final total = workout.restTotalSeconds ?? remaining;
    final controller = ref.read(workoutControllerProvider);
    final logged = lastLoggedSet(detail);
    final next = nextUp(detail);

    Widget roundButton(String label, int delta) => SizedBox.square(
      dimension: 64,
      child: IconButton(
        tooltip: label,
        style: IconButton.styleFrom(
          backgroundColor: colors.surfaceContainerHigh,
          foregroundColor: colors.onSurface,
        ),
        onPressed: () => unawaited(controller.adjustRest(workout.id, delta)),
        icon: Text(
          label,
          style: context.text.titleMedium!.copyWith(
            fontSize: 18,
            fontFeatures: AppTheme.tabular,
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          if (logged case (final exercise, final set)) ...[
            _LoggedCard(exercise: exercise, set: set),
            const SizedBox(height: AppSpacing.xl),
          ],
          TimerRing(
            fraction: total <= 0 ? 0 : remaining / total,
            color: context.appColors.brand,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Overline(
                  Strings.restLabel,
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                ),
                Text(
                  PlanFormat.clock(remaining),
                  style: AppTheme.timer.copyWith(color: colors.onSurface),
                ),
                Text(
                  Strings.ofTotal(PlanFormat.clock(total)),
                  style: context.text.bodyLarge!.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              roundButton('−15', -15),
              const SizedBox(width: AppSpacing.md),
              BigButton(
                tonal: true,
                icon: Symbols.skip_next_rounded,
                label: Strings.skip,
                onPressed: () => unawaited(controller.completeRest(workout.id)),
              ),
              const SizedBox(width: AppSpacing.md),
              roundButton('+15', 15),
            ],
          ),
          if (next case (final exercise, final set)) ...[
            const SizedBox(height: AppSpacing.xl),
            _NextUpCard(
              exercise: exercise,
              set: set,
              sameExercise: exercise.id == detail.currentExercise?.id,
            ),
          ],
        ],
      ),
    );
  }
}

class _LoggedCard extends ConsumerWidget {
  const new({required this.exercise, required this.set});

  final WorkoutExercise exercise;
  final WorkoutSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(unitLookupProvider);
    final name = ref.watch(exerciseProvider(exercise.exerciseId))?.name ?? '';
    final value = PlanFormat.set(
      reps: set.reps,
      seconds: set.seconds,
      loadValue: set.load,
      unitId: set.unitId,
      units: units,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const DoneMark(size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.setLogged(exercise.sets.indexOf(set) + 1, value),
                  style: context.text.titleMedium!.copyWith(
                    fontSize: 18,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
                Text(Strings.loggedOn(name), style: context.text.bodyMedium),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                unawaited(editLoggedSetFlow(context, ref, exercise, set)),
            child: const Text(Strings.edit),
          ),
        ],
      ),
    );
  }
}

class _NextUpCard extends ConsumerWidget {
  const new({
    required this.exercise,
    required this.set,
    required this.sameExercise,
  });

  final WorkoutExercise exercise;
  final WorkoutSet set;
  final bool sameExercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(unitLookupProvider);
    final name = ref.watch(exerciseProvider(exercise.exerciseId))?.name ?? '';
    final index = exercise.sets.indexOf(set);
    final last = lastAt(
      ref.watch(lastTimeSetsProvider(exercise.exerciseId)),
      index,
    );
    final t = set.target;
    final target = PlanFormat.set(
      reps: t.reps,
      seconds: t.seconds,
      isMax: t.isMax,
      loadValue: t.load,
      unitId: t.unitId,
      units: units,
    );
    final lastText = last == null
        ? ''
        : ' ${PlanFormat.dot} ${Strings.lastShort(shortSetText(last.reps, last.seconds, last.load, units(last.unitId ?? '')))}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          ExerciseThumb(exerciseId: exercise.exerciseId, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Overline(
                  sameExercise
                      ? Strings.nextSetOf(index + 1, exercise.sets.length)
                      : Strings.nextUpExercise,
                  color: colors.onSurfaceVariant,
                ),
                Text(
                  target,
                  style: context.text.titleMedium!.copyWith(
                    fontSize: 18,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
                Text(
                  '$name$lastText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium!.copyWith(
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
