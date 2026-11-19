import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/date_text.dart';
import 'package:my_bodybuilding_program/features/profile/data/body_weight_repository.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/body_weight_dialog.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/body_weight_providers.dart';
import 'package:my_bodybuilding_program/features/progress/domain/chart_scale.dart';
import 'package:my_bodybuilding_program/features/progress/domain/chart_series.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_widgets.dart';

/// "78.4".
String weightText(double kg) => kg.toStringAsFixed(1);

/// "−0.6", "+0.1", "0.0".
String signedChange(double change) {
  final text = change.abs().toStringAsFixed(1);
  if (change > 0) return '+$text';
  if (change < 0) return '−$text';
  return text;
}

/// Asks for a new weigh-in (pre-filled with the latest weight) and saves it.
Future<void> logWeightFlow(BuildContext context, WidgetRef ref) async {
  final entries = ref.read(bodyWeightsProvider).value ?? const <BodyWeight>[];
  final result = await showBodyWeightDialog(
    context,
    now: ref.read(clockProvider)(),
    suggestion: BodyWeightTrend.latest(entries)?.weightKg,
  );
  if (result == null) return;
  await ref
      .read(bodyWeightRepositoryProvider)
      .addEntry(
        measuredAt: result.measuredAt,
        weightKg: result.weightKg,
        note: result.note,
      );
}

/// The bodyweight log: latest value, trend chart and every entry.
class BodyweightScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BodyweightScreen> createState() => _BodyweightScreenState();
}

class _BodyweightScreenState extends ConsumerState<BodyweightScreen> {
  ChartRange _range = ChartRange.threeMonths;

  Future<void> _edit(BodyWeight entry) async {
    final result = await showBodyWeightDialog(
      context,
      now: ref.read(clockProvider)(),
      initial: entry,
    );
    if (result == null) return;
    await ref
        .read(bodyWeightRepositoryProvider)
        .updateEntry(
          entry.id,
          measuredAt: result.measuredAt,
          weightKg: result.weightKg,
          note: result.note,
        );
  }

