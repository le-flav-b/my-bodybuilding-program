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
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/date_text.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/exercise_picker_sheet.dart';
import 'package:my_bodybuilding_program/features/program/domain/estimated_duration.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_controller.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_providers.dart';
import 'package:my_bodybuilding_program/features/program/presentation/set_table_editor.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_draft.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// "10, 10, 9, 8 · 40 kg": what was done last time, set by set.
String lastTimeText(List<LoggedSet> sets, UnitLookup units) =>
    PlanFormat.performed([
      for (final s in sets)
        SetTarget(
          reps: s.reps,
          seconds: s.seconds,
          load: s.load,
          unitId: s.unitId,
        ),
    ], units);

/// A session just before starting: its exercises with planned sets and last
/// time. Edits made here apply to this workout only.
class SessionPreviewScreen extends ConsumerStatefulWidget {
  const new({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionPreviewScreen> createState() =>
      _SessionPreviewScreenState();
}

class _SessionPreviewScreenState extends ConsumerState<SessionPreviewScreen> {
  /// The workout to be: the session's plan until something is edited here.
  List<WorkoutDraftExercise>? _draft;
  bool _starting = false;

  List<WorkoutDraftExercise> _planDraft() => [
    for (final e
        in ref.read(sessionPlanProvider(widget.sessionId))?.toPlan() ??
            const <PlannedExercise>[])
      WorkoutDraftExercise(plan: e),
  ];

  void _edit(void Function(List<WorkoutDraftExercise> draft) change) {
    final draft = [...(_draft ?? _planDraft())];
    change(draft);
    setState(() => _draft = draft);
  }

  Future<void> _add() async {
    final picked = await showExercisePicker(context);
    if (picked == null) return;
    final plan = await ref
        .read(programControllerProvider)
        .defaultPlanFor(picked);
    _edit((d) => d.add(WorkoutDraftExercise(plan: plan, fromPlan: false)));
  }

  Future<void> _swap(int index, WorkoutDraftExercise entry) async {
    final exercises = ref.read(exercisesByIdProvider);
    final current = exercises[entry.plan.exerciseId];
    final picked = await showExercisePicker(
      context,
      replacing: current,
      initialMuscleIds: {?current?.mainMuscleId},
      excludeExerciseIds: {entry.plan.exerciseId},
    );
    if (picked == null) return;
    final targets = SwapRule.targets(
      current: entry.plan.sets,
      from: current?.measure ?? picked.measure,
      to: picked.measure,
      lastLoads: [
        for (final s in ref.read(lastTimeSetsProvider(picked.id)))
          (load: s.load, unitId: s.unitId),
      ],
    );
    _edit(
      (d) => d[index] = entry.copyWith(
        plan: entry.plan.copyWith(exerciseId: picked.id, sets: targets),
        swappedFrom: entry.fromPlan
            ? entry.swappedFrom ?? entry.plan.exerciseId
            : null,
      ),
    );
  }

  Future<void> _editSets(int index) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final draft = _draft ?? _planDraft();
        if (index >= draft.length) return const SizedBox.shrink();
        final entry = draft[index];
        final exercise = ref.read(exercisesByIdProvider)[entry.plan.exerciseId];
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise?.name ?? '',
                        style: context.text.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _swap(index, entry);
                      },
                      icon: const Icon(Symbols.swap_horiz_rounded),
                      label: const Text(Strings.swap),
                    ),
                  ],
                ),
                SetTableEditor(
                  exercise: entry.plan,
                  measure: exercise?.measure ?? Measure.reps,
                  onChanged: (change) {
                    _edit(
                      (d) => d[index] = entry.copyWith(
                        plan: change(d[index].plan),
                      ),
                    );
                    setSheetState(() {});
                  },
                  onRemove: () {
                    Navigator.of(context).pop();
                    _edit((d) => d.removeAt(index));
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _start() async {
    final session = ref.read(sessionPlanProvider(widget.sessionId));
    if (session == null || _starting) return;
    if (ref.read(activeWorkoutProvider).value != null) {
      showAppSnackBar(context, Strings.workoutAlreadyRunning);
      return;
    }
    setState(() => _starting = true);
    await ref
        .read(workoutControllerProvider)
        .start(session, _draft ?? _planDraft());
    if (mounted) context.pushReplacement(Routes.workout);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionPlanProvider(widget.sessionId));
    if (session == null) return Scaffold(appBar: AppBar());
    final draft = _draft ?? _planDraft();
    final colors = context.colors;
    final estimate = _draft == null
        ? ref.watch(sessionEstimatesProvider)[widget.sessionId] ?? 0
        : EstimatedDuration.fromPlan([for (final d in draft) d.plan]);
    final lastDone = ref.watch(sessionLastDoneProvider)[widget.sessionId];
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(session.session.name),
        actions: [
          IconButton(
            tooltip: Strings.editSession,
            icon: const Icon(Symbols.edit_rounded),
            onPressed: () => context.push(Routes.session(widget.sessionId)),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SessionMeta(
                    exerciseCount: draft.length,
                    estimateSeconds: estimate,
                    lastDone: lastDone == null
                        ? Strings.neverDone
                        : DateText.relativeDay(lastDone, now),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const InfoLine(Strings.previewInfo),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverReorderableList(
              itemCount: draft.length,
              onReorderItem: (from, to) =>
                  _edit((d) => d.insert(to, d.removeAt(from))),
              itemBuilder: (context, index) => _PreviewRow(
                key: ValueKey('$index-${draft[index].plan.exerciseId}'),
                index: index,
                entry: draft[index],
                showDivider: index < draft.length - 1,
                onTap: () => _editSets(index),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(4, 4, AppSpacing.lg, 24),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _add,
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
          icon: Symbols.play_arrow_rounded,
          label: Strings.startWorkout,
          onPressed: draft.isEmpty || _starting ? null : _start,
        ),
      ),
      backgroundColor: colors.surface,
    );
  }
}

/// "6 exercises · ~55 min · 4 days ago" with icons.
class SessionMeta extends StatelessWidget {
  const new({
    required this.exerciseCount,
    required this.estimateSeconds,
    required this.lastDone,
    this.color,
    super.key,
  });

  final int exerciseCount;
  final int estimateSeconds;
  final String lastDone;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.onSurfaceVariant;
    Widget item(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.text.bodyMedium!.copyWith(
            color: tint,
            fontFeatures: AppTheme.tabular,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        item(Symbols.exercise_rounded, Strings.exerciseCount(exerciseCount)),
        if (exerciseCount > 0)
          item(
            Symbols.schedule_rounded,
            Strings.approxMinutes(EstimatedDuration.minutes(estimateSeconds)),
          ),
        item(Symbols.history_rounded, lastDone),
      ],
    );
  }
}

/// The sticky bar holding the one main action of a screen.
class BottomActionBar extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
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
          child: child,
        ),
      ),
    );
  }
}

class _PreviewRow extends ConsumerWidget {
  const new({
    required this.index,
    required this.entry,
    required this.showDivider,
    required this.onTap,
    super.key,
  });

  final int index;
  final WorkoutDraftExercise entry;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(unitLookupProvider);
    final exercise = ref.watch(exerciseProvider(entry.plan.exerciseId));
    final last = ref.watch(lastTimeSetsProvider(entry.plan.exerciseId));
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: colors.outlineVariant))
                : null,
          ),
          child: Row(
            children: [
              ExerciseThumb(exerciseId: entry.plan.exerciseId),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium,
                    ),
                    Text(
                      PlanFormat.summary(entry.plan.sets, units),
                      style: context.text.bodyMedium!.copyWith(
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                    if (last.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Symbols.history_rounded,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              Strings.lastTime(lastTimeText(last, units)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall!.copyWith(
                                fontFeatures: AppTheme.tabular,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Symbols.drag_indicator_rounded,
                    color: colors.onSurfaceVariant,
                    semanticLabel: Strings.reorder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
