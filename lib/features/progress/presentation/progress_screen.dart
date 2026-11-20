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
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/app/widgets/exercise_image.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/date_text.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/progress/domain/calendar.dart';
import 'package:my_bodybuilding_program/features/progress/domain/chart_series.dart';
import 'package:my_bodybuilding_program/features/progress/domain/stats.dart';
import 'package:my_bodybuilding_program/features/progress/domain/streak.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_widgets.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/streak_chip.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// Tab 3: Calendar · Exercises · History.
class ProgressScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(workoutSummariesProvider);
    final empty = summaries.hasValue && summaries.value!.isEmpty;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: AppSpacing.lg,
          title: const TabTitle(Strings.tabProgress),
          bottom: empty
              ? null
              : const TabBar(
                  tabs: [
                    Tab(text: Strings.calendarTab),
                    Tab(text: Strings.exercisesTab),
                    Tab(text: Strings.historyTab),
                  ],
                ),
        ),
        body: empty
            ? const EmptyState(
                icon: Symbols.monitoring_rounded,
                title: Strings.progressEmptyTitle,
                body: Strings.progressEmptyBody,
              )
            : const TabBarView(
                children: [_CalendarTab(), _ExercisesTab(), _HistoryTab()],
              ),
      ),
    );
  }
}

/// Opens a workout of a calendar day: directly, or from a short list when
/// there were two.
Future<void> _openDay(
  BuildContext context,
  List<WorkoutSummary> workouts,
) async {
  if (workouts.length == 1) {
    await context.push(Routes.workoutDetail(workouts.single.id));
    return;
  }
  final id = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(
              Strings.workoutsOnDay(DateText.longDay(workouts.first.startedAt)),
              style: context.text.titleLarge,
            ),
          ),
          for (final w in workouts)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              title: Text(w.sessionName),
              subtitle: Text(
                '${DateText.time(w.startedAt)} · '
                '${longDuration(w.durationSeconds)} · '
                '${Strings.setCount(w.setCount)}',
              ),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop(w.id),
            ),
        ],
      ),
    ),
  );
  if (id != null && context.mounted) {
    await context.push(Routes.workoutDetail(id));
  }
}

// ------------------------------------------------------------------ calendar

