import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/core/notifications/device_feedback.dart';
import 'package:my_bodybuilding_program/core/notifications/workout_notifier.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_runtime.g.dart';

/// Keeps what surrounds a workout in step with it:
///
/// - the ongoing notification (elapsed time, rest countdown, paused);
/// - the end of a rest: beep + vibration in the foreground, a scheduled
///   alert while the app is in the background;
/// - the same alert for a timed set that is running ([holdEndsAt]).
class WorkoutRuntime {
  WorkoutRuntime(this._ref);

  final Ref _ref;
  WorkoutDetail? _detail;
  Timer? _restTimer;
  String? _shownStatus;
  bool _foreground = true;
  DateTime? _holdEndsAt;
  AppLifecycleListener? _lifecycle;

  WorkoutNotifier get _notifier => _ref.read(workoutNotifierProvider);
  Clock get _clock => _ref.read(clockProvider);

  /// Starts following the workout in progress. Called once at launch.
  void start() {
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) =>
          unawaited(_onForeground(state == AppLifecycleState.resumed)),
    );
    _ref
      ..onDispose(dispose)
      ..listen(activeWorkoutProvider, (_, next) {
        if (next.hasValue) unawaited(_onWorkout(next.value));
      }, fireImmediately: true);
  }

  void dispose() {
    _restTimer?.cancel();
    _lifecycle?.dispose();
  }

  /// End of the timed set that is running, or null. Lets the background
  /// alert also ring for a hold.
  set holdEndsAt(DateTime? value) {
    _holdEndsAt = value;
    if (!_foreground) unawaited(_scheduleAlert());
  }

  Future<void> _onWorkout(WorkoutDetail? detail) async {
    final previous = _detail;
    _detail = detail;
    _restTimer?.cancel();
    if (detail == null) {
      _shownStatus = null;
      _holdEndsAt = null;
      if (previous != null) await _notifier.clear();
      return;
    }
    await _showStatus(detail);
    final workout = detail.workout;
    final endsAt = workout.restEndsAt;
    if (endsAt != null && !workout.isPaused) {
      final remaining = endsAt.difference(_clock());
      _restTimer = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        () => unawaited(_onRestOver(workout.id)),
      );
    }
    if (!_foreground) await _scheduleAlert();
  }

  Future<void> _onRestOver(String workoutId) async {
    if (_foreground) {
      final settings = _ref.read(currentSettingsProvider);
      final feedback = _ref.read(deviceFeedbackProvider);
      if (settings.timerSound) unawaited(feedback.beep());
      if (settings.timerVibration) unawaited(feedback.vibrate());
    }
    await _ref.read(workoutControllerProvider).completeRest(workoutId);
  }

  Future<void> _onForeground(bool foreground) async {
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      await _notifier.cancelAlert();
    } else {
      await _scheduleAlert();
    }
  }

  /// Schedules (or cancels) the background alert for the next timer end.
  Future<void> _scheduleAlert() async {
    final workout = _detail?.workout;
    final now = _clock();
    final candidates = [
      if (workout != null && !workout.isPaused) ?workout.restEndsAt,
      if (workout != null && !workout.isPaused) ?_holdEndsAt,
    ].where((t) => t.isAfter(now)).toList()..sort();
    if (workout == null || candidates.isEmpty) {
      await _notifier.cancelAlert();
      return;
    }
    final at = candidates.first;
    final isRest = at == workout.restEndsAt;
    final settings = _ref.read(currentSettingsProvider);
    await _notifier.scheduleAlert(
      at: at,
      title: isRest ? Strings.notifyRestOverTitle : Strings.notifyHoldOverTitle,
      body: _nextUp(_detail!) ?? workout.sessionName,
      sound: settings.timerSound,
      vibration: settings.timerVibration,
    );
  }

  Future<void> _showStatus(WorkoutDetail detail) async {
    final workout = detail.workout;
    final now = _clock();
    final WorkoutStatusNotice notice;
    if (workout.isPaused) {
      notice = PausedNotice(
        title: workout.sessionName,
        body: Strings.notifyPaused,
      );
    } else if (workout.restEndsAt case final endsAt?) {
      notice = RestNotice(
        title: Strings.notifyRest(workout.sessionName),
        body: _nextUp(detail) ?? '',
        endsAt: endsAt,
      );
    } else {
      notice = ActiveNotice(
        title: workout.sessionName,
        body: _nextUp(detail) ?? Strings.notifyInProgress,
        clockStart: now.subtract(
          Duration(seconds: WorkoutClock.elapsedSeconds(workout, now)),
        ),
      );
    }
    // The chronometer runs by itself: only re-post when something changed.
    final signature = switch (notice) {
      ActiveNotice() => 'active|${notice.body}|${workout.pausedSeconds}',
      RestNotice(:final endsAt) => 'rest|${notice.body}|$endsAt',
      PausedNotice() => 'paused',
    };
    if (signature == _shownStatus) return;
    _shownStatus = signature;
    await _notifier.showStatus(notice);
  }

  /// "Overhead press · set 2 of 3".
  String? _nextUp(WorkoutDetail detail) {
    var exercise = detail.currentExercise;
    if (exercise != null && exercise.isFinished) {
      exercise = detail.nextUnfinishedAfter(exercise.id);
    }
    final set = exercise?.nextSet;
    if (exercise == null || set == null) return null;
    final name =
        _ref.read(exercisesByIdProvider)[exercise.exerciseId]?.name ?? '';
    return Strings.exerciseSetOf(
      name,
      exercise.sets.indexOf(set) + 1,
      exercise.sets.length,
    );
  }
}

@Riverpod(keepAlive: true)
WorkoutRuntime workoutRuntime(Ref ref) => WorkoutRuntime(ref)..start();