  Future<void> _delete(BodyWeight entry) async {
    final confirmed = await showConfirmDialog(
      context,
      title: Strings.deleteWeighInTitle,
      message:
          '${weightText(entry.weightKg)} kg · '
          '${DateText.mediumDay(entry.measuredAt)}',
      confirmLabel: Strings.delete,
      destructive: true,
    );
    if (confirmed) {
      await ref.read(bodyWeightRepositoryProvider).deleteEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final entries = ref.watch(bodyWeightsProvider).value ?? const [];
    final now = ref.watch(clockProvider)();
    final latest = BodyWeightTrend.latest(entries);
    final change = BodyWeightTrend.changeOver(entries, days: 30);
    final changes = BodyWeightTrend.changes(entries);
    final from = _range.start(now);
    final shown = [
      for (final e in entries.reversed)
        if (from == null || !e.measuredAt.isBefore(from)) e,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.bodyweightTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(logWeightFlow(context, ref)),
        icon: const Icon(Symbols.add_rounded),
        label: const Text(Strings.logWeight),
      ),
      body: latest == null
          ? const EmptyState(
              icon: Symbols.monitor_weight_rounded,
              title: Strings.noWeighIn,
              body: Strings.noWeighInsBody,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                96,
              ),
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: weightText(latest.weightKg)),
                      TextSpan(
                        text: ' kg',
                        style: context.text.headlineSmall!.copyWith(
                          fontWeight: FontWeight.w400,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: AppTheme.style('displaySmall').copyWith(
                    fontSize: 48,
                    height: 56 / 48,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                if (change != null)
                  _ChangeLine(
                    change: change,
                    text: Strings.inDays(weightText(change.abs()), 30),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: shown.length < 2
                            ? Center(
                                child: Text(
                                  Strings.noSetsInRange,
                                  style: context.text.bodyMedium,
                                ),
                              )
                            : _WeightChart(
                                entries: shown,
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
                const SizedBox(height: AppSpacing.sm),
                for (final (i, e) in entries.indexed) ...[
                  if (i > 0) Divider(height: 1, color: colors.outlineVariant),
                  _EntryRow(
                    entry: e,
                    change: changes[e.id],
                    now: now,
                    onEdit: () => unawaited(_edit(e)),
                    onDelete: () => unawaited(_delete(e)),
                  ),
                ],
              ],
            ),
    );
  }
}

/// "↓ 1.2 kg in 30 days" in a neutral colour.
class _ChangeLine extends StatelessWidget {
  const new({required this.change, required this.text});

  final double change;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurfaceVariant;
    return Row(
      children: [
        Icon(
          change < 0
              ? Symbols.arrow_downward_rounded
              : change > 0
              ? Symbols.arrow_upward_rounded
              : Symbols.arrow_forward_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.text.bodyLarge!.copyWith(
            color: color,
            fontFeatures: AppTheme.tabular,
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const new({
    required this.entry,
    required this.change,
    required this.now,
    required this.onEdit,
    required this.onDelete,
  });

  final BodyWeight entry;
  final double? change;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isToday = DateText.daysBetween(entry.measuredAt, now) <= 0;
    final when = isToday
        ? Strings.todayAt(DateText.time(entry.measuredAt))
        : DateFormat('EEE d MMM').format(entry.measuredAt.toLocal());
    final note = entry.note;
    final c = change;
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weightText(entry.weightKg)} kg',
                    style: context.text.titleMedium!.copyWith(
                      fontSize: 17,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  Text(
                    note == null ? when : '$when · $note',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
            if (c != null)
              Text(
                signedChange(c),
                style: context.text.bodyLarge!.copyWith(
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            PopupMenuButton<String>(
              tooltip: Strings.more,
              icon: Icon(
                Symbols.more_vert_rounded,
                color: colors.onSurfaceVariant,
              ),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Symbols.edit_rounded),
                    title: Text(Strings.edit),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Symbols.delete_rounded, color: colors.error),
                    title: Text(
                      Strings.delete,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One primary line, the latest point marked.
class _WeightChart extends StatelessWidget {
  const new({required this.entries, required this.from, required this.now});

  /// Oldest first.
  final List<BodyWeight> entries;
  final DateTime? from;
  final DateTime now;

  static const double _msPerDay = 86400000;

  double _x(DateTime d) => d.millisecondsSinceEpoch / _msPerDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final values = [for (final e in entries) e.weightKg];
    final scale = ChartScale.nice(
      values.reduce((a, b) => a < b ? a : b),
      values.reduce((a, b) => a > b ? a : b),
      ticks: 2,
    );
    var minX = _x(from ?? entries.first.measuredAt);
    final maxX = _x(now);
    if (maxX - minX < 7) minX = maxX - 7;
    final span = maxX - minX;
    final labelStyle = context.text.bodySmall!.copyWith(
      fontFeatures: AppTheme.tabular,
    );
    final dateFormat = DateFormat(span <= 45 ? 'd MMM' : 'MMM');
    return LineChart(
      LineChartData(
        minX: minX - span * 0.03,
        maxX: maxX + span * 0.03,
        minY: scale.min,
        maxY: scale.max,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final e in entries) FlSpot(_x(e.measuredAt), e.weightKg),
            ],
            color: colors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              checkToShowDot: (spot, bar) => spot == bar.spots.last,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 5, color: colors.primary),
            ),
          ),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: scale.step,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colors.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            for (final y in [scale.min, scale.max])
              HorizontalLine(
                y: y,
                color: colors.outlineVariant,
                strokeWidth: 1,
              ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: scale.step,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatWeightTick(value, scale.step),
                  style: labelStyle,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: span / 3,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    dateFormat.format(
                      DateTime.fromMillisecondsSinceEpoch(
                        (value * _msPerDay).round(),
                      ),
                    ),
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.inverseSurface,
            fitInsideHorizontally: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormat('d MMM').format(entries[s.spotIndex].measuredAt.toLocal())}\n'
                  '${weightText(s.y)} kg',
                  context.text.labelLarge!.copyWith(
                    color: colors.onInverseSurface,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "79", "78.5": a tick of the weight axis.
String formatWeightTick(double value, double step) =>
    step >= 1 ? value.round().toString() : value.toStringAsFixed(1);
