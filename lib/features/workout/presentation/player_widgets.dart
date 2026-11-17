import 'dart:math' as math;

import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/progress/domain/records.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';

/// "42.5 kg × 10", "16 reps" or "1:20": a record as text.
String recordValueText(
  RecordEvent event,
  UnitLookup units,
) => switch (event.series) {
  LoadSeries(:final unitId) =>
    '${PlanFormat.load(event.value, unitId, units)}'
        '${event.set.reps == null ? '' : ' ${PlanFormat.times} ${event.set.reps}'}',
  RepsSeries() => Strings.repsCount(event.value.round()),
  TimeSeries() => PlanFormat.clock(event.value.round()),
};

/// The record that was beaten, as text ("40 kg", "14", "1:05").
String recordPreviousText(RecordEvent event, UnitLookup units) =>
    switch (event.series) {
      LoadSeries(:final unitId) =>
        PlanFormat.load(event.previous, unitId, units) ?? '',
      RepsSeries() => '${event.previous.round()}',
      TimeSeries() => PlanFormat.clock(event.previous.round()),
    };

String recordTypeLabel(SeriesKey series) => switch (series) {
  LoadSeries() => Strings.heaviestLoad,
  RepsSeries() => Strings.mostReps,
  TimeSeries() => Strings.longestHold,
};

/// The round countdown: a 12-wide track and an arc that drains clockwise
/// from 12 o'clock, with content in the centre.
class TimerRing extends StatelessWidget {
  const new({
    required this.fraction,
    required this.color,
    required this.child,
    this.size = 280,
    super.key,
  });

  /// Part of the ring that is filled, 0 to 1 (null = no arc).
  final double? fraction;
  final Color color;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: (fraction ?? 0).clamp(0, 1)),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            fraction: fraction == null ? null : value,
            color: color,
            track: context.colors.surfaceContainerHigh,
          ),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  new({required this.fraction, required this.color, required this.track});

  final double? fraction;
  final Color color;
  final Color track;

  static const double _stroke = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
    final value = fraction;
    if (value != null && value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// Label, round − and + buttons and a large value. A value that differs
/// from the target turns primary. Long-press the value to type it.
class ValueStepper extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.changed = false,
    this.dim = false,
    this.onLongPress,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  /// The value was changed from the target.
  final bool changed;

  /// "Body": no load.
  final bool dim;
  final VoidCallback? onLongPress;

  /// The unit chip next to the label.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget round(IconData icon, VoidCallback? onPressed, String tooltip) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(48),
            backgroundColor: colors.surfaceContainerHigh,
            foregroundColor: colors.onSurface,
          ),
          icon: Icon(icon),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: context.text.labelSmall!.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              ],
            ),
          ),
          Row(
            children: [
              round(Symbols.remove_rounded, onMinus, '$label −'),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: onLongPress,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      semanticsLabel: '$label $value',
                      style: TextStyle(
                        fontSize: dim ? 22 : 32,
                        height: 40 / 32,
                        fontWeight: FontWeight.w600,
                        color: changed
                            ? colors.primary
                            : dim
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ),
                ),
              ),
              round(Symbols.add_rounded, onPlus, '$label +'),
            ],
          ),
        ],
      ),
    );
  }
}

/// "kg ▾" on the load stepper: picks the unit of the remaining sets.
class UnitChip extends StatelessWidget {
  const new({
    required this.unit,
    required this.units,
    required this.onSelected,
    required this.onManage,
    super.key,
  });

  final LoadUnit? unit;
  final List<LoadUnit> units;
  final ValueChanged<String> onSelected;
  final VoidCallback onManage;

  static const String _manage = '__manage__';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopupMenuButton<String>(
      tooltip: Strings.changeUnit,
      padding: EdgeInsets.zero,
      onSelected: (v) => v == _manage ? onManage() : onSelected(v),
      itemBuilder: (context) => [
        for (final u in units)
          PopupMenuItem(
            value: u.id,
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: u.name,
                      children: [
                        TextSpan(
                          text:
                              '  ${Strings.unitStep(formatLoadValue(u.step, 2))}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (u.id == unit?.id)
                  Icon(Symbols.check_rounded, size: 20, color: colors.primary),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _manage, child: Text(Strings.manageUnits)),
      ],
      child: Container(
        height: 24,
        padding: const EdgeInsets.only(left: 8, right: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unit?.name ?? '',
              style: context.text.labelMedium!.copyWith(height: 1),
            ),
            Icon(
              Symbols.arrow_drop_down_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Yellow pill marking a record ("PR").
class PrChip extends StatelessWidget {
  const new({this.label = Strings.pr, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.appColors.trophy,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Symbols.trophy_rounded,
            size: 14,
            fill: 1,
            color: Color(0xFF181B1E),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.text.labelMedium!.copyWith(
              height: 1,
              color: const Color(0xFF181B1E),
            ),
          ),
        ],
      ),
    );
  }
}
