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
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/value_dialogs.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/date_text.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/plan_diff.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_widgets.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';

/// Finishes the workout: to the summary, or back to Today when nothing was
/// logged (the workout is discarded).
Future<void> finishWorkoutFlow(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
) async {
  final kept = await ref.read(workoutControllerProvider).finish(workoutId);
  if (!context.mounted) return;
  if (kept) {
    context.go(Routes.workoutSummary(workoutId));
  } else {
    context.go(Routes.today);
    showAppSnackBar(context, Strings.nothingLoggedDiscarded);
  }
}

Future<void> discardWorkoutFlow(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
) async {
  await ref.read(workoutControllerProvider).discard(workoutId);
  if (context.mounted) context.go(Routes.today);
}

/// A stacked dialog button, full width.
class _StackedAction extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: SizedBox(width: double.infinity, child: child),
  );
}

/// "Leave workout?": Finish now / Keep going / Discard workout.
Future<void> showLeaveDialog(
  BuildContext context,
  WidgetRef ref,
  WorkoutDetail detail,
) {
  final now = ref.read(clockProvider)();
  Widget tile(String value, String label) => Expanded(
    child: Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: context.text.titleMedium!.copyWith(
                fontFeatures: AppTheme.tabular,
              ),
            ),
            Text(label, style: context.text.bodySmall),
          ],
        ),
      ),
    ),
  );
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(Strings.leaveTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              tile(
                PlanFormat.clock(
                  WorkoutClock.elapsedSeconds(detail.workout, now),
                ),
                Strings.elapsed,
              ),
              tile('${detail.doneSetCount}', Strings.setsLogged),
              tile(
                '${detail.doneExerciseCount} / ${detail.exercises.length}',
                Strings.exercisesLabel,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StackedAction(
            child: FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await finishWorkoutFlow(context, ref, detail.workout.id);
              },
              icon: const Icon(Symbols.flag_rounded),
              label: const Text(Strings.finishNow),
            ),
          ),
          _StackedAction(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(Strings.keepGoing),
            ),
          ),
          _StackedAction(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.colors.error,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await discardWorkoutFlow(context, ref, detail.workout.id);
              },
              child: const Text(Strings.discardWorkout),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Resume workout?" at launch: Resume / Finish with what's logged / Discard.
Future<void> showResumeDialog(
  BuildContext context,
  WidgetRef ref,
  WorkoutDetail detail,
) {
  final now = ref.read(clockProvider)();
  final started =
      '${DateText.relativeDay(detail.workout.startedAt, now)} at '
      '${DateText.time(detail.workout.startedAt)}';
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Symbols.history_rounded),
      title: const Text(Strings.resumeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Strings.resumeBody(
              detail.workout.sessionName,
              started,
              detail.doneSetCount,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StackedAction(
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(context.push(Routes.workout));
              },
              icon: const Icon(Symbols.play_arrow_rounded, fill: 1),
              label: const Text(Strings.resume),
            ),
          ),
          _StackedAction(
            child: OutlinedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await finishWorkoutFlow(context, ref, detail.workout.id);
              },
              child: const Text(Strings.finishWithLogged),
            ),
          ),
          _StackedAction(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.colors.error,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await discardWorkoutFlow(context, ref, detail.workout.id);
              },
              child: const Text(Strings.discard),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Update the program?" with the list of changes. True = Update.
Future<bool> showUpdateProgramDialog(
  BuildContext context,
  WidgetRef ref, {
  required String sessionName,
  required List<PlanChange> changes,
}) async {
  final exercises = ref.read(exercisesByIdProvider);
  final units = ref.read(unitLookupProvider);
  String name(String id) => exercises[id]?.name ?? '';
  (IconData, String) describe(PlanChange change) => switch (change) {
    PlanSwapped(:final fromExerciseId, :final toExerciseId) => (
      Symbols.swap_horiz_rounded,
      Strings.changeSwapped(name(fromExerciseId), name(toExerciseId)),
    ),
    PlanAdded(:final exerciseId) => (
      Symbols.add_rounded,
      Strings.changeAdded(name(exerciseId)),
    ),
    PlanRemoved(:final exerciseId) => (
      Symbols.delete_rounded,
      Strings.changeRemoved(name(exerciseId)),
    ),
    PlanSetsChanged(:final exerciseId, :final before, :final after) => (
      Symbols.edit_rounded,
      Strings.changeSets(
        name(exerciseId),
        PlanFormat.summary(before, units),
        PlanFormat.summary(after, units),
      ),
    ),
    PlanReordered() => (Symbols.swap_vert_rounded, Strings.changeReordered),
    PlanSkipped(:final exerciseId) => (
      Symbols.block_rounded,
      Strings.changeSkipped(name(exerciseId)),
    ),
  };
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text(Strings.updateProgramTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.updateProgramBody(sessionName)),
            const SizedBox(height: AppSpacing.sm),
            for (final (icon, text) in changes.map(describe))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: context.colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        text,
                        style: context.text.bodyMedium!.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(Strings.keepProgram),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(Strings.update),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// What the user chose in [showEditSetSheet].
sealed class EditSetResult {
  const new();
}

final class EditSetSaved extends EditSetResult {
  const new({this.reps, this.seconds, this.load, this.unitId});

  final int? reps;
  final int? seconds;
  final double? load;
  final String? unitId;
}

final class EditSetNotDone extends EditSetResult {
  const new();
}

final class EditSetDeleted extends EditSetResult {
  const new();
}

/// Edits a logged set: reps or time and load, mark as not done (during a
/// workout) or delete (from the history).
Future<EditSetResult?> showEditSetSheet(
  BuildContext context, {
  required WorkoutSet set,
  required Measure measure,
  bool allowNotDone = false,
  bool allowDelete = false,
}) => showModalBottomSheet<EditSetResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _EditSetSheet(
    set: set,
    measure: measure,
    allowNotDone: allowNotDone,
    allowDelete: allowDelete,
  ),
);

