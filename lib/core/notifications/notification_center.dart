import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

/// The one `flutter_local_notifications` plugin of the app, initialised
/// once for the workout notifications and the reminders (the plugin has a
/// single tap callback).
class NotificationCenter {
  new _();

  static final NotificationCenter instance = NotificationCenter._();

  static const String _icon = '@mipmap/ic_launcher';

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController.broadcast();
  Future<void>? _ready;

  /// Payloads of the notifications tapped while the app runs.
  Stream<String> get taps => _taps.stream;

  AndroidFlutterLocalNotificationsPlugin? get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> ensureReady() => _ready ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload case final payload?) _taps.add(payload);
      },
    );
  }

  /// The payload of the notification that launched the app, if any.
  Future<String?> launchPayload() async {
    await ensureReady();
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
}
