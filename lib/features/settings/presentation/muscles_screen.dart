import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_controller.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';

/// The muscle list used to tag exercises: add, rename, hide.
class MusclesScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await showTextPrompt(
      context,
      title: Strings.newMuscle,
      label: Strings.muscleName,
      confirmLabel: Strings.add,
    );
    if (name != null) {
      await ref.read(catalogueControllerProvider).addMuscle(name);
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Muscle muscle,
    int count,
  ) async {
    final controller = ref.read(catalogueControllerProvider);
    final name = await showTextPrompt(
      context,
      title: Strings.renameMuscle,
      label: Strings.muscleName,
      initial: muscle.name,
      extraActions: (dialogContext) => [
        if (count > 0)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(controller.setMuscleHidden(muscle.id, hidden: true));
            },
            child: const Text(Strings.hide),
          )
        else
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.error,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(controller.deleteMuscle(muscle.id));
            },
            child: const Text(Strings.delete),
          ),
      ],
    );
    if (name != null && name != muscle.name) {
      await controller.renameMuscle(muscle.id, name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscles = ref.watch(musclesProvider).value ?? const <Muscle>[];
    final counts =
        ref.watch(muscleExerciseCountsProvider).value ?? const <String, int>{};
    final visible = muscles.where((m) => !m.hidden).toList();
    final hidden = muscles.where((m) => m.hidden).toList();
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.muscles)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final muscle in visible)
            ListTile(
              title: Text(muscle.name),
              subtitle: Text(Strings.exerciseCount(counts[muscle.id] ?? 0)),
              trailing: IconButton(
                tooltip: Strings.renameMuscle,
                icon: const Icon(Symbols.edit_rounded),
                onPressed: () =>
                    _edit(context, ref, muscle, counts[muscle.id] ?? 0),
              ),
            ),
          if (hidden.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                Strings.hidden,
                style: context.text.titleSmall!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            for (final muscle in hidden)
              ListTile(
                title: Text(
                  muscle.name,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                subtitle: const Text(Strings.hiddenFromFilters),
                trailing: IconButton(
                  tooltip: Strings.show,
                  icon: const Icon(Symbols.visibility_off_rounded),
                  onPressed: () => ref
                      .read(catalogueControllerProvider)
                      .setMuscleHidden(muscle.id, hidden: false),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Symbols.add_rounded),
        label: const Text(Strings.addMuscle),
      ),
    );
  }
}
