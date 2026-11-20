import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/core/notifications/reminder_scheduler.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/body_weight_providers.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/settings/domain/reminders.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/timezone.dart' as tz;

part 'reminder_runtime.g.dart';

/// The reminder settings, live.
@Riverpod(keepAlive: true)
ReminderSettings reminderSettings(Ref ref) =>
    ref.watch(currentSettingsProvider).reminders;

/// What the enabled reminders depend on; null while it loads. Only the
/// data of an enabled reminder is watched.
@Riverpod(keepAlive: true)
ReminderFacts? reminderFacts(Ref ref) {
  final settings = ref.watch(reminderSettingsProvider);
  var facts = const ReminderFacts();
  if (settings.trainingEnabled) {
    final program = ref.watch(programOverviewProvider);
    final active = ref.watch(activeWorkoutProvider);
    final workouts = ref.watch(workoutSummariesProvider);
    if (!program.hasValue || !active.hasValue || !workouts.hasValue) {
      return null;
    }
    DateTime? lastEnded;
    for (final w in workouts.value!) {
      final ended = w.endedAt;
      if (ended != null && (lastEnded == null || ended.isAfter(lastEnded))) {
        lastEnded = ended;
      }
    }
    facts = facts.copyWith(
      nextSessionName: program.value!.nextSession?.session.name,
      workoutInProgress: active.value != null,
      lastWorkoutEndedAt: lastEnded,
    );
  }
  if (settings.weighInEnabled) {
    final weights = ref.watch(bodyWeightsProvider);
    if (!weights.hasValue) return null;
    DateTime? last;
    for (final w in weights.value!) {
      if (last == null || w.measuredAt.isAfter(last)) last = w.measuredAt;
    }
    facts = facts.copyWith(lastWeighInAt: last);
  }
  return facts;
}

/// Keeps the scheduled reminders in step with their settings and data, and
/// opens the right screen when one is tapped.
///
/// The plan ([ReminderPlanner]) is recomputed at launch, when the app comes
/// back to the foreground, and whenever the settings or facts change
/// (workout logged, finished or discarded, program edited, weight logged).
class ReminderRuntime {
  new(this._ref);

  final Ref _ref;
  AppLifecycleListener? _lifecycle;
  StreamSubscription<String>? _taps;
  tz.Location? _location;
  List<ReminderNotification>? _applied;
  Future<void>? _running;
  bool _again = false;

  ReminderScheduler get _scheduler => _ref.read(reminderSchedulerProvider);

  /// Starts following the reminders. Called once at launch.
  void start() {
    _lifecycle = AppLifecycleListener(
      onResume: () {
        // Time moved on and the time zone may have changed.
        _location = null;
        unawaited(refresh());
      },
    );
    _taps = _scheduler.taps.listen(openFromPayload);
    _ref
      ..onDispose(dispose)
      ..listen(reminderSettingsProvider, (_, _) => unawaited(refresh()))
      ..listen(reminderFactsProvider, (_, _) => unawaited(refresh()));
    unawaited(refresh());
    unawaited(
      _scheduler.takeLaunchPayload().then((payload) {
        if (payload != null) openFromPayload(payload);
      }),
    );
  }

  void dispose() {
    _lifecycle?.dispose();
    unawaited(_taps?.cancel());
  }

  /// Plans the reminders again (coalesced: one run at a time).
  Future<void> refresh() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _run();
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;
        await _apply();
      } while (_again);
    } finally {
      _running = null;
    }
  }

  Future<void> _apply() async {
    final settings = _ref.read(reminderSettingsProvider);
    final List<ReminderNotification> plan;
    if (settings.anyEnabled) {
      final facts = _ref.read(reminderFactsProvider);
      if (facts == null) return; // Planned again once the data is loaded.
      final location = _location ??= await _scheduler.localLocation();
      plan = [
        for (final occurrence in ReminderPlanner.plan(
          settings: settings,
          facts: facts,
          now: _ref.read(clockProvider)(),
          location: location,
        ))
          notificationOf(occurrence, facts),
      ];
    } else {
      plan = const [];
    }
    if (listEquals(plan, _applied)) return;
    // The first plan of the process schedules everything again.
    await _scheduler.apply(plan, rescheduleAll: _applied == null);
    _applied = plan;
  }

  /// Opens Today (training) or the Profile with the log-weight dialog
  /// (weigh-in).
  void openFromPayload(String payload) {
    final kind = kindOfPayload(payload);
    if (kind == null) return;
    final router = _ref.read(routerProvider);
    switch (kind) {
      case ReminderKind.training:
        router.go(Routes.today);
      case ReminderKind.weighIn:
        router.go(Routes.profile);
        _ref.read(weighInRequestProvider.notifier).request();
    }
  }

  /// "training@2026-11-20T17:00:00.000Z" → training.
  static ReminderKind? kindOfPayload(String payload) {
    final name = payload.split('@').first;
    for (final kind in ReminderKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  /// The notification of [occurrence], with its texts.
  static ReminderNotification notificationOf(
    ReminderOccurrence occurrence,
    ReminderFacts facts,
  ) {
    final (title, body) = switch (occurrence.kind) {
      ReminderKind.training => switch (facts.nextSessionName) {
        final name? => (
          Strings.reminderTrainingTitle(name),
          Strings.reminderTrainingBody,
        ),
        null => (Strings.reminderTrainTitle, Strings.reminderTrainBody),
      },
      ReminderKind.weighIn => (
        Strings.reminderWeighInTitle,
        switch (occurrence.daysSinceWeighIn) {
          final days? => Strings.reminderWeighInBody(days),
          null => Strings.reminderFirstWeighInBody,
        },
      ),
    };
    return ReminderNotification(
      id: occurrence.id,
      at: occurrence.at,
      title: title,
      body: body,
      payload:
          '${occurrence.kind.name}@${occurrence.at.toUtc().toIso8601String()}',
    );
  }
}

@Riverpod(keepAlive: true)
ReminderRuntime reminderRuntime(Ref ref) => ReminderRuntime(ref)..start();
