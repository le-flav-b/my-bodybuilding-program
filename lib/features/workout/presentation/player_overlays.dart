import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/big_button.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/domain/bests.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_clock.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_rest_view.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_widgets.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_controller.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// Over the player while paused: the frozen clock, what's next, Resume,
/// Finish and Discard.
class PausedOverlay extends ConsumerWidget {
  const new({required this.detail, super.key});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final workout = detail.workout;
    final elapsed = WorkoutClock.elapsedSeconds(
      workout,
      ref.watch(nowProvider),
    );
    final next = nextUp(detail);
    final nextName = next == null
        ? null
        : ref.watch(exerciseProvider(next.$1.exerciseId))?.name;
    final explanation = [
      Strings.pausedExplanation,
      if (next != null && nextName != null)
        Strings.nextIs(
          Strings.exerciseSetOf(
            nextName,
            next.$1.sets.indexOf(next.$2) + 1,
            next.$1.sets.length,
          ),
        ),
    ].join('\n');
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: ColoredBox(
            color: colors.surface.withValues(alpha: 0.85),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surfaceContainerHigh,
                        ),
                        child: Icon(
                          Symbols.pause_rounded,
                          size: 48,
                          fill: 1,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Overline(
                        Strings.paused,
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      Text(
                        PlanFormat.clock(elapsed),
                        style: AppTheme.timer.copyWith(
                          fontSize: 72,
                          height: 80 / 72,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        explanation,
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge!.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: 240,
                        child: BigButton(
                          expand: true,
                          icon: Symbols.play_arrow_rounded,
                          label: Strings.resume,
                          onPressed: () => unawaited(
                            ref
                                .read(workoutControllerProvider)
                                .resume(workout.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => unawaited(
                              finishWorkoutFlow(context, ref, workout.id),
                            ),
                            icon: const Icon(Symbols.flag_rounded),
                            label: const Text(Strings.finish),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: colors.error,
                            ),
                            onPressed: () => unawaited(
                              confirmDiscardFlow(context, ref, workout.id),
                            ),
                            child: const Text(Strings.discard),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "NEW RECORD": the trophy over everything. Closes on tap, on Nice! or
/// after 4 s; the rest keeps running (strip at the bottom).
class TrophyOverlay extends ConsumerWidget {
  const new({
    required this.event,
    required this.detail,
    required this.onClose,
    super.key,
  });

  final BestEvent event;
  final WorkoutDetail detail;
  final VoidCallback onClose;

  static const Color _scrim = Color(0xFA080A0C);
  static const Color _ink = Color(0xFF181B1E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trophy = context.appColors.trophy;
    final units = ref.watch(unitLookupProvider);
    final name = ref.watch(exerciseProvider(event.exerciseId))?.name ?? '';
    final remaining = WorkoutClock.restRemainingSeconds(
      detail.workout,
      ref.watch(nowProvider),
    );
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: ColoredBox(
          color: _scrim,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/trophy.png', width: 260),
                          const SizedBox(height: AppSpacing.lg),
                          Overline(
                            Strings.newBest,
                            color: trophy,
                            fontSize: 16,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              recordValueText(event, units),
                              style: const TextStyle(
                                fontSize: 40,
                                height: 48 / 40,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFeatures: AppTheme.tabular,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '$name ${PlanFormat.dot} '
                            '${recordTypeLabel(event.series)}',
                            textAlign: TextAlign.center,
                            style: context.text.titleMedium!.copyWith(
                              fontWeight: FontWeight.w400,
                              fontSize: 17,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            Strings.previousBest(
                              recordPreviousText(event, units),
                            ),
                            style: context.text.bodyMedium!.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: 220,
                            child: BigButton(
                              expand: true,
                              label: Strings.nice,
                              backgroundColor: trophy,
                              foregroundColor: _ink,
                              onPressed: onClose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (detail.workout.isResting)
                  Container(
                    margin: const EdgeInsets.all(AppSpacing.lg),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1F22),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Symbols.timer_rounded,
                          color: context.appColors.brand,
                        ),
                        const Expanded(
                          child: Text(
                            Strings.restRunning,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        Text(
                          PlanFormat.clock(remaining),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
