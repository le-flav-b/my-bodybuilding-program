import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/big_button.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/core/utils/date_text.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_providers.dart';
import 'package:my_bodybuilding_program/features/progress/domain/records.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_widgets.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/session_preview_screen.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// After Finish: "Update the program?" first when the plan changed, then
/// duration, sets, exercises, new records, a note and the next session.
class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const new({required this.workoutId, super.key});

  final String workoutId;

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  final TextEditingController _note = TextEditingController();
  bool _asked = false;
  bool _noteLoaded = false;
  Timer? _saveNote;

  @override
  void dispose() {
    _saveNote?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _onNoteChanged(String text) {
    _saveNote?.cancel();
    _saveNote = Timer(const Duration(milliseconds: 600), () {
      unawaited(
        ref
            .read(workoutControllerProvider)
            .setWorkoutNotes(widget.workoutId, text.trim()),
      );
    });
  }

  Future<void> _done() async {
    _saveNote?.cancel();
    await ref
        .read(workoutControllerProvider)
        .setWorkoutNotes(widget.workoutId, _note.text.trim());
    if (mounted) context.go(Routes.today);
  }

  Future<void> _askUpdate(WorkoutDetail detail) async {
    final controller = ref.read(workoutControllerProvider);
    final changes = controller.planChanges(detail);
    if (changes.isEmpty) return;
    final update = await showUpdateProgramDialog(
      context,
      ref,
      sessionName: detail.workout.sessionName,
      changes: changes,
    );
    if (update) await controller.applyChangesToProgram(detail.workout.id);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(workoutDetailProvider(widget.workoutId)).value;
    if (detail == null) return const Scaffold();
    if (!_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_askUpdate(detail));
      });
    }
    if (!_noteLoaded) {
      _noteLoaded = true;
      _note.text = detail.workout.notes;
    }
    final colors = context.colors;
    final workout = detail.workout;
    final records = Records.ofWorkout(
      workoutRecordEvents(
        detail,
        ref.watch(loggedSetsByExerciseProvider),
        ref.watch(exercisesByIdProvider),
      ),
      workout.id,
    );
    final next = ref.watch(programOverviewProvider).value?.nextSession;
    final ended = workout.endedAt ?? workout.lastActivityAt;

    Widget tile(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Text(label, style: context.text.bodyMedium),
            const SizedBox(height: 2),
            Text(
              value,
              style: context.text.headlineMedium!.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_done());
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Center(
                child: Overline(
                  Strings.workoutComplete,
                  color: colors.primary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                workout.sessionName,
                textAlign: TextAlign.center,
                style: context.text.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${DateText.mediumDay(workout.startedAt)} ${PlanFormat.dot} '
                '${DateText.time(workout.startedAt)} – ${DateText.time(ended)}',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  tile(
                    Strings.duration,
                    PlanFormat.clock(
                      WorkoutClock.elapsedSeconds(workout, ended),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  tile(Strings.sets, '${detail.doneSetCount}'),
                  const SizedBox(width: AppSpacing.sm),
                  tile(
                    Strings.exercisesTile,
                    '${detail.doneExerciseCount} / ${detail.exercises.length}',
                  ),
                ],
              ),
              if (records.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Overline(
                  Strings.newRecords(records.length),
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final r in records) _RecordCard(event: r),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _note,
                onChanged: _onNoteChanged,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: Strings.workoutNote,
                  hintText: Strings.workoutNoteHint,
                  alignLabelWithHint: true,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.skip_next_rounded,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        Strings.nextSessionLabel,
                        style: context.text.bodyLarge!.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          next.session.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          child: BigButton(
            expand: true,
            icon: Symbols.check_rounded,
            label: Strings.done,
            onPressed: () => unawaited(_done()),
          ),
        ),
      ),
    );
  }
}

class _RecordCard extends ConsumerWidget {
  const new({required this.event});

  final RecordEvent event;

  static const Color _ink = Color(0xFF181B1E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(unitLookupProvider);
    final name = ref.watch(exerciseProvider(event.exerciseId))?.name ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.appColors.trophy,
            ),
            child: const Icon(
              Symbols.trophy_rounded,
              size: 22,
              fill: 1,
              color: _ink,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name ${PlanFormat.dot} ${recordTypeLabel(event.series)}',
                  style: context.text.titleMedium!.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
                Text(
                  '${recordValueText(event, units)} ${PlanFormat.dot} '
                  '${Strings.wasRecord(recordPreviousText(event, units))}',
                  style: context.text.bodyMedium!.copyWith(
                    color: colors.onSecondaryContainer,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
