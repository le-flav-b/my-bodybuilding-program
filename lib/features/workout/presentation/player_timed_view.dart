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
import 'package:my_bodybuilding_program/core/notifications/device_feedback.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_parts.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_widgets.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_runtime.dart';

enum _Phase { idle, leadIn, hold }

/// A time-based exercise: compact header, set chips, then either the
/// current set card (Time + Load, Log / Start) or the running timer:
/// 3-2-1 lead-in, then the hold counting down to the target (logged at 0)
/// or up for "max" (Stop logs the time held).
class TimedExerciseView extends ConsumerStatefulWidget {
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
  ConsumerState<TimedExerciseView> createState() => _TimedExerciseViewState();
}

class _TimedExerciseViewState extends ConsumerState<TimedExerciseView> {
  static const int _leadInMs = 3000;

  _Phase _phase = _Phase.idle;
  DateTime? _phaseStart;
  DateTime? _pausedAt;
  WorkoutSet? _set;
  SetValues? _values;
  Timer? _ticker;
  int _lastLeadInSecond = 3;
  int _shownFrame = -1;
  late final WorkoutRuntime _runtime;
  late final DeviceFeedback _feedback;

  @override
  void initState() {
    super.initState();
    _runtime = ref.read(workoutRuntimeProvider);
    _feedback = ref.read(deviceFeedbackProvider);
  }

  DateTime _now() => ref.read(clockProvider)();

  int get _targetSeconds => _values?.seconds ?? 0;
  bool get _isMax => _set?.target.isMax ?? false;

  int _elapsedMs() {
    final start = _phaseStart;
    if (start == null) return 0;
    return (_pausedAt ?? _now()).difference(start).inMilliseconds;
  }

