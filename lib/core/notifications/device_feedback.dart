import 'package:flutter/services.dart';
import 'package:my_bodybuilding_program/core/utils/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'device_feedback.g.dart';

/// Sounds, vibration and screen wake of the workout. Tests use a fake.
abstract interface class DeviceFeedback {
  /// Short beep (3-2-1 lead-in).
  Future<void> tick();

  /// Long beep (go / time is up).
  Future<void> beep();

  Future<void> vibrate();

  /// Keeps the screen on, or lets it sleep again.
  Future<void> keepScreenOn({required bool on});
}

/// [DeviceFeedback] on Android: ToneGenerator and the vibrator through the
/// app's own platform channel (see MainActivity), wakelock for the screen.
class AndroidDeviceFeedback implements DeviceFeedback {
  static const MethodChannel _channel = MethodChannel(
    'com.leflavb.mybodybuildingprogram/feedback',
  );

  Future<void> _call(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      AppLogger.warning('Device feedback failed', error: error);
    }
  }

  @override
  Future<void> tick() =>
      _call(() => _channel.invokeMethod('beep', {'durationMs': 120}));

  @override
  Future<void> beep() =>
      _call(() => _channel.invokeMethod('beep', {'durationMs': 600}));

  @override
  Future<void> vibrate() =>
      _call(() => _channel.invokeMethod('vibrate', {'durationMs': 500}));

  @override
  Future<void> keepScreenOn({required bool on}) =>
      _call(() => WakelockPlus.toggle(enable: on));
}

@Riverpod(keepAlive: true)
DeviceFeedback deviceFeedback(Ref ref) => AndroidDeviceFeedback();
