import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/big_button.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/core/notifications/device_feedback.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/progress/domain/records.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_overlays.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_parts.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_rest_view.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_timed_view.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// The guided workout: one exercise at a time, its sets, the rest timer,
/// timed sets, pause and records.
class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<WorkoutPlayerScreen> createState() =>
      _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends ConsumerState<WorkoutPlayerScreen> {
  RecordEvent? _trophy;
  Timer? _trophyTimer;
  bool _logging = false;
  late final DeviceFeedback _feedback;

  @override
  void initState() {
    super.initState();
    _feedback = ref.read(deviceFeedbackProvider);
    if (ref.read(currentSettingsProvider).keepScreenOn) {
      unawaited(_feedback.keepScreenOn(on: true));
    }
  }

  @override
  void dispose() {
    _trophyTimer?.cancel();
    unawaited(_feedback.keepScreenOn(on: false));
    super.dispose();
  }

  Future<void> _log(
    WorkoutDetail detail,
    WorkoutExercise exercise,
    WorkoutSet set,
    SetValues values,
  ) async {
    if (_logging) return;
    _logging = true;
    try {
      final record = await ref
          .read(workoutControllerProvider)
          .logSet(
            detail,
            exercise,
            set,
            reps: values.reps,
            seconds: values.seconds,
            load: values.load,
            unitId: values.unitId,
          );
      if (record != null && mounted) _showTrophy(record);
    } finally {
      _logging = false;
    }
  }

  void _showTrophy(RecordEvent event) {
    _trophyTimer?.cancel();
    setState(() => _trophy = event);
    _trophyTimer = Timer(const Duration(seconds: 4), _closeTrophy);
  }

  void _closeTrophy() {
    _trophyTimer?.cancel();
    if (mounted) setState(() => _trophy = null);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeWorkoutProvider);
    final detail = async.value;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Symbols.close_rounded),
            onPressed: () => context.go(Routes.today),
          ),
        ),
      );
    }
    final trophy = _trophy;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(showLeaveDialog(context, ref, detail));
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: PlayerHeader(
                    detail: detail,
                    onLeave: () =>
                        unawaited(showLeaveDialog(context, ref, detail)),
                  ),
                ),
                SegmentBar(detail: detail),
                Expanded(child: _content(detail)),
                if (detail.exercises.isNotEmpty && !detail.isAllFinished)
                  NextExerciseFooter(detail: detail),
              ],
            ),
            if (detail.workout.isPaused) PausedOverlay(detail: detail),
            if (trophy != null)
              TrophyOverlay(
                event: trophy,
                detail: detail,
                onClose: _closeTrophy,
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(WorkoutDetail detail) {
    final current = detail.currentExercise;
    if (detail.exercises.isEmpty || current == null) {
      return _NoExercises(detail: detail);
    }
    if (detail.workout.isResting) return RestView(detail: detail);
    if (detail.isAllFinished) return _AllDone(detail: detail);
    final measure = ref.watch(
      exercisesByIdProvider.select((m) => m[current.exerciseId]?.measure),
    );
    if (measure == Measure.time) {
      return TimedExerciseView(
        key: ValueKey('timed-${current.id}'),
        detail: detail,
        exercise: current,
        onLog: (e, s, v) => unawaited(_log(detail, e, s, v)),
      );
    }
    return _RepsExerciseView(
      key: ValueKey('reps-${current.id}'),
      detail: detail,
      exercise: current,
      onLog: (e, s, v) => unawaited(_log(detail, e, s, v)),
    );
  }
}

class _RepsExerciseView extends ConsumerWidget {
  const new({
    required this.detail,
    required this.exercise,
    required this.onLog,
    super.key,
  });

  final WorkoutDetail detail;
  final WorkoutExercise exercise;
  final void Function(WorkoutExercise, WorkoutSet, SetValues) onLog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastTimeSetsProvider(exercise.exerciseId));
    final records = ref.watch(workoutRecordSetIdsProvider(detail.workout.id));
    final next = exercise.isSkipped ? null : exercise.nextSet;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExerciseBlock(detail: detail, exercise: exercise),
          const SizedBox(height: AppSpacing.md),
          SetupNoteStrip(exerciseId: exercise.exerciseId),
          const SizedBox(height: AppSpacing.sm),
          for (final (i, set) in exercise.sets.indexed)
            if (set.id == next?.id)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: CurrentSetCard(
                  key: ValueKey('card-${set.id}'),
                  exercise: exercise,
                  set: set,
                  number: i + 1,
                  measure: Measure.reps,
                  last: lastAt(last, i),
                  onDone: (values) => onLog(exercise, set, values),
                ),
              )
            else
              SetRow(
                key: ValueKey('row-${set.id}'),
                exercise: exercise,
                set: set,
                number: i + 1,
                last: lastAt(last, i),
                isRecord: records.contains(set.id),
              ),
          const SizedBox(height: AppSpacing.xs),
          AddSetButton(exercise: exercise),
        ],
      ),
    );
  }
}

class _AllDone extends ConsumerWidget {
  const new({required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: Symbols.done_all_rounded,
              title: Strings.allDoneTitle,
              body: Strings.allDoneBody,
              action: BigButton(
                icon: Symbols.flag_rounded,
                label: Strings.finishWorkout,
                onPressed: () => unawaited(
                  finishWorkoutFlow(context, ref, detail.workout.id),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => unawaited(addExerciseFlow(context, ref, detail)),
              icon: const Icon(Symbols.add_rounded),
              label: const Text(Strings.addExercise),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoExercises extends ConsumerWidget {
  const new({required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: EmptyState(
          icon: Symbols.fitness_center_rounded,
          title: Strings.noExercisesInWorkout,
          body: Strings.noExercisesInWorkoutBody,
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.primary,
            ),
            onPressed: () => unawaited(addExerciseFlow(context, ref, detail)),
            icon: const Icon(Symbols.add_rounded),
            label: const Text(Strings.addExercise),
          ),
        ),
      ),
    );
  }
}