  void _start(WorkoutSet set, SetValues values) {
    _set = set;
    _values = values;
    _phase = _Phase.leadIn;
    _phaseStart = _now();
    _lastLeadInSecond = 3;
    unawaited(_feedback.tick());
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _onTick(),
    );
    setState(() {});
  }

  void _onTick() {
    if (!mounted || _pausedAt != null) return;
    final elapsed = _elapsedMs();
    final settings = ref.read(currentSettingsProvider);
    switch (_phase) {
      case _Phase.idle:
        return;
      case _Phase.leadIn:
        if (elapsed >= _leadInMs) {
          if (settings.timerSound) unawaited(_feedback.beep());
          _phase = _Phase.hold;
          _phaseStart = _now();
          _updateHoldEnd();
        } else {
          final second = 3 - elapsed ~/ 1000;
          if (second != _lastLeadInSecond) {
            _lastLeadInSecond = second;
            if (settings.timerSound) unawaited(_feedback.tick());
          }
        }
      case _Phase.hold:
        if (!_isMax && elapsed >= _targetSeconds * 1000) {
          if (settings.timerSound) unawaited(_feedback.beep());
          if (settings.timerVibration) unawaited(_feedback.vibrate());
          _finish(_targetSeconds);
          return;
        }
    }
    // Repaint only when what is shown moves (4 times a second).
    final frame = _phase.index * 1000000 + _elapsedMs() ~/ 250;
    if (frame != _shownFrame) {
      _shownFrame = frame;
      setState(() {});
    }
  }

  void _updateHoldEnd() {
    final start = _phaseStart;
    _runtime.holdEndsAt =
        _phase == _Phase.hold && !_isMax && start != null && _pausedAt == null
        ? start.add(Duration(seconds: _targetSeconds))
        : null;
  }

  void _stop() {
    if (_phase == _Phase.hold) {
      final held = (_elapsedMs() / 1000).floor();
      _finish(held < 1 ? 1 : held);
    } else {
      _reset();
    }
  }

  void _finish(int seconds) {
    final set = _set;
    final values = _values;
    _reset();
    if (set == null || values == null) return;
    widget.onLog(widget.exercise, set, (
      reps: null,
      seconds: seconds,
      load: values.load,
      unitId: values.unitId,
    ));
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _phase = _Phase.idle;
    _phaseStart = null;
    _pausedAt = null;
    _runtime.holdEndsAt = null;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(TimedExerciseView old) {
    super.didUpdateWidget(old);
    if (_phase == _Phase.idle) return;
    final paused = widget.detail.workout.isPaused;
    if (paused && _pausedAt == null) {
      _pausedAt = _now();
      _updateHoldEnd();
    } else if (!paused && _pausedAt != null) {
      _phaseStart = _phaseStart?.add(_now().difference(_pausedAt!));
      _pausedAt = null;
      _updateHoldEnd();
    }
    // The set was edited away (list view, swap): stop the timer.
    if (widget.exercise.id != old.exercise.id ||
        !widget.exercise.sets.any((s) => s.id == _set?.id && !s.isDone)) {
      _reset();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _runtime.holdEndsAt = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final last = ref.watch(lastTimeSetsProvider(exercise.exerciseId));
    final next = exercise.nextSet;
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
          ExerciseBlock(
            detail: widget.detail,
            exercise: exercise,
            compact: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SetChips(
            exercise: exercise,
            current: _phase == _Phase.idle ? next : _set,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_phase == _Phase.idle) ...[
            SetupNoteStrip(exerciseId: exercise.exerciseId),
            const SizedBox(height: AppSpacing.md),
            if (next != null)
              CurrentSetCard(
                key: ValueKey('timed-${next.id}'),
                exercise: exercise,
                set: next,
                number: exercise.sets.indexOf(next) + 1,
                measure: Measure.time,
                last: lastAt(last, exercise.sets.indexOf(next)),
                onDone: (values) => widget.onLog(exercise, next, values),
                onStart: (values) => _start(next, values),
              ),
            AddSetButton(exercise: exercise),
          ] else
            _running(context),
        ],
      ),
    );
  }

  Widget _running(BuildContext context) {
    final colors = context.colors;
    final elapsed = _elapsedMs();
    final Widget ring;
    final String help;
    if (_phase == _Phase.leadIn) {
      final left = ((_leadInMs - elapsed) / 1000).ceil().clamp(1, 3);
      ring = TimerRing(
        fraction: (_leadInMs - elapsed) / _leadInMs,
        color: colors.secondary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Overline(
              Strings.getReady,
              color: colors.onSurfaceVariant,
              fontSize: 14,
            ),
            Text(
              '$left',
              style: AppTheme.timer.copyWith(color: colors.onSurface),
            ),
          ],
        ),
      );
      help = _isMax ? Strings.timedMaxHelp : Strings.timedHelp;
    } else {
      final heldSeconds = elapsed ~/ 1000;
      final index = widget.exercise.sets.indexWhere((s) => s.id == _set?.id);
      final lastSet = lastAt(
        ref.watch(lastTimeSetsProvider(widget.exercise.exerciseId)),
        index < 0 ? 0 : index,
      );
      final String shown;
      final String below;
      final double? fraction;
      if (_isMax) {
        shown = PlanFormat.clock(heldSeconds);
        final best = _bestSeconds();
        below = Strings.bestTime(best == null ? null : PlanFormat.clock(best));
        fraction = null;
      } else {
        final leftMs = _targetSeconds * 1000 - elapsed;
        shown = PlanFormat.clock((leftMs / 1000).ceil());
        below = Strings.targetAndLast(
          PlanFormat.clock(_targetSeconds),
          lastSet?.seconds == null ? null : PlanFormat.clock(lastSet!.seconds!),
        );
        fraction = _targetSeconds <= 0 ? 0 : leftMs / (_targetSeconds * 1000);
      }
      ring = TimerRing(
        fraction: fraction,
        color: colors.primary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Overline(
              _isMax ? PlanFormat.max : Strings.hold,
              color: colors.onSurfaceVariant,
              fontSize: 14,
            ),
            Text(
              shown,
              style: AppTheme.timer.copyWith(color: colors.onSurface),
            ),
            Text(
              below,
              style: context.text.bodyLarge!.copyWith(
                color: colors.onSurfaceVariant,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        ),
      );
      help = _isMax ? Strings.timedMaxHelp : Strings.timedHelp;
    }
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(child: ring),
        const SizedBox(height: AppSpacing.xl),
        BigButton(
          expand: true,
          icon: _phase == _Phase.leadIn
              ? Symbols.close_rounded
              : Symbols.stop_rounded,
          label: _phase == _Phase.leadIn ? Strings.cancel : Strings.stop,
          onPressed: _stop,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(help, textAlign: TextAlign.center, style: context.text.bodyMedium),
      ],
    );
  }

  int? _bestSeconds() {
    final sets =
        ref.read(loggedSetsByExerciseProvider)[widget.exercise.exerciseId] ??
        const [];
    int? best;
    for (final s in sets) {
      final v = s.seconds;
      if (v != null && (best == null || v > best)) best = v;
    }
    for (final s in widget.exercise.doneSets) {
      final v = s.seconds;
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }
}

class _SetChips extends ConsumerWidget {
  const new({required this.exercise, required this.current});

  final WorkoutExercise exercise;
  final WorkoutSet? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final success = context.appColors.success;
    Widget chip(int i, WorkoutSet set) {
      final isCurrent = set.id == current?.id;
      final Widget label;
      if (set.isDone) {
        label = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.check_rounded, size: 18, color: success),
            const SizedBox(width: 6),
            Text(
              PlanFormat.clock(set.seconds ?? 0),
              style: context.text.titleMedium!.copyWith(
                color: success,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        );
      } else {
        label = Text(
          Strings.setN(i + 1),
          style: context.text.titleMedium!.copyWith(
            color: isCurrent
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
        );
      }
      return Material(
        color: isCurrent ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: set.isDone
              ? () => unawaited(editLoggedSetFlow(context, ref, exercise, set))
              : null,
          child: SizedBox(height: 40, child: Center(child: label)),
        ),
      );
    }

    final sets = exercise.sets;
    if (sets.length <= 4) {
      return Row(
        children: [
          for (final (i, s) in sets.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: chip(i, s)),
          ],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, s) in sets.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 88, child: chip(i, s)),
          ],
        ],
      ),
    );
  }
}
