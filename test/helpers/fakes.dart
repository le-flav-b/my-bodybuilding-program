import 'package:my_bodybuilding_program/core/notifications/device_feedback.dart';
import 'package:my_bodybuilding_program/core/notifications/workout_notifier.dart';

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
