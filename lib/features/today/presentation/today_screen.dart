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
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/date_text.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/program/domain/program.dart';
import 'package:my_bodybuilding_program/features/program/domain/rotation.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_controller.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_providers.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_screen.dart';
import 'package:my_bodybuilding_program/features/progress/domain/stats.dart';
import 'package:my_bodybuilding_program/features/progress/domain/streak.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/session_preview_screen.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// Tab 1: what to do now.
class TodayScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(programOverviewProvider).value;
    final active = ref.watch(activeWorkoutProvider);
    final summaries =
        ref.watch(workoutSummariesProvider).value ?? const <WorkoutSummary>[];
    final now = ref.watch(clockProvider)();
    final colors = context.colors;

    final Widget body;
    if (overview == null || active.isLoading) {
      body = const SizedBox.shrink();
    } else if (overview.isEmpty && active.value == null) {
      body = Padding(
        padding: const EdgeInsets.only(bottom: 64),
        child: EmptyState(
          artAsset: 'assets/images/sleep.png',
          title: Strings.todayWelcomeTitle,
          body: Strings.todayWelcomeBody,
          largeTitle: true,
          action: BigButton(
            icon: Symbols.add_rounded,
            label: Strings.todayCreateFirstSession,
            onPressed: () => createSessionFlow(context, ref),
          ),
        ),
      );
    } else {
      final workout = active.value;
      final last = summaries.isEmpty ? null : summaries.first;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Overline(DateText.longDay(now)),
                const SizedBox(height: 2),
                Text(
                  workout != null
                      ? Strings.workoutInProgress
                      : last == null
                      ? Strings.noWorkoutYet
                      : Strings.lastWorkoutWhen(
                          DateText.relativeDay(last.startedAt, now),
                        ),
                  style: context.text.titleMedium,
                ),
              ],
            ),
          ),
          if (workout != null) ...[
            _ResumeBanner(detail: workout),
            const SizedBox(height: AppSpacing.md),
            _UpNextCard(detail: workout),
          ] else if (overview.nextSession case final next?)
            _SessionCard(overview: overview, next: next),
          const SizedBox(height: AppSpacing.md),
          _WeekCard(summaries: summaries, now: now),
          if (last != null && workout == null) ...[
            const SizedBox(height: AppSpacing.md),
            _LastWorkoutCard(summary: last, now: now),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Text(
          Strings.appName,
          style: AppTheme.logo.copyWith(color: context.appColors.brand),
        ),
      ),
      backgroundColor: colors.surface,
      body: body,
    );
  }
}

/// Starts an empty workout and opens its list view to add exercises.
Future<void> startEmptyWorkout(BuildContext context, WidgetRef ref) async {
  if (ref.read(activeWorkoutProvider).value != null) {
    showAppSnackBar(context, Strings.workoutAlreadyRunning);
    return;
  }
  await ref.read(workoutControllerProvider).startEmpty();
  if (context.mounted) unawaited(context.push(Routes.workoutList));
}

class _SessionCard extends ConsumerWidget {
  const new({required this.overview, required this.next});

