import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:my_bodybuilding_program/core/notifications/notification_center.dart';
import 'package:my_bodybuilding_program/core/utils/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/timezone.dart' as tz;

part 'workout_notifier.g.dart';

/// What the ongoing notification shows while a workout is in progress.
sealed class WorkoutStatusNotice {
  const new({required this.title, required this.body});

  final String title;
  final String body;
}

/// Training: the elapsed time counts up from [clockStart].
final class ActiveNotice extends WorkoutStatusNotice {
  const new({
    required super.title,
    required super.body,
    required this.clockStart,
  });

  /// Start of the workout shifted by the paused time.
  final DateTime clockStart;
}

/// Resting: counts down to [endsAt].
final class RestNotice extends WorkoutStatusNotice {
  const new({required super.title, required super.body, required this.endsAt});

  final DateTime endsAt;
}

/// Paused: nothing moves.
final class PausedNotice extends WorkoutStatusNotice {
  const new({required super.title, required super.body});
}

/// Notifications of a workout: the ongoing status and the alert at the end
/// of a rest or a hold. Tests replace it with a fake.
abstract interface class WorkoutNotifier {
  /// Asks for the notification permission (Android 13+). Safe to repeat.
  Future<void> requestPermission();

  /// Shows or updates the ongoing status notification.
  Future<void> showStatus(WorkoutStatusNotice notice);

  /// Schedules the alert that fires at [at] even with the app closed.
  Future<void> scheduleAlert({
    required DateTime at,
    required String title,
    required String body,
    required bool sound,
    required bool vibration,
  });

  Future<void> cancelAlert();

  /// Removes everything (workout finished or discarded).
  Future<void> clear();
}

/// [WorkoutNotifier] on `flutter_local_notifications`.
class LocalWorkoutNotifier implements WorkoutNotifier {
  new([NotificationCenter? center])
    : _center = center ?? NotificationCenter.instance;

  static const int statusId = 1;
  static const int alertId = 2;
  static const String _statusChannel = 'workout_status';

  final NotificationCenter _center;

  FlutterLocalNotificationsPlugin get _plugin => _center.plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _center.android;

  Future<void> _ensureReady() => _center.ensureReady();

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await _ensureReady();
      await action();
    } on Object catch (error, stackTrace) {
      // Notifications are a convenience: never break a workout over them.
      AppLogger.warning('Notification failed', error: error);
      AppLogger.error('Notification failed', stackTrace: stackTrace);
    }
  }

  @override
  Future<void> requestPermission() => _guard(() async {
    await _android?.requestNotificationsPermission();
  });

  @override
  Future<void> showStatus(WorkoutStatusNotice notice) => _guard(() async {
    final (anchor, countDown) = switch (notice) {
      ActiveNotice(:final clockStart) => (clockStart, false),
      RestNotice(:final endsAt) => (endsAt, true),
      PausedNotice() => (null, false),
    };
    await _plugin.show(
      id: statusId,
      title: notice.title,
      body: notice.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _statusChannel,
          'Workout in progress',
          channelDescription: 'Elapsed time and rest countdown while you train',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          category: AndroidNotificationCategory.stopwatch,
          showWhen: anchor != null,
          when: anchor?.millisecondsSinceEpoch,
          usesChronometer: anchor != null,
          chronometerCountDown: countDown,
        ),
      ),
    );
  });

  @override
  Future<void> scheduleAlert({
    required DateTime at,
    required String title,
    required String body,
    required bool sound,
    required bool vibration,
  }) => _guard(() async {
    // Sound and vibration are fixed per channel on Android: one channel
    // for each combination of the two settings.
    final channel =
        'timer_alert_${sound ? 'sound' : 'silent'}'
        '_${vibration ? 'vibrate' : 'still'}';
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: alertId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          'Timer finished',
          channelDescription: 'Alert at the end of a rest or a timed set',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          enableVibration: vibration,
          category: AndroidNotificationCategory.alarm,
          timeoutAfter: 60000,
        ),
      ),
    );
  });

  @override
  Future<void> cancelAlert() => _guard(() => _plugin.cancel(id: alertId));

  @override
  Future<void> clear() => _guard(() async {
    await _plugin.cancel(id: alertId);
    await _plugin.cancel(id: statusId);
  });
}

@Riverpod(keepAlive: true)
WorkoutNotifier workoutNotifications(Ref ref) => LocalWorkoutNotifier();
