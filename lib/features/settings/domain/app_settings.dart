import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

/// System / Light / Dark.
enum AppThemeMode { system, light, dark }

/// Keys of the settings table.
abstract final class SettingKeys {
  static const String themeMode = 'theme_mode';
  static const String defaultRestSeconds = 'default_rest_s';
  static const String timerSound = 'timer_sound';
  static const String timerVibration = 'timer_vibration';
  static const String keepScreenOn = 'keep_screen_on';
  static const String weeklyTarget = 'weekly_target';

  /// Last imported seed version and every seed key ever imported.
  static const String seedVersion = 'seed.version';
  static const String seedKnownKeys = 'seed.known_keys';
}

/// User preferences, with the defaults of the spec.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory({
    @Default(AppThemeMode.system) AppThemeMode themeMode,
    @Default(AppSettings.defaultRest) int defaultRestSeconds,
    @Default(true) bool timerSound,
    @Default(true) bool timerVibration,
    @Default(true) bool keepScreenOn,
    @Default(AppSettings.defaultWeeklyTarget) int weeklyTarget,
  }) = _AppSettings;
  const new _();

  /// Builds the settings from the raw key/value rows.
  factory fromMap(Map<String, String> values) {
    bool flag(String key, {required bool fallback}) => switch (values[key]) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };
    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (m) => m.name == values[SettingKeys.themeMode],
        orElse: () => AppThemeMode.system,
      ),
      defaultRestSeconds:
          (int.tryParse(values[SettingKeys.defaultRestSeconds] ?? '') ??
                  defaultRest)
              .clamp(minRest, maxRest),
      timerSound: flag(SettingKeys.timerSound, fallback: true),
      timerVibration: flag(SettingKeys.timerVibration, fallback: true),
      keepScreenOn: flag(SettingKeys.keepScreenOn, fallback: true),
      weeklyTarget:
          (int.tryParse(values[SettingKeys.weeklyTarget] ?? '') ??
                  defaultWeeklyTarget)
              .clamp(minWeeklyTarget, maxWeeklyTarget),
    );
  }

  static const int defaultRest = 90;
  static const int minRest = 0;
  static const int maxRest = 600;
  static const int defaultWeeklyTarget = 3;
  static const int minWeeklyTarget = 1;
  static const int maxWeeklyTarget = 7;
}
