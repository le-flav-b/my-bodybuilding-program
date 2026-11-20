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
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/app/widgets/value_dialogs.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/estimated_duration.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_widgets.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// "10 × 40" without the unit (last-time hints), "0:45", "12".
String shortSetText(int? reps, int? seconds, double? load, LoadUnit? unit) {
  final goal = PlanFormat.goal(SetTarget(reps: reps, seconds: seconds));
  if (load == null) return goal;
  final value = unit?.formatValue(load) ?? formatLoadValue(load, 2);
  return seconds != null && reps == null
      ? '$goal ${PlanFormat.dot} $value'
      : '$goal ${PlanFormat.times} $value';
}

/// The set done at the same place last time, if any.
LoggedSet? lastAt(List<LoggedSet> last, int index) =>
    index < last.length ? last[index] : null;

/// The measure of a workout exercise (reps when the exercise is gone).
Measure measureOf(WidgetRef ref, WorkoutExercise exercise) =>
    ref.watch(exerciseProvider(exercise.exerciseId))?.measure ?? Measure.reps;

/// The player's top bar: leave, session name with elapsed and time left,
/// pause and list view.
class PlayerHeader extends ConsumerWidget {
  const new({required this.detail, required this.onLeave, super.key});

  final WorkoutDetail detail;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final elapsed = PlanFormat.clock(
      WorkoutClock.elapsedSeconds(detail.workout, now),
    );
    final left = EstimatedDuration.minutes(estimatedSecondsLeft(detail));
    final controller = ref.read(workoutControllerProvider);
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: Strings.leaveWorkout,
            onPressed: onLeave,
            icon: const Icon(Symbols.close_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.workout.sessionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge!.copyWith(fontSize: 18),
                ),
                Text(
                  Strings.elapsedAndLeft(elapsed, left),
                  style: context.text.bodyMedium!.copyWith(
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: Strings.pause,
            onPressed: () => unawaited(controller.pause(detail.workout.id)),
            icon: const Icon(Symbols.pause_rounded),
          ),
          IconButton(
            tooltip: Strings.listView,
            onPressed: () => unawaited(context.push(Routes.workoutList)),
            icon: const Icon(Symbols.view_list_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// One 4-high segment per exercise: done green, current primary, skipped
/// outline, to do grey.
class SegmentBar extends StatelessWidget {
  const new({required this.detail, super.key});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = detail.currentExercise?.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 0),
      child: Row(
        children: [
          for (final (i, e) in detail.exercises.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: e.id == current && !e.isFinished
                      ? colors.primary
                      : e.isSkipped
                      ? colors.outlineVariant
                      : e.allSetsDone || (e.isFinished && e.hasDoneSets)
                      ? context.appColors.success
                      : e.id == current
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Image, "EXERCISE 1 / 6", name, muscles, form cues, note and the ⋮ menu
/// (swap, skip, change unit). [compact] is the time-based header.
class ExerciseBlock extends ConsumerStatefulWidget {
  const new({
    required this.detail,
    required this.exercise,
    this.compact = false,
    super.key,
  });

  final WorkoutDetail detail;
  final WorkoutExercise exercise;
  final bool compact;

  @override
  ConsumerState<ExerciseBlock> createState() => _ExerciseBlockState();
}

class _ExerciseBlockState extends ConsumerState<ExerciseBlock> {
  bool _showCues = false;

  Future<void> _editNote() async {
    final text = await showTextPrompt(
      context,
      title: Strings.exerciseNote,
      label: Strings.note,
      initial: widget.exercise.notes,
      helper: Strings.exerciseNoteHint,
    );
    if (text == null) return;
    await ref
        .read(workoutControllerProvider)
        .setExerciseNotes(widget.exercise.id, text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final exercise = widget.exercise;
    final info = ref.watch(exerciseProvider(exercise.exerciseId));
    final muscles = ref.watch(exerciseMuscleNamesProvider(exercise.exerciseId));
    final index = widget.detail.exercises.indexOf(exercise) + 1;
    final hasCues = (info?.description ?? '').trim().isNotEmpty;
    final menu = _ExerciseMenu(detail: widget.detail, exercise: exercise);
    final noteButton = TextButton.icon(
      onPressed: _editNote,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: const Icon(Symbols.edit_note_rounded),
      label: const Text(Strings.note),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExerciseThumb(
              exerciseId: exercise.exerciseId,
              size: widget.compact ? 72 : 96,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Overline(
                    Strings.exerciseOf(index, widget.detail.exercises.length),
                    color: colors.primary,
                  ),
                  Text(
                    info?.name ?? '',
                    style: context.text.headlineSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (muscles.isNotEmpty)
                    Text(muscles, style: context.text.bodyMedium),
                  if (!widget.compact)
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            children: [
                              if (hasCues)
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _showCues = !_showCues),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  icon: Icon(
                                    _showCues
                                        ? Symbols.expand_less_rounded
                                        : Symbols.expand_more_rounded,
                                  ),
                                  label: const Text(Strings.formCues),
                                ),
                              noteButton,
                            ],
                          ),
                        ),
                        menu,
                      ],
                    ),
                ],
              ),
            ),
            if (widget.compact) menu,
          ],
        ),
        if (_showCues && hasCues)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(info!.description, style: context.text.bodyMedium),
          ),
        if (exercise.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: InkWell(
              onTap: _editNote,
              child: Row(
                children: [
                  Icon(
                    Symbols.edit_note_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      exercise.notes,
                      style: context.text.bodyMedium!.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.compact && exercise.notes.isEmpty)
          Align(alignment: Alignment.centerLeft, child: noteButton),
      ],
    );
  }
}

class _ExerciseMenu extends ConsumerWidget {
  const new({required this.detail, required this.exercise});

