import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository.g.dart';

/// Key/value preferences.
class SettingsRepository {
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<AppSettings> watchSettings() =>
      _db.personalDao.watching([_db.settings], getSettings);

  Future<AppSettings> getSettings() async =>
      AppSettings.fromMap(await _db.personalDao.allSettings());

  Future<String?> getRaw(String key) => _db.personalDao.setting(key);

  Future<void> putRaw(String key, String value) =>
      _db.personalDao.putSetting(key, value, _clock());

  Future<void> setThemeMode(AppThemeMode mode) =>
      putRaw(SettingKeys.themeMode, mode.name);

  Future<void> setDefaultRestSeconds(int seconds) => putRaw(
    SettingKeys.defaultRestSeconds,
    '${seconds.clamp(AppSettings.minRest, AppSettings.maxRest)}',
  );

  Future<void> setTimerSound({required bool enabled}) =>
      putRaw(SettingKeys.timerSound, '$enabled');

  Future<void> setTimerVibration({required bool enabled}) =>
      putRaw(SettingKeys.timerVibration, '$enabled');

  Future<void> setKeepScreenOn({required bool enabled}) =>
      putRaw(SettingKeys.keepScreenOn, '$enabled');

  Future<void> setWeeklyTarget(int target) => putRaw(
    SettingKeys.weeklyTarget,
    '${target.clamp(AppSettings.minWeeklyTarget, AppSettings.maxWeeklyTarget)}',
  );
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => SettingsRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
);
