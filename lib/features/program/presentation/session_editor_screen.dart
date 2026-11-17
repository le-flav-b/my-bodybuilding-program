import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/exercise_picker_sheet.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_controller.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_providers.dart';
import 'package:my_bodybuilding_program/features/program/presentation/set_table_editor.dart';
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
                style: AppTheme.tonal(context.colors).copyWith(
                  minimumSize: const WidgetStatePropertyAll(
                    Size.fromHeight(56),
                  ),
                ),
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
              child: SetTableEditor(
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