  final WorkoutDetail detail;
  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTime = measureOf(ref, exercise) == Measure.time;
    return PopupMenuButton<String>(
      tooltip: Strings.more,
      icon: const Icon(Symbols.more_vert_rounded),
      onSelected: (value) async {
        switch (value) {
          case 'swap':
            await swapExerciseFlow(context, ref, exercise);
          case 'skip':
            await ref.read(workoutControllerProvider).skip(detail, exercise);
          case 'unit':
            await changeUnitFlow(context, ref, exercise);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'swap',
          child: ListTile(
            leading: Icon(Symbols.swap_horiz_rounded),
            title: Text(Strings.swap),
          ),
        ),
        const PopupMenuItem(
          value: 'skip',
          child: ListTile(
            leading: Icon(Symbols.block_rounded),
            title: Text(Strings.skip),
          ),
        ),
        if (!isTime || exercise.sets.any((s) => s.target.hasLoad))
          const PopupMenuItem(
            value: 'unit',
            child: ListTile(
              leading: Icon(Symbols.straighten_rounded),
              title: Text(Strings.changeUnit),
            ),
          ),
      ],
    );
  }
}

/// The personal setup note of an exercise ("seat 4, pin 7"), if any.
class SetupNoteStrip extends ConsumerWidget {
  const new({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(exerciseNotesProvider).value?[exerciseId] ?? '';
    if (note.trim().isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.push_pin_rounded,
            size: 20,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              note,
              style: context.text.bodyLarge!.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "NEXT EXERCISE · Incline dumbbell press · 3 × 12 · 16 kg" at the bottom.
/// Tapping it goes to that exercise.
class NextExerciseFooter extends ConsumerWidget {
  const new({required this.detail, super.key});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final current = detail.currentExercise;
    final next = current == null
        ? detail.firstUnfinished
        : detail.nextUnfinishedAfter(current.id);
    final units = ref.watch(unitLookupProvider);
    final name = next == null
        ? null
        : ref.watch(exerciseProvider(next.exerciseId))?.name;
    final plan = next == null
        ? ''
        : PlanFormat.summary([
            for (final s in next.sets)
              if (!s.isDone) s.target,
          ], units);
    return Material(
      color: colors.surfaceContainerLow,
      child: InkWell(
        onTap: next == null
            ? null
            : () => unawaited(
                ref
                    .read(workoutControllerProvider)
                    .goTo(detail.workout.id, next.id),
              ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Overline(
                          next == null
                              ? Strings.lastExercise
                              : Strings.nextExercise,
                          color: colors.onSurfaceVariant,
                        ),
                        if (next != null)
                          Text(
                            '${name ?? ''} ${PlanFormat.dot} $plan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium!.copyWith(
                              fontFeatures: AppTheme.tabular,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    ExerciseThumb(
                      exerciseId: next.exerciseId,
                      size: 40,
                      radius: AppRadius.sm,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round number badge (set rows).
class SetNumberBadge extends StatelessWidget {
  const new({required this.number, this.active = false, super.key});

  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? colors.primary : colors.surfaceContainerHigh,
      ),
      child: Text(
        '$number',
        style: context.text.labelMedium!.copyWith(
          height: 1,
          color: active ? colors.onPrimary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The ✓ in a green circle of a done set.
class DoneMark extends StatelessWidget {
  const new({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: context.appColors.success,
    ),
    child: Icon(
      Symbols.check_rounded,
      size: size * 0.65,
      color: Colors.white,
      weight: 600,
    ),
  );
}

/// "10 × 40 kg" with the unit smaller and grey.
class SetValueText extends StatelessWidget {
  const new({
    required this.reps,
    required this.seconds,
    required this.load,
    required this.unit,
    this.isMax = false,
    this.dim = false,
    super.key,
  });

  final int? reps;
  final int? seconds;
  final double? load;
  final LoadUnit? unit;
  final bool isMax;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = context.text.titleMedium!.copyWith(
      fontSize: 18,
      fontWeight: dim ? FontWeight.w400 : FontWeight.w600,
      color: dim ? colors.onSurfaceVariant : colors.onSurface,
      fontFeatures: AppTheme.tabular,
    );
    final goal = PlanFormat.goal(
      SetTarget(reps: reps, seconds: seconds, isMax: isMax),
    );
    final l = load;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: goal),
          if (l != null) ...[
            TextSpan(
              text: seconds != null && reps == null
                  ? ' ${PlanFormat.dot} '
                  : ' ${PlanFormat.times} ',
            ),
            TextSpan(text: unit?.formatValue(l) ?? formatLoadValue(l, 2)),
            TextSpan(
              text: ' ${unit?.name ?? ''}',
              style: base.copyWith(
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A done or upcoming set row: tap a done set to edit it, swipe left to
/// remove a set.
class SetRow extends ConsumerWidget {
  const new({
    required this.exercise,
    required this.set,
    required this.number,
    required this.last,
    required this.isRecord,
    super.key,
  });

  final WorkoutExercise exercise;
  final WorkoutSet set;
  final int number;
  final LoggedSet? last;
  final bool isRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(loadUnitsByIdProvider);
    final done = set.isDone;
    final t = set.target;
    final l = last;
    final row = InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: done
          ? () => unawaited(editLoggedSetFlow(context, ref, exercise, set))
          : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              if (done) const DoneMark() else SetNumberBadge(number: number),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: done
                    ? SetValueText(
                        reps: set.reps,
                        seconds: set.seconds,
                        load: set.load,
                        unit: units[set.unitId],
                      )
                    : SetValueText(
                        reps: t.reps,
                        seconds: t.seconds,
                        isMax: t.isMax,
                        load: t.load,
                        unit: units[t.unitId],
                        dim: true,
                      ),
              ),
              if (isRecord) ...[
                const SizedBox(width: AppSpacing.sm),
                const TrophyChip(),
              ],
              const Spacer(),
              if (l != null)
                Text(
                  Strings.lastShort(
                    shortSetText(l.reps, l.seconds, l.load, units[l.unitId]),
                  ),
                  style: context.text.bodySmall!.copyWith(
                    fontFeatures: AppTheme.tabular,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(Symbols.delete_rounded, color: colors.onErrorContainer),
      ),
      onDismissed: (_) => unawaited(removeSetFlow(context, ref, set, number)),
      child: row,
    );
  }
}

/// What the current set card hands back when the set is logged or started.
typedef SetValues = ({int? reps, int? seconds, double? load, String? unitId});

/// The current set: header with target and last time, the reps (or time)
/// and load steppers pre-filled with the target, and Done (or Log /
/// Start for a timed set).
class CurrentSetCard extends ConsumerStatefulWidget {
  const new({
    required this.exercise,
    required this.set,
    required this.number,
    required this.measure,
    required this.last,
    required this.onDone,
    this.onStart,
    super.key,
  });

  final WorkoutExercise exercise;
  final WorkoutSet set;
  final int number;
  final Measure measure;
  final LoggedSet? last;
  final ValueChanged<SetValues> onDone;

  /// Time-based only: runs the 3-2-1 lead-in then the countdown.
  final ValueChanged<SetValues>? onStart;

  @override
  ConsumerState<CurrentSetCard> createState() => _CurrentSetCardState();
}

class _CurrentSetCardState extends ConsumerState<CurrentSetCard> {
  late SetTarget _target = widget.set.target;
  late int _reps = _initialReps();
  late int _seconds = _initialSeconds();
  late double? _load = _target.load;
  late String _unitId = _target.unitId ?? FixedIds.kgUnit;

  int _initialReps() =>
      _target.isMax ? widget.last?.reps ?? 10 : _target.reps ?? 10;

  int _initialSeconds() => _target.isMax
      ? widget.last?.seconds ?? 30
      : _target.seconds ?? widget.last?.seconds ?? 30;

  @override
  void didUpdateWidget(CurrentSetCard old) {
    super.didUpdateWidget(old);
    // The unit or target changed elsewhere (unit menu, list view).
    if (old.set.target != widget.set.target) {
      _target = widget.set.target;
      if (old.set.target.unitId != _target.unitId) {
        _load = _target.load;
        _unitId = _target.unitId ?? FixedIds.kgUnit;
      }
    }
  }

  SetValues get _values => (
    reps: widget.measure == Measure.reps ? _reps : null,
    seconds: widget.measure == Measure.time ? _seconds : null,
    load: _load,
    unitId: _load == null ? null : _unitId,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unitsById = ref.watch(loadUnitsByIdProvider);
    final unit = unitsById[_unitId] ?? unitsById[FixedIds.kgUnit];
    final t = _target;
    final l = widget.last;
    final isTime = widget.measure == Measure.time;
    final targetText = PlanFormat.set(
      reps: t.reps,
      seconds: t.seconds,
      isMax: t.isMax,
      loadValue: t.load,
      unitId: t.unitId,
      units: (id) => unitsById[id],
    );
    final goalStepper = isTime
        ? ValueStepper(
            label: Strings.time,
            value: PlanFormat.clock(_seconds),
            changed: !t.isMax && t.seconds != null && _seconds != t.seconds,
            onMinus: _seconds > 5 ? () => setState(() => _seconds -= 5) : null,
            onPlus: () => setState(() => _seconds += 5),
            onLongPress: () async {
              final picked = await showGoalDialog(
                context,
                title: Strings.time,
                initial: _seconds,
                step: 5,
                min: 1,
                asClock: true,
              );
              if (picked?.value case final v?) setState(() => _seconds = v);
            },
          )
        : ValueStepper(
            label: Strings.reps,
            value: '$_reps',
            changed: !t.isMax && t.reps != null && _reps != t.reps,
            onMinus: _reps > 0 ? () => setState(() => _reps--) : null,
            onPlus: () => setState(() => _reps++),
            onLongPress: () async {
              final picked = await showGoalDialog(
                context,
                title: Strings.reps,
                initial: _reps,
                step: 1,
              );
              if (picked?.value case final v?) setState(() => _reps = v);
            },
          );
    final loadStepper = LoadStepper(
      load: _load,
      unit: unit,
      changed: _load != t.load,
      onChanged: (v) => setState(() => _load = v),
      trailing: UnitChip(
        unit: unit,
        units: ref.watch(activeLoadUnitsProvider),
        onSelected: (id) {
          if (id == _unitId) return;
          setState(() => _unitId = id);
          unawaited(
            ref.read(workoutControllerProvider).changeUnit(widget.exercise, id),
          );
        },
        onManage: () => unawaited(context.push(Routes.loadUnits)),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.md),
            child: Row(
              children: [
                SetNumberBadge(number: widget.number, active: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    Strings.target(targetText),
                    style: context.text.titleMedium!.copyWith(
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ),
                if (l != null) ...[
                  Icon(
                    Symbols.history_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Strings.lastLong(
                      PlanFormat.set(
                        reps: l.reps,
                        seconds: l.seconds,
                        loadValue: l.load,
                        unitId: l.unitId,
                        units: (id) => unitsById[id],
                      ),
                    ),
                    style: context.text.bodySmall!.copyWith(
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: goalStepper),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: loadStepper),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.onStart case final onStart?)
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(96, AppSizes.bigButtonHeight - 8),
                  ),
                  onPressed: () => widget.onDone(_values),
                  icon: const Icon(Symbols.edit_rounded),
                  label: const Text(Strings.log),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        double.infinity,
                        AppSizes.bigButtonHeight - 8,
                      ),
                      textStyle: context.text.labelLarge!.copyWith(
                        fontSize: 18,
                      ),
                    ),
                    onPressed: () => onStart(_values),
                    icon: const Icon(Symbols.timer_rounded, fill: 1),
                    label: const Text(Strings.start),
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  AppSizes.bigButtonHeight,
                ),
                textStyle: context.text.labelLarge!.copyWith(
                  fontSize: 18,
                  height: 24 / 18,
                ),
                iconSize: 28,
              ),
              onPressed: () => widget.onDone(_values),
              icon: const Icon(Symbols.check_rounded),
              label: const Text(Strings.done),
            ),
        ],
      ),
    );
  }
}

/// "+ Add set" under a set list.
class AddSetButton extends ConsumerWidget {
  const new({required this.exercise, super.key});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () =>
          unawaited(ref.read(workoutControllerProvider).addSet(exercise.id)),
      icon: const Icon(Symbols.add_rounded),
      label: const Text(Strings.addSet),
    ),
  );
}
