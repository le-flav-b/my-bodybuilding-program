import 'dart:async';

import 'package:my_bodybuilding_program/core/notifications/device_feedback.dart';
import 'package:my_bodybuilding_program/core/notifications/reminder_scheduler.dart';
import 'package:my_bodybuilding_program/core/notifications/workout_notifier.dart';
import 'package:timezone/timezone.dart' as tz;

/// Records what the app asked the notification system to do.
class FakeWorkoutNotifier implements WorkoutNotifier {
  int permissionRequests = 0;
  WorkoutStatusNotice? status;
  final List<WorkoutStatusNotice> statuses = [];
  ({DateTime at, String title, bool sound, bool vibration})? alert;
  int clears = 0;

  @override
  Future<void> requestPermission() async => permissionRequests++;

  @override
  Future<void> showStatus(WorkoutStatusNotice notice) async {
    status = notice;
    statuses.add(notice);
  }

  @override
  Future<void> scheduleAlert({
    required DateTime at,
    required String title,
    required String body,
    required bool sound,
    required bool vibration,
  }) async =>
      alert = (at: at, title: title, sound: sound, vibration: vibration);

  @override
  Future<void> cancelAlert() async => alert = null;

  @override
  Future<void> clear() async {
    status = null;
    alert = null;
    clears++;
  }
}

/// Counts beeps and vibrations.
class FakeDeviceFeedback implements DeviceFeedback {
  int ticks = 0;
  int beeps = 0;
  int vibrations = 0;
  bool screenOn = false;

  @override
  Future<void> tick() async => ticks++;

  @override
  Future<void> beep() async => beeps++;

  @override
  Future<void> vibrate() async => vibrations++;

  @override
  Future<void> keepScreenOn({required bool on}) async => screenOn = on;
}

/// Records the reminders the app schedules; grants or refuses the
/// permission; can simulate a tap on a reminder.
class FakeReminderScheduler implements ReminderScheduler {
  new({tz.Location? location}) : location = location ?? tz.UTC;

  tz.Location location;
  bool grantPermission = true;
  int permissionRequests = 0;
  int applyCount = 0;
  bool lastRescheduleAll = false;
  List<ReminderNotification> scheduled = const [];
  String? launchPayload;
  final StreamController<String> _taps = StreamController.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<tz.Location> localLocation() async => location;

  @override
  Future<void> apply(
    List<ReminderNotification> notifications, {
    bool rescheduleAll = false,
  }) async {
    applyCount++;
    lastRescheduleAll = rescheduleAll;
    scheduled = List.unmodifiable(notifications);
  }

  @override
  Stream<String> get taps => _taps.stream;

  /// As if the user tapped the reminder with [payload].
  void tap(String payload) => _taps.add(payload);

  @override
  Future<String?> takeLaunchPayload() async {
    final payload = launchPayload;
    launchPayload = null;
    return payload;
  }
}
