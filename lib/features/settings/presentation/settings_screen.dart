import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_controller.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// Settings, behind the gear icon of the Profile.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final controller = ref.read(settingsControllerProvider);
    final units = ref.watch(activeLoadUnitsProvider);
    final muscles = ref.watch(visibleMusclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          const SettingsSectionLabel(Strings.appearance),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Symbols.contrast_rounded,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(Strings.theme, style: context.text.bodyLarge),
                const Spacer(),
                SegmentedButton<AppThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AppThemeMode.system,
                      label: Text(Strings.themeSystem),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.light,
                      label: Text(Strings.themeLight),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.dark,
                      label: Text(Strings.themeDark),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => controller.setThemeMode(s.single),
                ),
              ],
            ),
          ),
          const SettingsSectionLabel(Strings.library),
          ListTile(
            leading: const Icon(Symbols.straighten_rounded),
            title: const Text(Strings.loadUnits),
            subtitle: Text(
              units.map((u) => u.name).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _CountChevron(units.length),
            onTap: () => context.push(Routes.loadUnits),
          ),
          ListTile(
            leading: const Icon(Symbols.accessibility_new_rounded),
            title: const Text(Strings.muscles),
            subtitle: const Text(Strings.musclesSubtitle),
            trailing: _CountChevron(muscles.length),
            onTap: () => context.push(Routes.muscles),
          ),
        ],
      ),
    );
  }
}

/// Section title of a settings list (`titleSmall` in primary).
class SettingsSectionLabel extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: context.text.titleSmall!.copyWith(color: context.colors.primary),
      ),
    );
  }
}

class _CountChevron extends StatelessWidget {
  const new(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count', style: context.text.bodyMedium!.copyWith(color: color)),
        Icon(Symbols.chevron_right_rounded, color: color),
      ],
    );
  }
}
