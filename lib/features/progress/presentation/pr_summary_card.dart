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
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/personal_records_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/pr_flows.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// An exercise's current best PR (or "No PR yet") with an Add PR button;
/// tap → its Personal records screen. Shown on Exercise detail and
/// Exercise progress.
class PrSummaryCard extends ConsumerWidget {
  const new({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseProvider(exerciseId));
    if (exercise == null) return const SizedBox.shrink();
    final records = ref.watch(exercisePersonalRecordsProvider(exerciseId));
    final best = PrRule.currentBest(records, exercise.measure);
    final units = ref.watch(unitLookupProvider);
    final colors = context.colors;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(Routes.exerciseRecords(exerciseId)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: best == null
                      ? colors.surfaceContainerHigh
                      : context.appColors.trophy,
                ),
                child: Icon(
                  Symbols.trophy_rounded,
                  size: 22,
                  fill: 1,
                  color: best == null
                      ? colors.onSurfaceVariant
                      : const Color(0xFF181B1E),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Overline(Strings.personalRecord),
                    if (best == null)
                      Text(Strings.noPrYet, style: context.text.titleMedium)
                    else ...[
                      Text(
                        prValueText(best, units),
                        style: context.text.titleLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                      Text(
                        [
                          DateFormat('d MMM y')
                              .format(best.achievedAt.toLocal()),
                          if (records.length > 1)
                            Strings.prHistory(records.length),
                        ].join(' · '),
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: Strings.addPr,
                style: AppTheme.tonal(colors),
                onPressed: () => unawaited(addPrFlow(context, ref, exerciseId)),
                icon: const Icon(Symbols.add_rounded),
              ),
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
