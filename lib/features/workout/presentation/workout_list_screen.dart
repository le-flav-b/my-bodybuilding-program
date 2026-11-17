import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/big_button.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/session_preview_screen.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// Every exercise of the workout with its status: jump, reorder, swap,
/// skip, change unit, remove, add, finish.
class WorkoutListScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(activeWorkoutProvider).value;
    if (detail == null) return Scaffold(appBar: AppBar());
    final workout = detail.workout;
    final controller = ref.read(workoutControllerProvider);
    final elapsed = PlanFormat.clock(
      WorkoutClock.elapsedSeconds(workout, ref.watch(nowProvider)),
    );
    final done = detail.exercises
        .where((e) => e.isFinished && !e.isSkipped)
        .length;
    final current = detail.currentExercise?.id;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.exercisesOf(workout.sessionName)),
            Text(
              Strings.doneOf(elapsed, done, detail.exercises.length),
              style: context.text.bodyMedium!.copyWith(
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: workout.isPaused ? Strings.resume : Strings.pause,
            onPressed: () => unawaited(
              workout.isPaused
                  ? controller.resume(workout.id)
                  : controller.pause(workout.id),
            ),
            icon: Icon(
              workout.isPaused
                  ? Symbols.play_arrow_rounded
                  : Symbols.pause_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            sliver: SliverReorderableList(
              itemCount: detail.exercises.length,
              onReorderItem: (from, to) {
                final ids = [for (final e in detail.exercises) e.id];
                ids.insert(to, ids.removeAt(from));
                unawaited(controller.reorder(workout.id, ids));
              },
              itemBuilder: (context, index) {
                final e = detail.exercises[index];
                return _ListRow(
                  key: ValueKey(e.id),
                  index: index,
                  detail: detail,
                  exercise: e,
                  isCurrent: e.id == current && !e.isFinished,
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(4, 4, AppSpacing.lg, 24),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      unawaited(addExerciseFlow(context, ref, detail)),
                  icon: const Icon(Symbols.add_rounded),
                  label: const Text(Strings.addExercise),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: BigButton(
          expand: true,
          icon: Symbols.flag_rounded,
          label: Strings.finishWorkout,
          onPressed: () =>
              unawaited(finishWorkoutFlow(context, ref, workout.id)),
        ),
      ),
    );
  }
}

enum _Action { goTo, swap, skip, unskip, unit, remove }

class _ListRow extends ConsumerWidget {
  const new({
    required this.index,
    required this.detail,
    required this.exercise,
    required this.isCurrent,
    super.key,
  });

  final int index;
  final WorkoutDetail detail;
  final WorkoutExercise exercise;
  final bool isCurrent;

  List<(_Action, IconData, String)> get _actions => [
    if (!isCurrent)
      (_Action.goTo, Symbols.play_arrow_rounded, Strings.goToExercise),
    (_Action.swap, Symbols.swap_horiz_rounded, Strings.swap),
    if (exercise.isSkipped)
      (_Action.unskip, Symbols.replay_rounded, Strings.unskip)
    else if (!exercise.allSetsDone)
      (_Action.skip, Symbols.block_rounded, Strings.skip),
    (_Action.unit, Symbols.straighten_rounded, Strings.changeUnit),
    (_Action.remove, Symbols.delete_rounded, Strings.remove),
  ];

  Future<void> _run(BuildContext context, WidgetRef ref, _Action action) async {
    final controller = ref.read(workoutControllerProvider);
    switch (action) {
      case _Action.goTo:
        await controller.goTo(detail.workout.id, exercise.id);
        if (context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(Routes.workout);
          }
        }
      case _Action.swap:
        await swapExerciseFlow(context, ref, exercise);
      case _Action.skip:
        await controller.skip(detail, exercise);
      case _Action.unskip:
        await controller.unskip(exercise.id);
      case _Action.unit:
        await changeUnitFlow(context, ref, exercise);
      case _Action.remove:
        await removeExerciseFlow(context, ref, exercise);
    }
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final name = ref.read(exercisesByIdProvider)[exercise.exerciseId]?.name;
    final action = await showModalBottomSheet<_Action>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text(name ?? '', style: context.text.titleLarge),
            ),
            for (final (a, icon, label) in _actions)
              _actionTile(context, a, icon, label, pop: true),
          ],
        ),
      ),
    );
    if (action != null && context.mounted) await _run(context, ref, action);
  }

  Widget _actionTile(
    BuildContext context,
    _Action action,
    IconData icon,
    String label, {
    bool pop = false,
  }) {
    final color = action == _Action.remove ? context.colors.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      onTap: pop ? () => Navigator.of(context).pop(action) : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(unitLookupProvider);
    final name = ref.watch(exerciseProvider(exercise.exerciseId))?.name ?? '';
    final skipped = exercise.isSkipped;
    final String subtitle;
    if (skipped) {
      subtitle = Strings.skippedLabel;
    } else if (exercise.hasDoneSets || isCurrent) {
      final remaining = [
        for (final s in exercise.sets)
          if (!s.isDone) s.target,
      ];
      subtitle = [
        Strings.setsDone(exercise.doneCount, exercise.sets.length),
        if (remaining.isNotEmpty && exercise.hasDoneSets)
          PlanFormat.summary(remaining, units),
      ].join(' ${PlanFormat.dot} ');
    } else {
      subtitle = PlanFormat.summary([
        for (final s in exercise.sets) s.target,
      ], units);
    }
    final strike = skipped
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : const TextStyle();
    final onTint = isCurrent ? colors.onPrimaryContainer : null;
    final Widget status;
    if (skipped) {
      status = _StatusCircle(
        color: colors.surfaceContainerHigh,
        child: Icon(
          Symbols.block_rounded,
          size: 20,
          color: colors.onSurfaceVariant,
        ),
      );
    } else if (isCurrent) {
      status = _StatusCircle(
        color: colors.primary,
        child: Icon(
          Symbols.play_arrow_rounded,
          size: 20,
          fill: 1,
          color: colors.onPrimary,
        ),
      );
    } else if (exercise.isFinished) {
      status = _StatusCircle(
        color: context.appColors.success,
        child: const Icon(Symbols.check_rounded, size: 20, color: Colors.white),
      );
    } else {
      status = _StatusCircle(
        border: colors.outline,
        child: const SizedBox.shrink(),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isCurrent ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => unawaited(_openSheet(context, ref)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              0,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                status,
                const SizedBox(width: AppSpacing.md),
                Opacity(
                  opacity: skipped ? 0.5 : 1,
                  child: ExerciseThumb(
                    exerciseId: exercise.exerciseId,
                    size: 56,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium!
                            .merge(strike)
                            .copyWith(color: onTint),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium!
                            .merge(strike)
                            .copyWith(
                              color: onTint,
                              fontFeatures: AppTheme.tabular,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  PopupMenuButton<_Action>(
                    tooltip: Strings.more,
                    icon: Icon(Symbols.more_vert_rounded, color: onTint),
                    onSelected: (a) => unawaited(_run(context, ref, a)),
                    itemBuilder: (context) => [
                      for (final (a, icon, label) in _actions) ...[
                        if (a == _Action.remove) const PopupMenuDivider(),
                        PopupMenuItem(
                          value: a,
                          child: _actionTile(context, a, icon, label),
                        ),
                      ],
                    ],
                  ),
                ReorderableDragStartListener(
                  index: index,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Symbols.drag_indicator_rounded,
                      color: onTint ?? colors.onSurfaceVariant,
                      semanticLabel: Strings.reorder,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  const new({required this.child, this.color, this.border});

  final Widget child;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: border == null ? null : Border.all(color: border!, width: 2),
    ),
    child: Center(child: child),
  );
}
