import 'dart:async';

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
import 'package:my_bodybuilding_program/core/utils/date_text.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/body_weight_providers.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/bodyweight_screen.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/personal_records_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/pr_flows.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_widgets.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// Tab 4: bodyweight, training stats and the latest personal records.
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final streak = ref.watch(streakProvider);
    final now = ref.watch(clockProvider)().toLocal();
    final lastMonth = DateTime(now.year, now.month - 1);
    final prs = PrRule.latest(
      ref.watch(personalRecordsProvider).value ?? const [],
      5,
    );
    final count = NumberFormat.decimalPattern();
    final thisShort = DateFormat('MMM').format(now);
    final lastShort = DateFormat('MMM').format(lastMonth);
    if (ref.watch(weighInRequestProvider)) {
      // Opened from the weigh-in reminder: log a weight right away.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (ref.read(weighInRequestProvider.notifier).take()) {
          unawaited(logWeightFlow(context, ref));
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: const TabTitle(Strings.tabProfile),
        actions: [
          IconButton(
            tooltip: Strings.settings,
            icon: const Icon(Symbols.settings_rounded),
            onPressed: () => context.push(Routes.settings),
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
          const _BodyweightCard(),
          const SizedBox(height: AppSpacing.md),
          _TileRow(
            left: StatTile(
              icon: Symbols.exercise_rounded,
              label: Strings.workoutsTile,
              value: statValue(context, [
                (count.format(stats.total.workouts), null),
              ]),
            ),
            right: StatTile(
              icon: Symbols.schedule_rounded,
              label: Strings.timeTrained,
              value: statValue(context, durationParts(stats.total.seconds)),
            ),
          ),
          _TileRow(
            left: StatTile(
              icon: Symbols.done_all_rounded,
              label: Strings.setsTile,
              value: statValue(context, [
                (count.format(stats.total.sets), null),
              ]),
            ),
            right: StatTile(
              icon: Symbols.local_fire_department_rounded,
              label: Strings.streakBest,
              value: statValue(context, [
                ('${streak.current}', Strings.weeksUnit),
                ('·', null),
                ('${streak.best}', Strings.weeksUnit),
              ]),
            ),
          ),
          _TileRow(
            left: StatTile(
              label: Strings.workoutsMonth(thisShort),
              value: statValue(context, [
                ('${stats.thisMonth.workouts}', null),
              ]),
              footer: _Delta(
                diff: stats.thisMonth.workouts - stats.lastMonth.workouts,
                text: Strings.vsMonth(
                  '${(stats.thisMonth.workouts - stats.lastMonth.workouts).abs()}',
                  lastShort,
                  '${stats.lastMonth.workouts}',
                ),
              ),
            ),
            right: StatTile(
              label: Strings.timeMonth(thisShort),
              value: statValue(context, durationParts(stats.thisMonth.seconds)),
              footer: _Delta(
                diff: stats.thisMonth.seconds - stats.lastMonth.seconds,
                text: Strings.vsMonth(
                  PlanFormat.duration(
                    (stats.thisMonth.seconds - stats.lastMonth.seconds).abs(),
                  ),
                  lastShort,
                  PlanFormat.duration(stats.lastMonth.seconds),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Overline(
            Strings.latestPrs,
            color: context.colors.onSurfaceVariant,
            fontSize: 14,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (prs.isEmpty)
            Text(Strings.noPrsYet, style: context.text.bodyMedium)
          else
            for (final r in prs) _PrRow(record: r),
        ],
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  const new({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: right),
        ],
      ),
    ),
  );
}

/// "↓ 5 vs Oct (12)": green when up, red when down, grey when equal.
class _Delta extends StatelessWidget {
  const new({required this.diff, required this.text});

  final int diff;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = diff > 0
        ? context.appColors.success
        : diff < 0
        ? context.colors.error
        : context.colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            diff > 0
                ? Symbols.arrow_upward_rounded
                : diff < 0
                ? Symbols.arrow_downward_rounded
                : Symbols.arrow_forward_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: context.text.labelLarge!.copyWith(
                  color: color,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyweightCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final entries = ref.watch(bodyWeightsProvider).value ?? const [];
    final latest = BodyWeightTrend.latest(entries);
    final change = BodyWeightTrend.changeOver(entries, days: 7);
    final now = ref.watch(clockProvider)();
    final spark = [
      for (final e in entries.take(10).toList().reversed) e.weightKg,
    ];
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () => context.push(Routes.bodyweight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Overline(
                      latest == null
                          ? Strings.bodyweightTitle
                          : Strings.bodyweightWhen(
                              DateText.relativeDay(latest.measuredAt, now),
                            ),
                      color: colors.onSurfaceVariant,
                    ),
                    if (latest == null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          Strings.noWeighIn,
                          style: context.text.titleLarge,
                        ),
                      )
                    else ...[
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: weightText(latest.weightKg)),
                            TextSpan(
                              text: ' kg',
                              style: context.text.titleLarge!.copyWith(
                                fontWeight: FontWeight.w400,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        style: context.text.headlineLarge!.copyWith(
                          fontSize: 34,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                      if (change != null)
                        Row(
                          children: [
                            Icon(
                              change < 0
                                  ? Symbols.arrow_downward_rounded
                                  : Symbols.arrow_upward_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                Strings.vsLastWeek(weightText(change.abs())),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium!.copyWith(
                                  fontFeatures: AppTheme.tabular,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
              if (spark.length > 1) ...[
                Sparkline(
                  values: spark,
                  width: 96,
                  height: 36,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              SizedBox.square(
                dimension: 56,
                child: IconButton.filled(
                  tooltip: Strings.logWeight,
                  onPressed: () => unawaited(logWeightFlow(context, ref)),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  icon: Icon(
                    Symbols.add_rounded,
                    size: 28,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the latest PRs: trophy, exercise, date, value → its PRs.
class _PrRow extends ConsumerWidget {
  const new({required this.record});

  final PersonalRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitLookupProvider);
    final name = ref.watch(exerciseProvider(record.exerciseId))?.name ?? '';
    return InkWell(
      onTap: () => context.push(Routes.exerciseRecords(record.exerciseId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                color: Color(0xFF181B1E),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM y').format(record.achievedAt.toLocal()),
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              prValueText(record, units),
              style: context.text.titleMedium!.copyWith(
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
