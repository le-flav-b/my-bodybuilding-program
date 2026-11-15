import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/core/utils/app_logger.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_controller.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';

/// Creates ([exerciseId] null) or edits an exercise of the catalogue.
class ExerciseEditScreen extends ConsumerStatefulWidget {
  const new({this.exerciseId, this.initialName, super.key});

  final String? exerciseId;

  /// Suggested name for a new exercise (from a search with no match).
  final String? initialName;

  @override
  ConsumerState<ExerciseEditScreen> createState() => _ExerciseEditScreenState();
}

class _ExerciseEditScreenState extends ConsumerState<ExerciseEditScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  Measure _measure = Measure.reps;
  ExerciseImage? _image;
  List<String> _primary = [];
  List<String> _secondary = [];

  Exercise? _original;
  ExerciseUsage _usage = (hasHistory: false, isPlanned: false);
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;

  /// Photos stored during this edit; removed again if it is not saved.
  final List<UserImage> _pickedPhotos = [];

  bool get _isNew => widget.exerciseId == null;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.exerciseId;
    if (id != null) {
      final exercise = await ref
          .read(catalogueRepositoryProvider)
          .getExercise(id);
      final usage = await ref.read(catalogueControllerProvider).usageOf(id);
      if (!mounted) return;
      if (exercise != null) {
        _original = exercise;
        _name.text = exercise.name;
        _description.text = exercise.description;
        _measure = exercise.measure;
        _image = exercise.image;
        _primary = [...exercise.primaryMuscleIds];
        _secondary = [...exercise.secondaryMuscleIds];
      }
      _usage = usage;
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _changed(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  /// Tap once = primary, twice = secondary, three times = off.
  void _cycleMuscle(String id) => _changed(() {
    if (_primary.contains(id)) {
      _primary.remove(id);
      _secondary.add(id);
    } else if (_secondary.contains(id)) {
      _secondary.remove(id);
    } else {
      _primary.add(id);
    }
  });

  Future<void> _pick({required bool fromCamera}) async {
    try {
      final image = await ref
          .read(catalogueControllerProvider)
          .pickPhoto(fromCamera: fromCamera);
      if (image == null || !mounted) return;
      _pickedPhotos.add(image);
      _changed(() => _image = image);
    } on Exception catch (error, stack) {
      AppLogger.error('Photo pick failed', error: error, stackTrace: stack);
      if (mounted) showAppSnackBar(context, Strings.photoFailed);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppSnackBar(context, Strings.nameRequired);
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(catalogueControllerProvider);
    await controller.save(
      widget.exerciseId,
      ExerciseDraft(
        name: _name.text,
        description: _description.text,
        measure: _measure,
        image: _image,
        primaryMuscleIds: _primary,
        secondaryMuscleIds: _secondary,
      ),
    );
    // Photos picked and then replaced during this edit are not needed.
    await controller.discardPhotos(_pickedPhotos.where((p) => p != _image));
    _dirty = false;
    if (mounted) context.pop();
  }

  Future<void> _close() async {
    if (_dirty) {
      final discard = await showConfirmDialog(
        context,
        title: Strings.discardChangesTitle,
        message: Strings.discardChangesBody,
        confirmLabel: Strings.discard,
        cancelLabel: Strings.keepEditing,
        destructive: true,
      );
      if (!discard) return;
    }
    await ref.read(catalogueControllerProvider).discardPhotos(_pickedPhotos);
    _dirty = false;
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final exercise = _original!;
    final confirmed = await showConfirmDialog(
      context,
      title: Strings.deleteExerciseTitle(exercise.name),
      message: Strings.deleteExerciseBody,
      confirmLabel: Strings.delete,
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(catalogueControllerProvider).delete(exercise.id);
    _dirty = false;
    if (!mounted) return;
    // Leave the edit screen and the detail of the deleted exercise.
    context
      ..pop()
      ..pop();
  }

  Future<void> _archive() async {
    final exercise = _original!;
    final confirmed = await showConfirmDialog(
      context,
      title: Strings.archiveExerciseTitle(exercise.name),
      message: Strings.archiveExerciseBody,
      confirmLabel: Strings.archive,
    );
    if (!confirmed) return;
    await ref.read(catalogueControllerProvider).archive(exercise.id);
    _dirty = false;
    if (mounted) context.pop();
  }

  Future<void> _restore() async {
    await ref.read(catalogueControllerProvider).restore(_original!.id);
    _dirty = false;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muscles = ref.watch(visibleMusclesProvider);
    final measureLocked = _usage.hasHistory || _usage.isPlanned;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: Strings.close,
            icon: const Icon(Symbols.close_rounded),
            onPressed: _close,
          ),
          titleSpacing: 0,
          title: Text(_isNew ? Strings.newExercise : Strings.editExercise),
          actions: [
            TextButton(
              onPressed: _loaded && !_saving ? _save : null,
              child: const Text(Strings.save, style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: !_loaded
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  _PhotoArea(
                    image: _image,
                    measure: _measure,
                    primaryMuscleIds: _primary,
                    onCamera: () => _pick(fromCamera: true),
                    onGallery: () => _pick(fromCamera: false),
                    onRemove: () => _changed(() => _image = null),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _name,
                          autofocus: _isNew && _name.text.isEmpty,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _dirty = true,
                          decoration: const InputDecoration(
                            labelText: Strings.exerciseName,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          controller: _description,
                          minLines: 3,
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _dirty = true,
                          decoration: const InputDecoration(
                            labelText: Strings.exerciseDescription,
                            hintText: Strings.exerciseDescriptionHint,
                            alignLabelWithHint: true,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const _FieldLabel(Strings.measure),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<Measure>(
                            segments: const [
                              ButtonSegment(
                                value: Measure.reps,
                                label: Text(Strings.reps),
                              ),
                              ButtonSegment(
                                value: Measure.time,
                                label: Text(Strings.time),
                              ),
                            ],
                            selected: {_measure},
                            onSelectionChanged: measureLocked
                                ? null
                                : (s) => _changed(() => _measure = s.single),
                          ),
                        ),
                        if (measureLocked)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              Strings.measureLocked,
                              style: context.text.bodySmall,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        const _FieldLabel(Strings.musclesPickLabel),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final muscle in muscles)
                              _MuscleChoice(
                                name: muscle.name,
                                role: _primary.contains(muscle.id)
                                    ? MuscleRole.primary
                                    : _secondary.contains(muscle.id)
                                    ? MuscleRole.secondary
                                    : null,
                                onTap: () => _cycleMuscle(muscle.id),
                              ),
                          ],
                        ),
                        if (_original != null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          _LifecycleRow(
                            archived: _original!.isArchived,
                            hasHistory: _usage.hasHistory,
                            onDelete: _delete,
                            onArchive: _archive,
                            onRestore: _restore,
                          ),
                        ],
                        if (_saving)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.lg),
                            child: LinearProgressIndicator(
                              color: colors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: context.text.labelMedium!.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The 200-high photo area with the Camera and Gallery buttons.
class _PhotoArea extends StatelessWidget {
  const new({
    required this.image,
    required this.measure,
    required this.primaryMuscleIds,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final ExerciseImage? image;
  final Measure measure;
  final List<String> primaryMuscleIds;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = image;
    final pill = FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: colors.inverseSurface,
      foregroundColor: colors.onInverseSurface,
      iconSize: 18,
    );
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (current == null)
            ColoredBox(
              color: colors.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.add_a_photo_rounded,
                      size: 40,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      Strings.noPhoto,
                      style: context.text.bodyMedium!.copyWith(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ImageWell(
              radius: 0,
              child: ExerciseImageView(
                exercise: Exercise(
                  id: '',
                  name: '',
                  measure: measure,
                  image: current,
                  primaryMuscleIds: primaryMuscleIds,
                ),
              ),
            ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: Row(
              children: [
                if (current != null) ...[
                  IconButton.filled(
                    tooltip: Strings.removePhoto,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(40),
                      backgroundColor: colors.inverseSurface,
                      foregroundColor: colors.onInverseSurface,
                    ),
                    onPressed: onRemove,
                    icon: const Icon(Symbols.delete_rounded, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                FilledButton.icon(
                  style: pill,
                  onPressed: onCamera,
                  icon: const Icon(Symbols.photo_camera_rounded),
                  label: const Text(Strings.camera),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  style: pill,
                  onPressed: onGallery,
                  icon: const Icon(Symbols.image_rounded),
                  label: const Text(Strings.gallery),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A muscle chip with three states: primary (filled), secondary (tonal),
/// off (outlined).
class _MuscleChoice extends StatelessWidget {
  const new({required this.name, required this.role, required this.onTap});

  final String name;
  final MuscleRole? role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (role) {
      MuscleRole.primary => (colors.primary, colors.onPrimary),
      MuscleRole.secondary => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      null => (Colors.transparent, colors.onSurfaceVariant),
    };
    return Semantics(
      button: true,
      label: switch (role) {
        MuscleRole.primary => '$name, primary',
        MuscleRole.secondary => '$name, secondary',
        null => name,
      },
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: role == null
              ? BorderSide(color: colors.outline)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                name,
                style: context.text.labelLarge!.copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Only the action that applies: Delete (never used), Archive (has
/// history) or Restore (archived).
class _LifecycleRow extends StatelessWidget {
  const new({
    required this.archived,
    required this.hasHistory,
    required this.onDelete,
    required this.onArchive,
    required this.onRestore,
  });

  final bool archived;
  final bool hasHistory;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (text, button) = archived
        ? (
            Strings.isArchivedCanRestore,
            TextButton.icon(
              onPressed: onRestore,
              icon: const Icon(Symbols.restore_rounded),
              label: const Text(Strings.restore),
            ),
          )
        : hasHistory
        ? (
            Strings.hasHistoryCanArchive,
            TextButton.icon(
              onPressed: onArchive,
              icon: const Icon(Symbols.inventory_2_rounded),
              label: const Text(Strings.archive),
            ),
          )
        : (
            Strings.neverUsedCanDelete,
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: colors.error),
              onPressed: onDelete,
              icon: const Icon(Symbols.delete_rounded),
              label: const Text(Strings.delete),
            ),
          );
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium!.copyWith(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        button,
      ],
    );
  }
}
