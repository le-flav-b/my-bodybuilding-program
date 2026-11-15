import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';

/// Search field, muscle filter chips and the matching exercises: the body
/// shared by the catalogue screen and the exercise picker.
class CatalogueList extends ConsumerStatefulWidget {
  const new({
    required this.onExerciseTap,
    required this.onCreate,
    this.showArchivedToggle = true,
    this.initialMuscleIds = const {},
    this.excludeExerciseIds = const {},
    this.thumbSize = 64,
    this.trailingChevron = true,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this.bottomSpace = 96,
    super.key,
  });

  final ValueChanged<Exercise> onExerciseTap;

  /// Opens the create screen, with the search text as a suggested name.
  final ValueChanged<String> onCreate;
  final bool showArchivedToggle;
  final Set<String> initialMuscleIds;
  final Set<String> excludeExerciseIds;
  final double thumbSize;
  final bool trailingChevron;
  final EdgeInsets padding;

  /// Room left under the list (for a FAB).
  final double bottomSpace;

  @override
  ConsumerState<CatalogueList> createState() => _CatalogueListState();
}

class _CatalogueListState extends ConsumerState<CatalogueList> {
  final _search = TextEditingController();
  late Set<String> _muscleIds = {...widget.initialMuscleIds};
  bool _archived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final muscles = ref.watch(visibleMusclesProvider);
    final activeCount = all.where((e) => !e.isArchived).length;
    final query = _search.text.trim();
    final results = [
      for (final e in filterExercises(
        all,
        query: query,
        muscleIds: _muscleIds,
        archived: _archived,
      ))
        if (!widget.excludeExerciseIds.contains(e.id)) e,
    ];

    return Column(
      children: [
        Padding(
          padding: widget.padding,
          child: SearchField(
            controller: _search,
            hint: widget.showArchivedToggle
                ? Strings.searchExercises(activeCount)
                : Strings.searchExercisesShort,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            children: [
              if (widget.showArchivedToggle) ...[
                AppFilterChip(
                  label: Strings.archived,
                  icon: Symbols.inventory_2_rounded,
                  selected: _archived,
                  onSelected: (v) => setState(() => _archived = v),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              for (final muscle in muscles) ...[
                AppFilterChip(
                  label: muscle.name,
                  selected: _muscleIds.contains(muscle.id),
                  onSelected: (selected) => setState(() {
                    final next = {..._muscleIds};
                    if (selected) {
                      next.add(muscle.id);
                    } else {
                      next.remove(muscle.id);
                    }
                    _muscleIds = next;
                  }),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: results.isEmpty
              ? _empty(query)
              : ListView.builder(
                  padding: widget.padding.copyWith(
                    top: AppSpacing.xs,
                    bottom: widget.bottomSpace,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) => CatalogueRow(
                    exercise: results[index],
                    thumbSize: widget.thumbSize,
                    trailingChevron: widget.trailingChevron,
                    onTap: () => widget.onExerciseTap(results[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _empty(String query) {
    if (_archived && query.isEmpty && _muscleIds.isEmpty) {
      return const EmptyState(
        icon: Symbols.inventory_2_rounded,
        title: Strings.noArchivedExercises,
        body: Strings.noArchivedExercisesBody,
      );
    }
    return EmptyState(
      icon: Symbols.search_off_rounded,
      title: query.isEmpty
          ? Strings.noExercises
          : Strings.noExerciseMatches(query),
      body: Strings.noExercisesBody,
      action: TextButton.icon(
        onPressed: () => widget.onCreate(query),
        icon: const Icon(Symbols.add_rounded),
        label: Text(
          query.isEmpty ? Strings.newExercise : Strings.createNamed(query),
        ),
      ),
    );
  }
}

/// A catalogue row: image well, name and muscles.
class CatalogueRow extends ConsumerWidget {
  const new({
    required this.exercise,
    required this.onTap,
    this.thumbSize = 64,
    this.trailingChevron = true,
    super.key,
  });

  final Exercise exercise;
  final VoidCallback onTap;
  final double thumbSize;
  final bool trailingChevron;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final muscles = ref.watch(exerciseMuscleNamesProvider(exercise.id));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: thumbSize + 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              ExerciseThumb(exerciseId: exercise.id, size: thumbSize),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium,
                    ),
                    if (muscles.isNotEmpty)
                      Text(
                        muscles,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium!.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailingChevron)
                Icon(
                  Symbols.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