class _CalendarTab extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(clockProvider)().toLocal();
    final thisMonth = DateTime(today.year, today.month);
    final month = _month ?? thisMonth;
    final summaries =
        ref.watch(workoutSummariesProvider).value ?? const <WorkoutSummary>[];
    final target = ref.watch(currentSettingsProvider).weeklyTarget;
    final streak = ref.watch(streakProvider);
    final byDay = <DateTime, List<WorkoutSummary>>{};
    for (final w in summaries.reversed) {
      final local = w.startedAt.toLocal();
      byDay
          .putIfAbsent(DateTime(local.year, local.month, local.day), () => [])
          .add(w);
    }
    final weeks = CalendarRule.weeks(
      month,
      workoutDates: [for (final w in summaries) w.startedAt.toLocal()],
      weeklyTarget: target,
      today: today,
    );
    final totals = StatsRule.ofMonth(summaries, month);
    final dayStyle = context.text.bodyLarge!.copyWith(
      fontFeatures: AppTheme.tabular,
    );

    Widget weekMark(WeekStatus status) => switch (status) {
      WeekStatus.reached => Icon(
        Symbols.check_circle_rounded,
        fill: 1,
        size: 24,
        color: context.appColors.brand,
        semanticLabel: Strings.weekReached,
      ),
      WeekStatus.missed => Icon(
        Symbols.radio_button_unchecked_rounded,
        size: 22,
        color: colors.outlineVariant,
        semanticLabel: Strings.weekMissed,
      ),
      WeekStatus.current => Icon(
        Symbols.more_horiz_rounded,
        color: colors.onSurfaceVariant,
        semanticLabel: Strings.weekCurrent,
      ),
      WeekStatus.future => const SizedBox.shrink(),
    };

    Widget day(DateTime date) {
      final inMonth = date.month == month.month;
      final workouts = byDay[date] ?? const <WorkoutSummary>[];
      final trained = workouts.isNotEmpty;
      final isToday = date == StreakRule.dayOf(today);
      return Expanded(
        child: SizedBox(
          height: 48,
          child: Center(
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: trained
                  ? () => unawaited(_openDay(context, workouts))
                  : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trained ? colors.primary : null,
                  border: isToday && !trained
                      ? Border.all(color: colors.onSurface, width: 2)
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: dayStyle.copyWith(
                        fontWeight: trained ? FontWeight.w600 : null,
                        color: trained
                            ? colors.onPrimary
                            : inMonth
                            ? colors.onSurface
                            : colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    if (workouts.length > 1)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Text(monthTitle(month), style: context.text.titleLarge),
            ),
            IconButton(
              tooltip: Strings.previousMonth,
              onPressed: () => setState(
                () => _month = DateTime(month.year, month.month - 1),
              ),
              icon: const Icon(Symbols.chevron_left_rounded),
            ),
            IconButton(
              tooltip: Strings.nextMonth,
              onPressed: month == thisMonth
                  ? null
                  : () => setState(
                      () => _month = DateTime(month.year, month.month + 1),
                    ),
              icon: const Icon(Symbols.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: context.text.labelLarge!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: 36,
              child: Icon(
                Symbols.local_fire_department_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final week in weeks)
          Row(
            children: [
              for (final d in week.days) day(d),
              SizedBox(width: 36, child: Center(child: weekMark(week.status))),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            StreakChip(weeks: streak.current, long: true),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                Strings.bestStreak(streak.best),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge!.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                label: Strings.workoutsIn(monthName(month)),
                value: statValue(context, [('${totals.workouts}', null)]),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatTile(
                label: Strings.timeIn(monthName(month)),
                value: statValue(context, durationParts(totals.seconds)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- exercises

class _ExercisesTab extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends ConsumerState<_ExercisesTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(doneExercisesProvider);
    final exercises = ref.watch(exercisesByIdProvider);
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final d in done)
        if (query.isEmpty ||
            (exercises[d.exerciseId]?.name.toLowerCase().contains(query) ??
                false))
          d,
    ];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                SearchField(
                  controller: _search,
                  hint: Strings.searchDone,
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Strings.sortedByLastDone,
                        style: context.text.bodyMedium,
                      ),
                    ),
                    Text(
                      Strings.exerciseCount(shown.length),
                      style: context.text.bodyMedium!.copyWith(
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (shown.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Symbols.search_off_rounded,
              title: query.isEmpty
                  ? Strings.noDoneExercises
                  : Strings.noDoneMatch(_query.trim()),
              body: '',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            sliver: SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) => _DoneExerciseRow(entry: shown[i]),
            ),
          ),
      ],
    );
  }
}

class _DoneExerciseRow extends ConsumerWidget {
  const new({required this.entry});

  final DoneExercise entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets =
        ref.watch(loggedSetsByExerciseProvider)[entry.exerciseId] ?? const [];
    final name = ref.watch(exerciseProvider(entry.exerciseId))?.name ?? '';
    final units = ref.watch(unitLookupProvider);
    final now = ref.watch(clockProvider)();
    final record = headlineBest(sets);
    final when = DateText.relativeDay(entry.lastDone, now);
    final subtitle = record == null
        ? when
        : '${_capitalize(when)} · '
              '${Strings.bestValue(seriesValueText(record.series, record.value, units))}';
    return InkWell(
      onTap: () => context.push(Routes.exerciseProgress(entry.exerciseId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            ExerciseThumb(exerciseId: entry.exerciseId, size: 52),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium!.copyWith(
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Sparkline(values: ChartSeriesBuilder.sparkline(sets)),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

// ------------------------------------------------------------------- history

class _HistoryTab extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries =
        ref.watch(workoutSummariesProvider).value ?? const <WorkoutSummary>[];
    final months = <DateTime, List<WorkoutSummary>>{};
    for (final w in summaries) {
      final local = w.startedAt.toLocal();
      months.putIfAbsent(DateTime(local.year, local.month), () => []).add(w);
    }
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        for (final MapEntry(key: month, value: workouts) in months.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    monthTitle(month),
                    style: context.text.titleSmall!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  Strings.monthTotals(
                    workouts.length,
                    longDuration(
                      workouts.fold(0, (s, w) => s + w.durationSeconds),
                    ),
                  ),
                  style: context.text.titleSmall!.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ],
            ),
          ),
          for (final w in workouts) _HistoryRow(summary: w),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const new({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final local = summary.startedAt.toLocal();
    return InkWell(
      onTap: () => context.push(Routes.workoutDetail(summary.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 52,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${local.day}',
                    style: context.text.titleLarge!.copyWith(
                      height: 1.1,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  Text(
                    DateText.weekdayShort(local).toUpperCase(),
                    style: context.text.labelSmall!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          summary.sessionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium!.copyWith(
                            fontSize: 17,
                          ),
                        ),
                      ),
                      if (summary.recordCount > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        BestCountBadge(count: summary.recordCount),
                      ],
                    ],
                  ),
                  Text(
                    '${longDuration(summary.durationSeconds)} · '
                    '${Strings.setCount(summary.setCount)}',
                    style: context.text.bodyMedium!.copyWith(
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