class _EditSetSheet extends ConsumerStatefulWidget {
  const new({
    required this.set,
    required this.measure,
    required this.allowNotDone,
    required this.allowDelete,
  });

  final WorkoutSet set;
  final Measure measure;
  final bool allowNotDone;
  final bool allowDelete;

  @override
  ConsumerState<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends ConsumerState<_EditSetSheet> {
  late int _reps = widget.set.reps ?? 0;
  late int _seconds = widget.set.seconds ?? 0;
  late double? _load = widget.set.load;
  late String _unitId = widget.set.unitId ?? FixedIds.kgUnit;

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(loadUnitsByIdProvider);
    final unit = units[_unitId] ?? units[FixedIds.kgUnit];
    final isReps = widget.measure == Measure.reps;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Strings.editSet, style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: isReps
                        ? ValueStepper(
                            label: Strings.reps,
                            value: '$_reps',
                            onMinus: _reps > 0
                                ? () => setState(() => _reps--)
                                : null,
                            onPlus: () => setState(() => _reps++),
                          )
                        : ValueStepper(
                            label: Strings.time,
                            value: PlanFormat.clock(_seconds),
                            onMinus: _seconds > 0
                                ? () => setState(
                                    () => _seconds = (_seconds - 5).clamp(
                                      0,
                                      36000,
                                    ),
                                  )
                                : null,
                            onPlus: () => setState(() => _seconds += 5),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: LoadStepper(
                      load: _load,
                      unit: unit,
                      onChanged: (v) => setState(() => _load = v),
                      trailing: UnitChip(
                        unit: unit,
                        units: ref.watch(activeLoadUnitsProvider),
                        onSelected: (id) => setState(() => _unitId = id),
                        onManage: () => context.push(Routes.loadUnits),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (widget.allowNotDone)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const EditSetNotDone()),
                  child: const Text(Strings.markNotDone),
                ),
              if (widget.allowDelete)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.error,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(const EditSetDeleted()),
                  child: const Text(Strings.deleteSet),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  EditSetSaved(
                    reps: isReps ? _reps : null,
                    seconds: isReps ? null : _seconds,
                    load: _load,
                    unitId: _load == null ? null : _unitId,
                  ),
                ),
                child: const Text(Strings.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The load stepper: − / + by the unit's step, "Body" for no load, a
/// negative value for assisted. Long-press to type.
class LoadStepper extends StatelessWidget {
  const new({
    required this.load,
    required this.unit,
    required this.onChanged,
    this.changed = false,
    this.trailing,
    super.key,
  });

  final double? load;
  final LoadUnit? unit;
  final ValueChanged<double?> onChanged;
  final bool changed;
  final Widget? trailing;

  void _step(int direction) {
    final u = unit;
    if (u == null) return;
    final next = u.stepBy(load ?? 0, direction);
    onChanged(next == 0 ? null : next);
  }

  @override
  Widget build(BuildContext context) {
    final u = unit;
    return ValueStepper(
      label: Strings.load,
      value: load == null || u == null
          ? Strings.bodyweight
          : u.formatValue(load!),
      dim: load == null,
      changed: changed,
      trailing: trailing,
      onMinus: () => _step(-1),
      onPlus: () => _step(1),
      onLongPress: u == null
          ? null
          : () async {
              final result = await showLoadDialog(
                context,
                unit: u,
                initial: load,
              );
              if (result != null) onChanged(result.load);
            },
    );
  }
}
