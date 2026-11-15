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
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/app/widgets/value_dialogs.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/exercise_picker_sheet.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_controller.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_providers.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// Edits a session: its name, its exercises in order, and for each one its
/// planned sets and rest time. Every change is saved at once.
class SessionEditorScreen extends ConsumerStatefulWidget {
  const new({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionEditorScreen> createState() =>
      _SessionEditorScreenState();
}

class _SessionEditorScreenState extends ConsumerState<SessionEditorScreen> {
  final _name = TextEditingController();
  Timer? _renameTimer;
  bool _nameLoaded = false;

  /// Positions of the expanded exercise cards.
  Set<int> _expanded = {};

  ProgramController get _controller => ref.read(programControllerProvider);

  @override
  void dispose() {
    if (_renameTimer?.isActive ?? false) {
      _renameTimer!.cancel();
      unawaited(_controller.renameSession(widget.sessionId, _name.text));
    }
    _name.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _renameTimer?.cancel();
    _renameTimer = Timer(
      const Duration(milliseconds: 400),
      () => _controller.renameSession(widget.sessionId, value),
    );
  }

  List<PlannedExercise> get _plan =>
      ref.read(sessionPlanProvider(widget.sessionId))?.toPlan() ?? const [];

  Future<void> _save(List<PlannedExercise> plan) =>
      _controller.savePlan(widget.sessionId, plan);

  /// Applies [change] to the exercise at [index] and saves.
  Future<void> _update(
    int index,
    PlannedExercise Function(PlannedExercise) change,
  ) {
    final plan = [..._plan];
    plan[index] = change(plan[index]);
    return _save(plan);
  }

  Future<void> _addExercise() async {
    final picked = await showExercisePicker(context);
    if (picked == null) return;
    final plan = [..._plan, await _controller.defaultPlanFor(picked)];
    setState(() => _expanded = {..._expanded, plan.length - 1});
    await _save(plan);
  }

  Future<void> _removeExercise(int index) async {
    final plan = [..._plan]..removeAt(index);
    setState(
      () => _expanded = {
        for (final i in _expanded)
          if (i < index) i else if (i > index) i - 1,
      },
    );
    await _save(plan);
  }

  void _toggle(int index) => setState(() {
    final next = {..._expanded};
    if (!next.remove(index)) next.add(index);
    _expanded = next;
  });

  Future<void> _reorder(int from, int to) async {
    final plan = [..._plan];
    plan.insert(to, plan.removeAt(from));
    // Keep each card's expanded state with its exercise.
    final flags = [
      for (var i = 0; i < _plan.length; i++) _expanded.contains(i),
    ];
    flags.insert(to, flags.removeAt(from));
    setState(
      () => _expanded = {
        for (final (i, open) in flags.indexed)
          if (open) i,
      },
    );
    await _save(plan);
  }

  Future<void> _deleteSession(String name) async {
    final confirmed = await showConfirmDialog(
      context,
      title: Strings.deleteSessionTitle(name),
      message: Strings.deleteSessionBody,
      confirmLabel: Strings.delete,
      destructive: true,
    );
    if (!confirmed) return;
    _renameTimer?.cancel();
    await _controller.deleteSession(widget.sessionId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(sessionPlanProvider(widget.sessionId));
    if (plan == null) {
      return Scaffold(appBar: AppBar(title: const Text(Strings.editSession)));
    }
    if (!_nameLoaded) {
      _name.text = plan.session.name;
      _nameLoaded = true;
    }
    final exercises = plan.toPlan();

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.editSession),
        actions: [
          PopupMenuButton<void>(
            tooltip: Strings.more,
            icon: const Icon(Symbols.more_vert_rounded),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _deleteSession(plan.session.name),
                child: Text(
                  Strings.deleteSession,
                  style: TextStyle(color: context.colors.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _onNameChanged,
                decoration: const InputDecoration(
                  labelText: Strings.sessionNameLabel,
                ),
              ),
            ),
          ),
          if (exercises.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: EmptyState(
                  icon: Symbols.exercise_rounded,
                  title: Strings.sessionEmptyTitle,
                  body: Strings.sessionEmptyBody,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverReorderableList(
                itemCount: exercises.length,
                onReorderItem: _reorder,
                itemBuilder: (context, index) => Padding(
                  key: ValueKey(plan.exercises[index].id),
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ExerciseCard(
                    index: index,
                    exercise: exercises[index],
                    expanded: _expanded.contains(index),
                    onToggle: () => _toggle(index),
                    onChanged: (change) => _update(index, change),
                    onRemove: () => _removeExercise(index),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            sliver: SliverToBoxAdapter(
              child: FilledButton.tonalIcon(
                onPressed: _addExercise,
                icon: const Icon(Symbols.add_rounded),
                label: const Text(Strings.addExercise),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One exercise of the session: collapsed to a summary line, or expanded in
/// place to its set table.
class _ExerciseCard extends ConsumerWidget {
  const new({
    required this.index,
    required this.exercise,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final PlannedExercise exercise;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<PlannedExercise Function(PlannedExercise)> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final entry = ref.watch(exerciseProvider(exercise.exerciseId));
    final units = ref.watch(unitLookupProvider);
    final measure = entry?.measure ?? Measure.reps;
    final summary = [
      PlanFormat.summary(exercise.sets, units),
      Strings.rest(PlanFormat.clock(exercise.restSeconds)),
    ].join(' · ');
    final subtitle = expanded
        ? [
            if (measure == Measure.reps) Strings.reps else Strings.time,
            ref.watch(exerciseMuscleNamesProvider(exercise.exerciseId)),
          ].where((s) => s.isNotEmpty).join(' · ')
        : summary;

    return Container(
      padding: expanded
          ? const EdgeInsets.fromLTRB(4, 8, 12, 12)
          : const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        color: expanded ? colors.surface : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: expanded ? colors.outlineVariant : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 40,
                  height: 48,
                  child: Icon(
                    Symbols.drag_indicator_rounded,
                    color: colors.onSurfaceVariant,
                    semanticLabel: Strings.reorder,
                  ),
                ),
              ),
              ExerciseThumb(exerciseId: exercise.exerciseId, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: InkWell(
                  onTap: onToggle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium!.copyWith(
                          height: 22 / 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium!.copyWith(
                          fontSize: 13,
                          height: 18 / 13,
                          color: colors.onSurfaceVariant,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: expanded ? Strings.collapse : Strings.expand,
                onPressed: onToggle,
                icon: Icon(
                  expanded
                      ? Symbols.keyboard_arrow_up_rounded
                      : Symbols.keyboard_arrow_down_rounded,
                ),
              ),
            ],
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _SetTable(
                exercise: exercise,
                measure: measure,
                onChanged: onChanged,
                onRemove: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

class _SetTable extends ConsumerWidget {
  const new({
    required this.exercise,
    required this.measure,
    required this.onChanged,
    required this.onRemove,
  });

  final PlannedExercise exercise;
  final Measure measure;
  final ValueChanged<PlannedExercise Function(PlannedExercise)> onChanged;
  final VoidCallback onRemove;

  static const double _numberWidth = 28;
  static const double _unitWidth = 64;
  static const double _deleteWidth = 36;

  void _setAt(int index, SetTarget target) => onChanged(
    (e) => e.copyWith(
      sets: [
        for (final (i, s) in e.sets.indexed)
          if (i == index) target else s,
      ],
    ),
  );

  Future<void> _editGoal(BuildContext context, int index) async {
    final set = exercise.sets[index];
    final isReps = measure == Measure.reps;
    final result = await showGoalDialog(
      context,
      title: isReps ? Strings.targetReps : Strings.targetTime,
      initial: isReps
          ? set.reps ?? SetTarget.defaultReps.reps!
          : set.seconds ?? SetTarget.defaultTime.seconds!,
      step: isReps ? 1 : 5,
      min: isReps ? 1 : 5,
      max: isReps ? 999 : 3600,
      asClock: !isReps,
      allowMax: true,
      initialIsMax: set.isMax,
      presets: isReps ? const [] : const [30, 45, 60, 90, 120],
    );
    if (result == null) return;
    _setAt(
      index,
      SetTarget(
        reps: isReps ? result.value ?? set.reps : null,
        seconds: isReps ? null : result.value ?? set.seconds,
        isMax: result.isMax,
        load: set.load,
        unitId: set.unitId,
      ),
    );
  }

  Future<void> _editLoad(BuildContext context, int index, LoadUnit unit) async {
    final set = exercise.sets[index];
    final result = await showLoadDialog(context, unit: unit, initial: set.load);
    if (result == null) return;
    _setAt(
      index,
      set.copyWith(
        load: result.load,
        unitId: result.load == null ? null : unit.id,
      ),
    );
  }

  /// An exercise is done in one unit: changing it applies to every loaded
  /// set. Loads are never converted.
  void _setUnit(String unitId) => onChanged(
    (e) => e.copyWith(
      sets: [
        for (final s in e.sets)
          if (s.load == null) s else s.copyWith(unitId: unitId),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final unitsById = ref.watch(loadUnitsByIdProvider);
    final kg = unitsById[FixedIds.kgUnit];
    // The unit of the exercise: the one of its first loaded set, else kg.
    final exerciseUnitId = exercise.sets
        .where((s) => s.load != null)
        .map((s) => s.unitId)
        .firstOrNull;
    final hasBodyweightSet = exercise.sets.any((s) => s.load == null);
    final header = context.text.labelSmall!.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: _numberWidth,
                child: Text(
                  Strings.setNumber,
                  textAlign: TextAlign.center,
                  style: header,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (measure == Measure.reps ? Strings.reps : Strings.time)
                      .toUpperCase(),
                  style: header,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(Strings.load.toUpperCase(), style: header)),
              const SizedBox(width: 8),
              SizedBox(
                width: _unitWidth,
                child: Text(Strings.unit.toUpperCase(), style: header),
              ),
              const SizedBox(width: 8 + _deleteWidth),
            ],
          ),
        ),
        for (final (i, set) in exercise.sets.indexed)
          () {
            final unit =
                unitsById[set.unitId ?? exerciseUnitId ?? FixedIds.kgUnit] ??
                kg;
            final load = set.load;
            return SizedBox(
              height: 48,
              child: Row(
                children: [
                  SizedBox(
                    width: _numberWidth,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: context.text.labelLarge!.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ValueBox(
                      text: PlanFormat.goal(set),
                      emphasis: set.isMax,
                      semanticLabel: measure == Measure.reps
                          ? Strings.targetReps
                          : Strings.targetTime,
                      onTap: () => _editGoal(context, i),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ValueBox(
                      text: load == null
                          ? Strings.bodyweight
                          : '${load > 0 && hasBodyweightSet ? '+' : ''}'
                                '${formatLoadValue(load, unit?.decimals ?? 2)}',
                      dim: load == null,
                      semanticLabel: Strings.load,
                      onTap: unit == null
                          ? null
                          : () => _editLoad(context, i, unit),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: _unitWidth,
                    child: _UnitSelector(
                      unit: unit,
                      enabled: load != null,
                      onSelected: _setUnit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: _deleteWidth,
                    child: IconButton(
                      tooltip: Strings.removeSet,
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(_deleteWidth, 48),
                      ),
                      onPressed: exercise.sets.length <= 1
                          ? null
                          : () => onChanged(
                              (e) => e.copyWith(sets: [...e.sets]..removeAt(i)),
                            ),
                      icon: const Icon(Symbols.close_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            );
          }(),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => onChanged(
                (e) => e.copyWith(
                  sets: [
                    ...e.sets,
                    // "Add set" copies the previous one.
                    if (e.sets.isNotEmpty)
                      e.sets.last
                    else if (measure == Measure.reps)
                      SetTarget.defaultReps
                    else
                      SetTarget.defaultTime,
                  ],
                ),
              ),
              icon: const Icon(Symbols.add_rounded),
              label: const Text(Strings.addSet),
            ),
            const Spacer(),
            ActionChip(
              avatar: Icon(
                Symbols.timer_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              label: Text(
                Strings.restChip(PlanFormat.clock(exercise.restSeconds)),
              ),
              labelStyle: context.text.labelLarge!.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: colors.surfaceContainerHigh,
              side: BorderSide.none,
              onPressed: () async {
                final result = await showGoalDialog(
                  context,
                  title: Strings.restBetweenSets,
                  initial: exercise.restSeconds,
                  step: 15,
                  max: 600,
                  asClock: true,
                  presets: const [30, 60, 90, 120, 180],
                );
                final seconds = result?.value;
                if (seconds != null) {
                  onChanged((e) => e.copyWith(restSeconds: seconds));
                }
              },
            ),
            const Spacer(),
            IconButton(
              tooltip: Strings.removeExercise,
              onPressed: onRemove,
              icon: const Icon(Symbols.delete_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

/// A 40-high value box of the set table ("12", "max", "Body", "+5").
class _ValueBox extends StatelessWidget {
  const new({
    required this.text,
    required this.onTap,
    required this.semanticLabel,
    this.emphasis = false,
    this.dim = false,
  });

  final String text;
  final VoidCallback? onTap;
  final String semanticLabel;

  /// "max": shown in primary.
  final bool emphasis;

  /// "Body": grey and lighter.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '$semanticLabel: $text',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: dim ? 14 : 16,
                  fontWeight: dim ? FontWeight.w500 : FontWeight.w600,
                  color: emphasis
                      ? colors.primary
                      : dim
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "kg ▾": picks the unit among the active ones, or opens their settings.
class _UnitSelector extends ConsumerWidget {
  const new({
    required this.unit,
    required this.enabled,
    required this.onSelected,
  });

  final LoadUnit? unit;
  final bool enabled;
  final ValueChanged<String> onSelected;

  static const String _manage = '__manage__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(activeLoadUnitsProvider);
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: Strings.unit,
      padding: EdgeInsets.zero,
      onSelected: (value) =>
          value == _manage ? context.push(Routes.loadUnits) : onSelected(value),
      itemBuilder: (context) => [
        for (final u in units)
          PopupMenuItem(
            value: u.id,
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: u.name,
                      children: [
                        TextSpan(
                          text:
                              '  ${Strings.unitStep(formatLoadValue(u.step, 2))}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (u.id == unit?.id)
                  Icon(Symbols.check_rounded, size: 20, color: colors.primary),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _manage, child: Text(Strings.manageUnits)),
      ],
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  unit?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Symbols.arrow_drop_down_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