  final ProgramOverview overview;
  final SessionPlan next;

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(programControllerProvider);
    final skipped = await controller.skipNext();
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      Strings.skipped(next.session.name),
      actionLabel: Strings.undo,
      onAction: () => controller.setNextSession(skipped),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final id = next.session.id;
    final estimate = ref.watch(sessionEstimatesProvider)[id] ?? 0;
    final lastDone = ref.watch(sessionLastDoneProvider)[id];
    final now = ref.watch(clockProvider)();
    final place = Rotation.placeOf(overview.sessionIds, id) ?? 1;
    final thumbs = next.exercises.take(5).toList();
    final more = next.exercises.length - thumbs.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Overline(
            Strings.nextSessionOf(place, overview.sessions.length),
            color: colors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(next.session.name, style: context.text.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          SessionMeta(
            exerciseCount: next.exercises.length,
            estimateSeconds: estimate,
            lastDone: lastDone == null
                ? Strings.neverDone
                : DateText.relativeDay(lastDone, now),
          ),
          if (thumbs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final e in thumbs)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ExerciseThumb(
                      exerciseId: e.exerciseId,
                      size: 48,
                      radius: AppRadius.sm,
                    ),
                  ),
                if (more > 0)
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '+$more',
                      style: context.text.labelLarge!.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          BigButton(
            expand: true,
            icon: Symbols.play_arrow_rounded,
            label: Strings.start,
            onPressed: next.exercises.isEmpty
                ? () => context.push(Routes.session(id))
                : () => context.push(Routes.sessionPreview(id)),
          ),
          const SizedBox(height: AppSpacing.sm),
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            children: [
              _CardAction(
                icon: Symbols.swap_horiz_rounded,
                label: Strings.otherSession,
                onPressed: () => showPickSessionSheet(context),
              ),
              _CardAction(
                icon: Symbols.add_rounded,
                label: Strings.emptyWorkout,
                onPressed: () => startEmptyWorkout(context, ref),
              ),
              _CardAction(
                icon: Symbols.skip_next_rounded,
                label: Strings.skip,
                onPressed: overview.sessions.length < 2
                    ? null
                    : () => _skip(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const new({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

/// "Start another session": every session with when it was last done.
Future<void> showPickSessionSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _PickSessionSheet(),
    );

class _PickSessionSheet extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(programOverviewProvider).value;
    final lastDone = ref.watch(sessionLastDoneProvider);
    final now = ref.watch(clockProvider)();
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Strings.startAnotherSession, style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Strings.pointerFollows,
            style: context.text.bodyMedium!.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (i, plan)
              in (overview?.sessions ?? const <SessionPlan>[]).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Builder(
                builder: (context) {
                  final isNext = plan.session.id == overview?.nextSessionId;
                  final done = lastDone[plan.session.id];
                  final muted = isNext
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant;
                  return Material(
                    color: isNext
                        ? colors.primaryContainer
                        : colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      enabled: plan.exercises.isNotEmpty,
                      minTileHeight: 72,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isNext
                            ? colors.primary
                            : colors.surfaceContainerHigh,
                        foregroundColor: isNext
                            ? colors.onPrimary
                            : colors.onSurface,
                        child: Text(
                          '${i + 1}',
                          style: context.text.labelLarge!.copyWith(
                            color: isNext ? colors.onPrimary : null,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.session.name,
                              style: context.text.titleMedium!.copyWith(
                                color: isNext
                                    ? colors.onPrimaryContainer
                                    : null,
                              ),
                            ),
                          ),
                          if (isNext) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const PillBadge(Strings.programNext),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        plan.exercises.isEmpty
                            ? Strings.sessionHasNoExercises
                            : '${Strings.exerciseCount(plan.exercises.length)}'
                                  ' · ${done == null ? Strings.neverDone : DateText.relativeDay(done, now)}',
                        style: TextStyle(color: muted),
                      ),
                      trailing: Icon(Symbols.play_circle_rounded, color: muted),
                      onTap: () {
                        Navigator.of(context).pop();
                        unawaited(
                          context.push(Routes.sessionPreview(plan.session.id)),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Replaces the session card while a workout is in progress.
class _ResumeBanner extends ConsumerWidget {
  const new({required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = ref.watch(nowProvider);
    final workout = detail.workout;
    final current = detail.currentExercise;
    final position = current == null
        ? 0
        : detail.exercises.indexOf(current) + 1;
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.workout),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          workout.isPaused
                              ? Strings.notifyPaused
                              : Strings.inProgressFor(
                                  PlanFormat.clock(
                                    WorkoutClock.elapsedSeconds(workout, now),
                                  ),
                                ),
                          style: context.text.bodyMedium!.copyWith(
                            color: colors.onPrimary,
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      workout.sessionName,
                      style: context.text.titleLarge!.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                    Text(
                      Strings.exerciseProgress(
                        position,
                        detail.exercises.length,
                        detail.doneSetCount,
                      ),
                      style: context.text.bodyMedium!.copyWith(
                        color: colors.onPrimary,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.onPrimary,
                ),
                child: Icon(
                  Symbols.play_arrow_rounded,
                  fill: 1,
                  color: colors.primary,
                  semanticLabel: Strings.resume,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpNextCard extends ConsumerWidget {
  const new({required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    var exercise = detail.currentExercise;
    if (exercise != null && exercise.isFinished) {
      exercise = detail.nextUnfinishedAfter(exercise.id);
    }
    final set = exercise?.nextSet;
    final units = ref.watch(unitLookupProvider);
    final name = exercise == null
        ? null
        : ref.watch(exerciseProvider(exercise.exerciseId))?.name;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Overline(Strings.upNextIn(detail.workout.sessionName)),
          const SizedBox(height: AppSpacing.md),
          if (exercise == null || set == null)
            Text(Strings.allSetsDone, style: context.text.titleMedium)
          else
            Row(
              children: [
                ExerciseThumb(exerciseId: exercise.exerciseId, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name ?? '', style: context.text.titleMedium),
                      Text(
                        Strings.setOfWith(
                          exercise.sets.indexOf(set) + 1,
                          exercise.sets.length,
                          PlanFormat.set(
                            reps: set.target.reps,
                            seconds: set.target.seconds,
                            isMax: set.target.isMax,
                            loadValue: set.target.load,
                            unitId: set.target.unitId,
                            units: units,
                          ),
                        ),
                        style: context.text.bodyMedium!.copyWith(
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const new({required this.summaries, required this.now});

  final List<WorkoutSummary> summaries;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final target = ref.watch(currentSettingsProvider).weeklyTarget;
    final today = now.toLocal();
    final dates = [for (final w in summaries) w.startedAt.toLocal()];
    final streak = StreakRule.compute(
      dates,
      weeklyTarget: target,
      today: today,
    );
    final trained = {for (final d in dates) StreakRule.dayOf(d)};
    final monday = StreakRule.weekStart(today);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Overline(Strings.thisWeek(streak.thisWeek, target)),
              ),
              StreakChip(weeks: streak.current),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _WeekDay(
                  date: DateTime(monday.year, monday.month, monday.day + i),
                  trained: trained.contains(
                    DateTime(monday.year, monday.month, monday.day + i),
                  ),
                  isToday: i == today.weekday - 1,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "🔥 2 weeks", or a grey "No streak".
class StreakChip extends StatelessWidget {
  const new({required this.weeks, super.key});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = weeks > 0;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: active ? colors.secondaryContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.local_fire_department_rounded,
            size: 18,
            fill: 1,
            color: active ? context.appColors.brand : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            active ? Strings.streakWeeks(weeks) : Strings.noStreak,
            style: context.text.labelLarge!.copyWith(
              color: active
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const new({required this.date, required this.trained, required this.isToday});

  final DateTime date;
  final bool trained;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: 2,
              color: isToday ? colors.onSurface : Colors.transparent,
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: trained ? colors.primary : colors.surfaceContainerHigh,
            ),
            child: Text(
              '${date.day}',
              style: context.text.labelLarge!.copyWith(
                color: trained ? colors.onPrimary : colors.onSurface,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(DateText.weekdayShort(date), style: context.text.bodySmall),
      ],
    );
  }
}

class _LastWorkoutCard extends StatelessWidget {
  const new({required this.summary, required this.now});

  final WorkoutSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceContainerHigh,
            ),
            child: Icon(
              Symbols.history_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.sessionName} · '
                  '${DateText.relativeDay(summary.startedAt, now)}',
                  style: context.text.titleMedium,
                ),
                Text(
                  Strings.sessionSummary(
                    PlanFormat.duration(summary.durationSeconds),
                    summary.setCount,
                    summary.recordCount,
                  ),
                  style: context.text.bodyMedium!.copyWith(
                    color: colors.onSurfaceVariant,
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
