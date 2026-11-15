import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_list.dart';

/// Opens the exercise picker (bottom sheet, ~90 % of the height) and
/// returns the chosen exercise, or null.
///
/// [replacing] turns it into the swap picker: it names the exercise being
/// replaced and starts filtered on [initialMuscleIds] (its primary muscle).
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  Exercise? replacing,
  Set<String> initialMuscleIds = const {},
  Set<String> excludeExerciseIds = const {},
}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _ExercisePicker(
        replacing: replacing,
        initialMuscleIds: initialMuscleIds,
        excludeExerciseIds: excludeExerciseIds,
      ),
    ),
  );
}

class _ExercisePicker extends StatelessWidget {
  const new({
    required this.replacing,
    required this.initialMuscleIds,
    required this.excludeExerciseIds,
  });

  final Exercise? replacing;
  final Set<String> initialMuscleIds;
  final Set<String> excludeExerciseIds;

  @override
  Widget build(BuildContext context) {
    final replaced = replacing;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    replaced == null
                        ? Strings.addExercise
                        : Strings.swapExercise,
                    style: context.text.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push(Routes.newExercise()),
                  icon: const Icon(Symbols.add_rounded),
                  label: const Text(Strings.newShort),
                ),
              ],
            ),
          ),
          if (replaced != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                Strings.swapReplacing(replaced.name),
                style: context.text.bodyMedium!.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: CatalogueList(
              showArchivedToggle: false,
              initialMuscleIds: initialMuscleIds,
              excludeExerciseIds: excludeExerciseIds,
              thumbSize: 56,
              trailingChevron: false,
              bottomSpace: AppSpacing.xl,
              onExerciseTap: (e) => Navigator.of(context).pop(e),
              onCreate: (name) => context.push(Routes.newExercise(name: name)),
            ),
          ),
        ],
      ),
    );
  }
}
