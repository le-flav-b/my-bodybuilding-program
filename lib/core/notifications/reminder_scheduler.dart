import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:my_bodybuilding_program/core/notifications/notification_center.dart';
import 'package:my_bodybuilding_program/core/utils/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/timezone.dart' as tz;

part 'reminder_scheduler.g.dart';

/// A reminder notification to show at [at] (an instant).
@immutable
class ReminderNotification {
  const new({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;

  /// Tells the app what to open on tap; it also carries the instant, so a
  /// moved reminder differs from the one already scheduled.
  final String payload;

  @override
  bool operator ==(Object other) =>
      other is ReminderNotification &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, at, title, body, payload);

  @override
  String toString() => 'ReminderNotification($id, $at, $title)';
}

/// The platform side of the reminders: permission, time zone, the
/// scheduled notifications and their taps. Tests replace it with a fake.
abstract interface class ReminderScheduler {
  /// Asks for the notification permission (Android 13+). True when
  /// notifications can be shown.
  Future<bool> requestPermission();

  /// The device's time zone, for local wall-clock times.
  Future<tz.Location> localLocation();

  /// Makes [notifications] the complete set of scheduled reminders:
  /// schedules new or changed ones and cancels the others. With
  /// [rescheduleAll], unchanged ones are scheduled again too (alarms are
  /// lost when the app is force-stopped, while the plugin still lists them).
  Future<void> apply(
    List<ReminderNotification> notifications, {
    bool rescheduleAll = false,
  });

  /// Payloads of the reminders tapped while the app runs.
  Stream<String> get taps;

  /// The payload of the reminder that launched the app, once.
  Future<String?> takeLaunchPayload();
}

/// [ReminderScheduler] on `flutter_local_notifications`: one-shot exact
/// alarms in their own channel, restored by the plugin's boot receiver.
class LocalReminderScheduler implements ReminderScheduler {
  new([NotificationCenter? center])
    : _center = center ?? NotificationCenter.instance;

  /// Reminder ids start here (see `ReminderOccurrence.id`); the workout
  /// notifications use small ids.
  static const int minId = 100000000;

  final NotificationCenter _center;
  bool _launchTaken = false;

  static const String _channel = 'reminders';
  static const MethodChannel _time = MethodChannel(
    'com.leflavb.mybodybuildingprogram/time',
  );

  @override
  Stream<String> get taps => _center.taps;

  @override
  Future<bool> requestPermission() async {
    try {
      await _center.ensureReady();
      final android = _center.android;
      if (android == null) return true;
      final granted = await android.requestNotificationsPermission();
      if (granted == false) return false;
      return await android.areNotificationsEnabled() ?? true;
    } on Object catch (error) {
      AppLogger.warning('Notification permission failed', error: error);
      return false;
    }
  }

  @override
  Future<tz.Location> localLocation() async {
    await _center.ensureReady();
    try {
      final id = await _time.invokeMethod<String>('timeZone');
      if (id != null) return tz.getLocation(id);
    } on Object catch (error) {
      AppLogger.warning('Time zone lookup failed', error: error);
    }
    // Unknown zone: today's offset, without daylight-saving changes.
    final offset = DateTime.now().timeZoneOffset;
    return tz.Location('Local', [tz.minTime], [0], [
      tz.TimeZone(offset, isDst: false, abbreviation: 'LT'),
    ]);
  }

  @override
  Future<void> apply(
    List<ReminderNotification> notifications, {
    bool rescheduleAll = false,
  }) async {
    try {
      await _center.ensureReady();
      final plugin = _center.plugin;
      final pending = {
        for (final p in await plugin.pendingNotificationRequests())
          if (p.id >= minId) p.id: p,
      };
      final wanted = {for (final n in notifications) n.id: n};
      for (final id in pending.keys) {
        if (!wanted.containsKey(id)) await plugin.cancel(id: id);
      }
      final exact =
          await _center.android?.canScheduleExactNotifications() ?? false;
      for (final n in notifications) {
        final current = pending[n.id];
        if (!rescheduleAll &&
            current != null &&
            current.title == n.title &&
            current.body == n.body &&
            current.payload == n.payload) {
          continue;
        }
        await plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          payload: n.payload,
          // The instant is computed in local time by the app; UTC keeps it
          // exact through reboots.
          scheduledDate: tz.TZDateTime.from(n.at.toUtc(), tz.UTC),
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channel,
              'Reminders',
              channelDescription: 'Training and weigh-in reminders',
              category: AndroidNotificationCategory.reminder,
            ),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      // Reminders are a convenience: never break the app over them.
      AppLogger.warning('Scheduling reminders failed', error: error);
      AppLogger.error('Scheduling reminders failed', stackTrace: stackTrace);
    }
  }

  @override
  Future<String?> takeLaunchPayload() async {
    if (_launchTaken) return null;
    _launchTaken = true;
    try {
      return await _center.launchPayload();
    } on Object catch (error) {
      AppLogger.warning('Launch details failed', error: error);
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
ReminderScheduler reminderScheduler(Ref ref) => LocalReminderScheduler();
