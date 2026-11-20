import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';

/// "🔥 2 weeks", or a grey "No streak".
class StreakChip extends StatelessWidget {
  const new({required this.weeks, this.long = false, super.key});

  final int weeks;

  /// "2 week streak" instead of "2 weeks" (calendar).
  final bool long;

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
            active
                ? (long
                      ? Strings.streakLong(weeks)
                      : Strings.streakWeeks(weeks))
                : Strings.noStreak,
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
