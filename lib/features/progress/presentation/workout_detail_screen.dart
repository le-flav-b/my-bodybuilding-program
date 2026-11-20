import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/core/utils/date_text.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/domain/bests.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_widgets.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_widgets.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// A past workout: when, how long, its note and every set. Sets, notes
/// and the workout itself can be edited or deleted; records and charts
/// follow.
class WorkoutDetailScreen extends ConsumerWidget {
  const new({required this.workoutId, super.key});

  final String workoutId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: Strings.deleteWorkoutTitle,
      message: Strings.deleteWorkoutBody,
      confirmLabel: Strings.delete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(workoutControllerProvider).deleteWorkout(workoutId);
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.progress);
    }
    showAppSnackBar(context, Strings.workoutDeleted);
  }

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    Workout workout,
  ) async {
    final text = await showTextPrompt(
      context,
      title: Strings.workoutNote,
      label: Strings.note,
      initial: workout.notes,
      helper: Strings.workoutNoteHint,
    );
    if (text != null) {
      await ref
          .read(workoutControllerProvider)
          .setWorkoutNotes(workoutId, text);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutDetailProvider(workoutId));
    final detail = async.value;
    if (detail == null || detail.workout.status == WorkoutStatus.discarded) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const SizedBox.shrink()
            : const EmptyState(
                icon: Symbols.history_rounded,
                title: Strings.historyTab,
                body: Strings.workoutNotFound,
              ),
      );
    }
    final workout = detail.workout;
    final colors = context.colors;
    final records = {
      for (final e in Bests.events(
        ref.watch(loggedSetsProvider).value ?? const [],
      ))
        if (e.workoutId == workoutId) e.setId,
    };
    final end = workout.endedAt ?? workout.lastActivityAt;
    final started = workout.startedAt.toLocal();
    final exercises = [
      for (final e in detail.exercises)
        if (e.hasDoneSets) e,
    ];

    Widget meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.text.bodyMedium!.copyWith(
            fontFeatures: AppTheme.tabular,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(workout.sessionName),
        actions: [
          PopupMenuButton<String>(
            tooltip: Strings.more,
            icon: const Icon(Symbols.more_vert_rounded),
            onSelected: (_) => unawaited(_delete(context, ref)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Symbols.delete_rounded, color: colors.error),
                  title: Text(
                    Strings.deleteWorkout,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              meta(
                Symbols.event_rounded,
                '${DateFormat('EEE d MMM').format(started)} · '
                '${DateText.time(workout.startedAt)}',
              ),
              meta(
                Symbols.schedule_rounded,
                longDuration(WorkoutClock.elapsedSeconds(workout, end)),
              ),
              meta(
                Symbols.done_all_rounded,
                Strings.setCount(detail.doneSetCount),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => unawaited(_editNote(context, ref, workout)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Overline(
                            Strings.workoutNote,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            workout.notes.isEmpty
                                ? Strings.addNote
                                : workout.notes,
                            style: context.text.bodyLarge!.copyWith(
                              color: workout.notes.isEmpty
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: Strings.editNote,
                      onPressed: () =>
                          unawaited(_editNote(context, ref, workout)),
                      icon: const Icon(Symbols.edit_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final (i, e) in exercises.indexed) ...[
            if (i > 0) Divider(height: 1, color: colors.outlineVariant),
            _ExerciseSection(exercise: e, records: records),
          ],
        ],
      ),
    );
  }
}

class _ExerciseSection extends ConsumerWidget {
  const new({required this.exercise, required this.records});

  final WorkoutExercise exercise;
  final Set<String> records;

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final text = await showTextPrompt(
      context,
      title: Strings.exerciseNote,
      label: Strings.note,
      initial: exercise.notes,
      helper: Strings.exerciseNoteHint,
    );
    if (text != null) {
      await ref
          .read(workoutControllerProvider)
          .setExerciseNotes(exercise.id, text);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showConfirmDialog(
      context,
      title: Strings.removeLoggedExerciseTitle(name),
      message: Strings.removeLoggedExerciseBody,
      confirmLabel: Strings.remove,
      destructive: true,
    );
    if (confirmed) {
      await ref.read(workoutControllerProvider).remove(exercise.id);
    }
  }

  Future<void> _editSet(
    BuildContext context,
    WidgetRef ref,
    WorkoutSet set,
    Measure measure,
  ) async {
    final result = await showEditSetSheet(
      context,
      set: set,
      measure: measure,
      allowDelete: true,
    );
    final controller = ref.read(workoutControllerProvider);
    switch (result) {
      case EditSetSaved(
        :final reps,
        :final seconds,
        :final load,
        :final unitId,
      ):
        await controller.editSet(
          set.id,
          reps: reps,
          seconds: seconds,
          load: load,
          unitId: unitId,
        );
      case EditSetDeleted():
        await controller.deleteLoggedSet(set.id);
      case EditSetNotDone() || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final info = ref.watch(exerciseProvider(exercise.exerciseId));
    final name = info?.name ?? '';
    final units = ref.watch(unitLookupProvider);
    final measure = info?.measure ?? Measure.reps;
    final done = exercise.doneSets.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () =>
                    context.push(Routes.exerciseProgress(exercise.exerciseId)),
                child: ExerciseThumb(
                  exerciseId: exercise.exerciseId,
                  size: 40,
                  radius: AppRadius.sm,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: Strings.more,
                icon: const Icon(Symbols.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'note':
                      await _editNote(context, ref);
                    case 'progress':
                      await context.push(
                        Routes.exerciseProgress(exercise.exerciseId),
                      );
                    case 'remove':
                      await _remove(context, ref, name);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'note',
                    child: ListTile(
                      leading: Icon(Symbols.edit_note_rounded),
                      title: Text(Strings.exerciseNote),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'progress',
                    child: ListTile(
                      leading: Icon(Symbols.monitoring_rounded),
                      title: Text(Strings.seeProgress),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(
                        Symbols.delete_rounded,
                        color: colors.error,
                      ),
                      title: Text(
                        Strings.removeFromWorkout,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (exercise.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 2),
              child: Text(
                exercise.notes,
                style: context.text.bodyMedium!.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          for (final (i, set) in done.indexed)
            InkWell(
              onTap: () => unawaited(_editSet(context, ref, set, measure)),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(
                          '${i + 1}',
                          style: context.text.bodyLarge!.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: Text(
                        PlanFormat.set(
                          reps: set.reps,
                          seconds: set.seconds,
                          loadValue: set.load,
                          unitId: set.unitId,
                          units: units,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge!.copyWith(
                          fontSize: 17,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ),
                    if (records.contains(set.id)) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const TrophyChip(),
                    ],
                    const Spacer(),
                    IconButton(
                      tooltip: Strings.editSet,
                      onPressed: () =>
                          unawaited(_editSet(context, ref, set, measure)),
                      icon: Icon(
                        Symbols.edit_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
