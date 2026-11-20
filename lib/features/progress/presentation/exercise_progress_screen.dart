import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/domain/bests.dart';
import 'package:my_bodybuilding_program/features/progress/domain/chart_scale.dart';
import 'package:my_bodybuilding_program/features/progress/domain/chart_series.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/pr_summary_card.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_widgets.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// Name of a series on the chart: the unit, "reps" or "time".
String seriesName(SeriesKey key, UnitLookup units) => switch (key) {
  LoadSeries(:final unitId) => units(unitId)?.name ?? '',
  RepsSeries() => Strings.repsSeries,
  TimeSeries() => Strings.timeSeries,
};

/// One exercise over time: its personal records card, then the training
/// bests per unit, the multi-unit chart and every set grouped by workout.
class ExerciseProgressScreen extends ConsumerStatefulWidget {
  const new({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  ConsumerState<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends ConsumerState<ExerciseProgressScreen> {
  ChartRange _range = ChartRange.threeMonths;
  final Set<SeriesKey> _hidden = {};

  @override
  Widget build(BuildContext context) {
    final exercise = ref.watch(exerciseProvider(widget.exerciseId));
    final sets =
        ref.watch(loggedSetsByExerciseProvider)[widget.exerciseId] ??
        const <LoggedSet>[];
    final units = ref.watch(unitLookupProvider);
    final appColors = context.appColors;
    final now = ref.watch(clockProvider)();

    final all = ChartSeriesBuilder.build(sets);
    final colorOf = {
      for (final (i, s) in all.indexed) s.key: appColors.chartAt(i),
    };
    final records = Bests.current(sets);
    final recordSetIds = {for (final e in Bests.events(sets)) e.setId};
    final from = _range.start(now);
    final visible = [
      for (final s in ChartSeriesBuilder.build(sets, from: from))
        if (!_hidden.contains(s.key) && s.points.isNotEmpty) s,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise?.name ?? ''),
        actions: [
          IconButton(
            tooltip: Strings.exerciseInfo,
            icon: const Icon(Symbols.info_rounded),
            onPressed: () => context.push(Routes.exercise(widget.exerciseId)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          // Personal records first: logged on purpose, kept apart
          // from the training data below.
          PrSummaryCard(exerciseId: widget.exerciseId),
          const SizedBox(height: AppSpacing.xl),
          if (sets.isEmpty)
            const _NotDoneYet()
          else ...[
            Overline(
              Strings.bests,
              color: context.colors.onSurfaceVariant,
              fontSize: 14,
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecordTiles(
              records: [
                for (final s in all)
                  ?records.where((r) => r.series == s.key).firstOrNull,
              ],
              colorOf: colorOf,
            ),
            if (all.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in all)
                    _LegendChip(
                      label: seriesName(s.key, units),
                      color: colorOf[s.key]!,
                      selected: !_hidden.contains(s.key),
                      onTap: () => setState(() {
                        if (_hidden.contains(s.key)) {
                          _hidden.remove(s.key);
                        } else if (_hidden.length < all.length - 1) {
                          _hidden.add(s.key);
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: visible.isEmpty
                        ? Center(
                            child: Text(
                              Strings.noSetsInRange,
                              style: context.text.bodyMedium,
                            ),
                          )
                        : MultiUnitChart(
                            series: visible,
                            colorOf: colorOf,
                            units: units,
                            from: from,
                            now: now,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ChartRangeRow(
                    value: _range,
                    onChanged: (r) => setState(() => _range = r),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _AllSets(sets: sets, colorOf: colorOf, recordSetIds: recordSetIds),
          ],
        ],
      ),
    );
  }
}

/// No training sets yet: the bests and the chart come with the first
/// workout.
class _NotDoneYet extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceContainer,
            ),
            child: Icon(
              Symbols.monitoring_rounded,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(Strings.notDoneYet, style: context.text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              Strings.progressEmptyBody,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium!.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTiles extends ConsumerWidget {
  const new({required this.records, required this.colorOf});

  final List<TrainingBest> records;
  final Map<SeriesKey, Color> colorOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitLookupProvider);
    final colors = context.colors;
    Widget tile(TrainingBest r) {
      final title = switch (r.series) {
        LoadSeries() => Strings.heaviestIn(seriesName(r.series, units)),
        RepsSeries() => Strings.mostRepsTitle,
        TimeSeries() => Strings.longestHoldTitle,
      };
      final date = DateFormat('d MMM').format(r.set.workoutStartedAt.toLocal());
      final detail = switch (r.series) {
        LoadSeries() when r.set.reps != null =>
          '${PlanFormat.times} ${r.set.reps} · $date',
        _ => date,
      };
      return Container(
        decoration: BoxDecoration(
          color: colorOf[r.series],
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg - 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Symbols.trophy_rounded,
                    size: 16,
                    fill: 1,
                    color: context.appColors.trophyText,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  seriesValueText(r.series, r.value, units),
                  style: context.text.headlineSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ),
              Text(
                detail,
                style: context.text.bodyMedium!.copyWith(
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < records.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: tile(records[i])),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: i + 1 < records.length
                    ? tile(records[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _LegendChip extends StatelessWidget {
  const new({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.primaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: selected
            ? BorderSide.none
            : BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : colors.outline,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: context.text.labelLarge!.copyWith(
                  fontSize: 15,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every unit on one timeline: each series on its own scale (normalised to
/// 0..1), the first two visible series own the left and right axes, lines
/// only join points of the same series, records are yellow dots.
class MultiUnitChart extends StatelessWidget {
  const new({
    required this.series,
    required this.colorOf,
    required this.units,
    required this.from,
    required this.now,
    super.key,
  });

  final List<ChartSeries> series;
  final Map<SeriesKey, Color> colorOf;
  final UnitLookup units;
  final DateTime? from;
  final DateTime now;

  static const int _ticks = 3;
  static const double _msPerDay = 86400000;

  double _x(DateTime date) => date.millisecondsSinceEpoch / _msPerDay;

  String _axisLabel(ChartSeries s, double value) => switch (s.key) {
    TimeSeries() => PlanFormat.clock(value.round()),
    LoadSeries(:final unitId) => formatLoadValue(
      value,
      units(unitId)?.decimals ?? 1,
    ),
    RepsSeries() => formatLoadValue(value, 0),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trophy = context.appColors.trophy;
    final scales = {
      for (final s in series)
        s.key: ChartScale.nice(
          s.points.map((p) => p.value).reduce((a, b) => a < b ? a : b),
          s.points.map((p) => p.value).reduce((a, b) => a > b ? a : b),
        ),
    };
    final firstDate = series
        .expand((s) => s.points)
        .map((p) => p.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    var minX = _x(from ?? firstDate);
    var maxX = _x(now);
    if (maxX - minX < 7) minX = maxX - 7;
    final span = maxX - minX;
    minX -= span * 0.03;
    maxX += span * 0.03;
    final left = series.first;
    final right = series.length > 1 ? series[1] : null;
    final labelStyle = context.text.bodySmall!.copyWith(
      fontFeatures: AppTheme.tabular,
    );
    final dateFormat = DateFormat(span <= 45 ? 'd MMM' : 'MMM');

    AxisTitles sideTitles(ChartSeries? s) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: s != null,
        reservedSize: 40,
        interval: 1 / _ticks,
        getTitlesWidget: (value, meta) {
          if (s == null) return const SizedBox.shrink();
          final scale = scales[s.key]!;
          return SideTitleWidget(
            meta: meta,
            child: Text(
              _axisLabel(s, scale.valueAt(value)),
              style: labelStyle.copyWith(color: colorOf[s.key]),
            ),
          );
        },
      ),
    );

    LineChartBarData bar(ChartSeries s) {
      final color = colorOf[s.key]!;
      final scale = scales[s.key]!;
      return LineChartBarData(
        spots: [
          for (final p in s.points)
            FlSpot(_x(p.date), scale.normalize(p.value)),
        ],
        color: color,
        barWidth: 2.5,
        dotData: FlDotData(
          getDotPainter: (spot, percent, barData, index) {
            final record = s.points[index].isRecord;
            return FlDotCirclePainter(
              radius: record ? 6 : 3.5,
              color: record ? trophy : color,
              strokeWidth: record ? 1.5 : 0,
              strokeColor: const Color(0xFF181B1E),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                seriesName(left.key, units),
                style: context.text.labelMedium!.copyWith(
                  color: colorOf[left.key],
                ),
              ),
            ),
            const Spacer(),
            if (right != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  seriesName(right.key, units),
                  style: context.text.labelMedium!.copyWith(
                    color: colorOf[right.key],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              maxY: 1,
              lineBarsData: [for (final s in series) bar(s)],
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 1 / _ticks,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: colors.outlineVariant, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  for (final y in const [0.0, 1.0])
                    HorizontalLine(
                      y: y,
                      color: colors.outlineVariant,
                      strokeWidth: 1,
                    ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                leftTitles: sideTitles(left),
                rightTitles: sideTitles(right),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (maxX - minX) / 4,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        (value * _msPerDay).round(),
                      );
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(dateFormat.format(date), style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                getTouchedSpotIndicator: (barData, indexes) => [
                  for (final _ in indexes)
                    TouchedSpotIndicatorData(
                      FlLine(
                        color: colors.onSurfaceVariant,
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                      const FlDotData(),
                    ),
                ],
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => colors.inverseSurface,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => [
                    for (final (i, spot) in spots.indexed)
                      _tooltip(context, series[spot.barIndex], spot, i == 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  LineTooltipItem _tooltip(
    BuildContext context,
    ChartSeries s,
    LineBarSpot spot,
    bool first,
  ) {
    final colors = context.colors;
    final point = s.points[spot.spotIndex];
    final set = point.bestSet;
    final value = PlanFormat.set(
      reps: set.reps,
      seconds: set.seconds,
      loadValue: set.load,
      unitId: set.unitId,
      units: units,
    );
    final date = DateFormat('d MMM').format(point.date.toLocal());
    return LineTooltipItem(
      first ? '$date\n' : '',
      context.text.labelMedium!.copyWith(color: colors.onInverseSurface),
      textAlign: TextAlign.left,
      children: [
        TextSpan(
          text: value,
          style: context.text.labelLarge!.copyWith(
            color: colors.onInverseSurface,
            fontFeatures: AppTheme.tabular,
          ),
        ),
        if (point.isRecord)
          TextSpan(
            text: '  ${Strings.best}',
            style: context.text.labelLarge!.copyWith(
              color: context.appColors.trophy,
            ),
          ),
      ],
    );
  }
}

class _AllSets extends ConsumerWidget {
  const new({
    required this.sets,
    required this.colorOf,
    required this.recordSetIds,
  });

  final List<LoggedSet> sets;
  final Map<SeriesKey, Color> colorOf;
  final Set<String> recordSetIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(unitLookupProvider);
    final byWorkout = <String, List<LoggedSet>>{};
    for (final s in sets.reversed) {
      byWorkout.putIfAbsent(s.workoutId, () => []).add(s);
    }
    final dateFormat = DateFormat('EEE d MMM');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Overline(
          Strings.allSets(byWorkout.length),
          color: colors.onSurfaceVariant,
          fontSize: 14,
        ),
        for (final (i, workoutSets) in byWorkout.values.indexed) ...[
          if (i > 0) Divider(height: 1, color: colors.outlineVariant),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.push(
                    Routes.workoutDetail(workoutSets.first.workoutId),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateFormat.format(
                            workoutSets.first.workoutStartedAt.toLocal(),
                          ),
                          style: context.text.titleMedium,
                        ),
                      ),
                      Text(
                        workoutSets.first.sessionName,
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final s in workoutSets.reversed)
                      _SetPill(
                        text: _setText(s, units),
                        color: colorOf[SeriesKey.of(s)?.$1] ?? colors.outline,
                        record: recordSetIds.contains(s.setId),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// "12 × 7" (unit shown by the dot colour), "16", "0:45".
  String _setText(LoggedSet s, UnitLookup units) {
    final goal = s.seconds != null && s.reps == null
        ? PlanFormat.clock(s.seconds!)
        : '${s.reps ?? 0}';
    final load = s.load;
    if (load == null) return goal;
    final value = formatLoadValue(load, units(s.unitId ?? '')?.decimals ?? 2);
    return s.seconds != null && s.reps == null
        ? '$goal · $value'
        : '$goal ${PlanFormat.times} $value';
  }
}

class _SetPill extends StatelessWidget {
  const new({required this.text, required this.color, required this.record});

  final String text;
  final Color color;
  final bool record;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: record ? colors.secondaryContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: context.text.bodyLarge!.copyWith(
              color: record ? colors.onSecondaryContainer : colors.onSurface,
              fontFeatures: AppTheme.tabular,
            ),
          ),
          if (record) ...[
            const SizedBox(width: 6),
            Icon(
              Symbols.trophy_rounded,
              size: 16,
              fill: 1,
              color: colors.onSecondaryContainer,
            ),
          ],
        ],
      ),
    );
  }
}
