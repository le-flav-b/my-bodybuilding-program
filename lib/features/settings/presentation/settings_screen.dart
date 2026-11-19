import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/app_info.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/value_dialogs.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
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
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.contrast_rounded,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Text(Strings.theme, style: context.text.bodyLarge),
                  ],
                ),
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
          const SettingsSectionLabel(Strings.workoutSection),
          ListTile(
            leading: const Icon(Symbols.timer_rounded),
            title: const Text(Strings.defaultRest),
            trailing: _ValueChevron(
              PlanFormat.clock(settings.defaultRestSeconds),
            ),
            onTap: () async {
              final picked = await showGoalDialog(
                context,
                title: Strings.defaultRest,
                initial: settings.defaultRestSeconds,
                step: 15,
                max: AppSettings.maxRest,
                asClock: true,
              );
              if (picked?.value case final v?) {
                await controller.setDefaultRestSeconds(v);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.volume_up_rounded),
            title: const Text(Strings.timerSound),
            value: settings.timerSound,
            onChanged: (v) => controller.setTimerSound(enabled: v),
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.vibration_rounded),
            title: const Text(Strings.timerVibration),
            value: settings.timerVibration,
            onChanged: (v) => controller.setTimerVibration(enabled: v),
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.brightness_high_rounded),
            title: const Text(Strings.keepScreenOn),
            subtitle: const Text(Strings.duringWorkouts),
            value: settings.keepScreenOn,
            onChanged: (v) => controller.setKeepScreenOn(enabled: v),
          ),
          const SettingsSectionLabel(Strings.streakSection),
          ListTile(
            leading: const Icon(Symbols.local_fire_department_rounded),
            title: const Text(Strings.weeklyTarget),
            subtitle: const Text(Strings.workoutsPerWeek),
            trailing: _Stepper(
              value: settings.weeklyTarget,
              min: 1,
              max: 7,
              onChanged: controller.setWeeklyTarget,
            ),
          ),
          const SettingsSectionLabel(Strings.about),
          ListTile(
            leading: const Icon(Symbols.info_rounded),
            title: const Text(Strings.version),
            trailing: Text(
              AppInfo.version,
              style: context.text.bodyMedium!.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
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

class _ValueChevron extends StatelessWidget {
  const new(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.text.bodyMedium!.copyWith(
            color: color,
            fontFeatures: AppTheme.tabular,
          ),
        ),
        Icon(Symbols.chevron_right_rounded, color: color),
      ],
    );
  }
}

/// Inline "− n +" with outlined round buttons.
class _Stepper extends StatelessWidget {
  const new({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: '${Strings.weeklyTarget} −',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Symbols.remove_rounded),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: context.text.titleMedium!.copyWith(
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: '${Strings.weeklyTarget} +',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Symbols.add_rounded),
        ),
      ],
    );
  }
}
