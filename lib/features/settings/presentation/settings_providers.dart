import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

/// The user's preferences, live.
@Riverpod(keepAlive: true)
Stream<AppSettings> appSettings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchSettings();

/// The preferences, or the defaults while they load.
@Riverpod(keepAlive: true)
AppSettings currentSettings(Ref ref) =>
    ref.watch(appSettingsProvider).value ?? const AppSettings();

/// System / Light / Dark as Flutter's [ThemeMode].
@Riverpod(keepAlive: true)
ThemeMode appThemeMode(Ref ref) =>
    switch (ref.watch(currentSettingsProvider).themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
