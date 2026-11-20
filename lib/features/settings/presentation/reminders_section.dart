import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/value_dialogs.dart';
import 'package:my_bodybuilding_program/features/settings/domain/reminders.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/reminder_runtime.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_controller.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_screen.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/value_chevron.dart';

/// "18:00" for 1080 minutes after midnight.
String reminderTimeText(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// "Mon", "Tue"… for an ISO weekday.
String weekdayShortName(int weekday) =>
    DateFormat('EEE').format(DateTime(2024, 1, weekday)); // 1 Jan 2024: Mon

/// "Monday"… for an ISO weekday.
String weekdayLongName(int weekday) =>
    DateFormat('EEEE').format(DateTime(2024, 1, weekday));

/// "Mon, Wed, Fri · 18:00", "Every day · 07:30".
String trainingReminderSummary(ReminderSettings settings) {
  final days = settings.trainingDays.length == 7
      ? Strings.everyDay
      : settings.trainingDays.map(weekdayShortName).join(', ');
  return '$days · ${reminderTimeText(settings.trainingMinutes)}';
}

/// Settings › Reminders: the training and weigh-in reminders, each a
/// switch that reveals its options when on.
class RemindersSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reminderSettingsProvider);
    final controller = ref.read(settingsControllerProvider);

    Future<void> toggle(ReminderKind kind, {required bool on}) async {
      final done = await controller.setReminder(kind, enabled: on);
      if (!done && context.mounted) await _showNotificationsOff(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionLabel(Strings.remindersSection),
        SwitchListTile(
          secondary: const Icon(Symbols.notifications_rounded),
          title: const Text(Strings.trainingReminder),
          subtitle: Text(
            settings.trainingEnabled
                ? trainingReminderSummary(settings)
                : Strings.reminderOff,
          ),
          value: settings.trainingEnabled,
          onChanged: (on) => toggle(ReminderKind.training, on: on),
        ),
        if (settings.trainingEnabled) ...[
          _WeekdayPicker(
            selected: settings.trainingDays,
            onChanged: controller.setTrainingReminderDays,
          ),
          ListTile(
            leading: const Icon(Symbols.schedule_rounded),
            title: const Text(Strings.reminderTime),
            trailing: ValueChevron(reminderTimeText(settings.trainingMinutes)),
            onTap: () async {
              final minutes = await _pickTime(
                context,
                settings.trainingMinutes,
              );
              if (minutes != null) {
                await controller.setTrainingReminderMinutes(minutes);
              }
            },
          ),
        ],
        SwitchListTile(
          secondary: const Icon(Symbols.monitor_weight_rounded),
          title: const Text(Strings.weighInReminder),
          subtitle: Text(
            settings.weighInEnabled
                ? Strings.weighInSummary(
                    settings.weighInAfterDays,
                    reminderTimeText(settings.weighInMinutes),
                  )
                : Strings.reminderOff,
          ),
          value: settings.weighInEnabled,
          onChanged: (on) => toggle(ReminderKind.weighIn, on: on),
        ),
        if (settings.weighInEnabled) ...[
          ListTile(
            leading: const Icon(Symbols.event_repeat_rounded),
            title: const Text(Strings.remindAfter),
            subtitle: const Text(Strings.remindAfterSubtitle),
            trailing: ValueChevron(Strings.dayCount(settings.weighInAfterDays)),
            onTap: () async {
              final picked = await showGoalDialog(
                context,
                title: Strings.remindAfterTitle,
                initial: settings.weighInAfterDays,
                step: 1,
                min: ReminderSettings.minAfterDays,
                max: ReminderSettings.maxAfterDays,
                presets: const [7, 14, 30],
              );
              if (picked?.value case final days?) {
                await controller.setWeighInAfterDays(days);
              }
            },
          ),
          ListTile(
            leading: const Icon(Symbols.schedule_rounded),
            title: const Text(Strings.reminderTime),
            trailing: ValueChevron(reminderTimeText(settings.weighInMinutes)),
            onTap: () async {
              final minutes = await _pickTime(context, settings.weighInMinutes);
              if (minutes != null) {
                await controller.setWeighInReminderMinutes(minutes);
              }
            },
          ),
        ],
      ],
    );
  }

  /// Material time picker, 24-hour clock. Minutes after midnight.
  static Future<int?> _pickTime(BuildContext context, int minutes) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  static Future<void> _showNotificationsOff(BuildContext context) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(Strings.notificationsOffTitle),
          content: const Text(Strings.notificationsOffBody),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(Strings.ok),
            ),
          ],
        ),
      );
}

/// Seven round day toggles, Monday first. The last selected day can't be
/// turned off.
class _WeekdayPicker extends StatelessWidget {
  const new({required this.selected, required this.onChanged});

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
            Builder(
              builder: (context) {
                final on = selected.contains(day);
                final locked = on && selected.length == 1;
                return Semantics(
                  label: weekdayLongName(day),
                  selected: on,
                  button: true,
                  excludeSemantics: true,
                  child: InkResponse(
                    radius: 24,
                    onTap: locked
                        ? null
                        : () => onChanged(
                            on
                                ? [...selected.where((d) => d != day)]
                                : [...selected, day],
                          ),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on ? colors.primary : null,
                            border: on
                                ? null
                                : Border.all(color: colors.outline),
                          ),
                          child: Text(
                            weekdayShortName(day).substring(0, 1),
                            style: context.text.labelLarge!.copyWith(
                              color: on
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
