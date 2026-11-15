import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_controller.g.dart';

/// System / Light / Dark. Persisted with the other settings from M1 on.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;

  // A method reads better than a setter at call sites (`.set(mode)`).
  // ignore: use_setters_to_change_properties
  void set(ThemeMode mode) => state = mode;
}
