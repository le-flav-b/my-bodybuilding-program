import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/data/units_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

/// Actions of the Settings screens (preferences and load units).
class SettingsController {
  new(this._ref);

  final Ref _ref;

  SettingsRepository get _settings => _ref.read(settingsRepositoryProvider);
  UnitsRepository get _units => _ref.read(unitsRepositoryProvider);

  Future<void> setThemeMode(AppThemeMode mode) => _settings.setThemeMode(mode);

  Future<void> setDefaultRestSeconds(int seconds) =>
      _settings.setDefaultRestSeconds(seconds);

  Future<void> setTimerSound({required bool enabled}) =>
      _settings.setTimerSound(enabled: enabled);

  Future<void> setTimerVibration({required bool enabled}) =>
      _settings.setTimerVibration(enabled: enabled);

  Future<void> setKeepScreenOn({required bool enabled}) =>
      _settings.setKeepScreenOn(enabled: enabled);

  Future<void> setWeeklyTarget(int target) => _settings.setWeeklyTarget(target);

  /// Creates ([unitId] null) or updates a custom unit.
  Future<void> saveUnit(String? unitId, LoadUnitDraft draft) async {
    if (unitId == null) {
      await _units.createUnit(draft);
    } else {
      await _units.updateUnit(unitId, draft);
    }
  }

  Future<void> archiveUnit(String unitId) => _units.archiveUnit(unitId);

  Future<void> restoreUnit(String unitId) => _units.restoreUnit(unitId);

  /// Only for a unit that was never used.
  Future<void> deleteUnit(String unitId) => _units.deleteUnit(unitId);
}

@Riverpod(keepAlive: true)
SettingsController settingsController(Ref ref) => SettingsController(ref);
