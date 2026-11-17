import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_controller.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/exercise_progress_card.dart';

/// One exercise: image, measure, muscles, form cues and my notes/setup.
class ExerciseDetailScreen extends ConsumerWidget {
  const new({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseProvider(exerciseId));
    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ref.watch(exercisesProvider).isLoading
            ? const SizedBox.shrink()
            : const EmptyState(
                icon: Symbols.search_off_rounded,
                title: Strings.exercisesTitle,
                body: Strings.exerciseNotFound,
              ),
      );
    }
    final muscles = ref.watch(musclesByIdProvider);
    final colors = context.colors;
    final isReps = exercise.measure == Measure.reps;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: Strings.editExercise,
            icon: const Icon(Symbols.edit_rounded),
            onPressed: () => context.push(Routes.editExercise(exerciseId)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          ImageWell(
            height: 240,
            radius: 0,
            child: ExerciseImageView(exercise: exercise, labelSize: 14),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: context.text.headlineMedium!.copyWith(
                    fontSize: 26,
                    height: 32 / 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      isReps ? Symbols.repeat_rounded : Symbols.timer_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isReps ? Strings.reps : Strings.time,
                      style: context.text.bodyMedium!.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in exercise.primaryMuscleIds)
                      if (muscles[id] case final m?)
                        _MuscleTag(name: m.name, primary: true),
                    for (final id in exercise.secondaryMuscleIds)
                      if (muscles[id] case final m?)
                        _MuscleTag(name: m.name, primary: false),
                  ],
                ),
                if (exercise.isArchived) ...[
                  const SizedBox(height: 14),
                  const InfoLine(
                    Strings.archivedBanner,
                    icon: Symbols.inventory_2_rounded,
                  ),
                ],
                if (exercise.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    exercise.description,
                    style: context.text.bodyLarge!.copyWith(
                      fontSize: 15,
                      height: 22 / 15,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _NotesCard(exerciseId: exerciseId),
                const SizedBox(height: AppSpacing.sm),
                ExerciseProgressCard(exerciseId: exerciseId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleTag extends StatelessWidget {
  const new({required this.name, required this.primary});

  final String name;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: primary ? colors.primaryContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          name,
          style: TextStyle(
            fontSize: 13,
            height: 1,
            fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
            color: primary ? colors.onPrimaryContainer : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// "My notes / setup": personal, separate from the catalogue entry, and
/// editable in place.
class _NotesCard extends ConsumerStatefulWidget {
  const new({required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<_NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends ConsumerState<_NotesCard> {
  final _controller = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(catalogueControllerProvider)
        .saveNote(widget.exerciseId, _controller.text);
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final notes =
        ref.watch(exerciseNotesProvider).value?[widget.exerciseId] ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Overline(Strings.myNotes)),
              IconButton(
                tooltip: _editing ? Strings.save : Strings.editNotes,
                icon: Icon(
                  _editing ? Symbols.check_rounded : Symbols.edit_rounded,
                  size: 20,
                ),
                onPressed: _editing
                    ? _save
                    : () => setState(() {
                        _controller.text = notes;
                        _editing = true;
                      }),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _editing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: Strings.myNotesHint,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _save(),
                  )
                : Text(
                    notes.isEmpty ? Strings.myNotesEmpty : notes,
                    style: context.text.bodyLarge!.copyWith(
                      fontSize: 15,
                      height: 22 / 15,
                      color: notes.isEmpty ? colors.onSurfaceVariant : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
