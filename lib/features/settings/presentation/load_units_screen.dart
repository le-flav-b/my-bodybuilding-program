import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_controller.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/unit_editor_dialog.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// The user-managed list of load units. `kg` is built in and locked.
class LoadUnitsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(loadUnitsProvider).value ?? const <LoadUnit>[];
    final usage = ref.watch(unitUsageProvider).value ?? const <String, int>{};
    final active = units.where((u) => !u.isArchived).toList();
    final archived = units.where((u) => u.isArchived).toList();
    final colors = context.colors;

    String describe(LoadUnit unit) {
      final step = formatLoadValue(unit.step, 2);
      final decimals = Strings.decimals(unit.decimals);
      return unit.isBuiltin
          ? Strings.unitBuiltIn(step, decimals)
          : Strings.unitSummary(
              step,
              decimals,
              Strings.usedInExercises(usage[unit.id] ?? 0),
            );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.loadUnits)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: InfoLine(Strings.unitsNeverConverted),
          ),
          for (final unit in active)
            ListTile(
              leading: const Icon(Symbols.straighten_rounded),
              title: Text(unit.name),
              subtitle: Text(describe(unit)),
              trailing: unit.isBuiltin
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Symbols.lock_rounded,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : IconButton(
                      tooltip: Strings.editUnit,
                      icon: const Icon(Symbols.edit_rounded),
                      onPressed: () => showUnitEditor(
                        context,
                        unit: unit,
                        usage: usage[unit.id] ?? 0,
                      ),
                    ),
            ),
          if (archived.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                Strings.archived,
                style: context.text.titleSmall!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            for (final unit in archived)
              ListTile(
                leading: const Icon(Symbols.inventory_2_rounded),
                title: Text(unit.name),
                subtitle: Text(describe(unit)),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(settingsControllerProvider).restoreUnit(unit.id),
                  child: const Text(Strings.restore),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showUnitEditor(context),
        icon: const Icon(Symbols.add_rounded),
        label: const Text(Strings.addUnit),
      ),
    );
  }
}
