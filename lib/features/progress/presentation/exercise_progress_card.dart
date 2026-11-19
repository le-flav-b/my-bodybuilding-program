import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/progress/domain/chart_series.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_widgets.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// The link from an exercise to its progress: best, workout count and a
/// sparkline. Hidden while the exercise has no history.
class ExerciseProgressCard extends ConsumerWidget {
  const new({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(loggedSetsByExerciseProvider)[exerciseId];
    final record = sets == null ? null : headlineRecord(sets);
    if (sets == null || record == null) return const SizedBox.shrink();
    final colors = context.colors;
    final units = ref.watch(unitLookupProvider);
    final workouts = {for (final s in sets) s.workoutId}.length;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(Routes.exerciseProgress(exerciseId)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Symbols.monitoring_rounded, color: colors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Strings.seeProgress, style: context.text.titleMedium),
                    Text(
                      Strings.progressLink(
                        Strings.bestValue(
                          seriesValueText(record.series, record.value, units),
                        ),
                        workouts,
                      ),
                      style: context.text.bodyMedium!.copyWith(
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              Sparkline(
                values: ChartSeriesBuilder.sparkline(sets),
                color: context.appColors.chartAt(0),
              ),
              const SizedBox(width: AppSpacing.sm),
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
