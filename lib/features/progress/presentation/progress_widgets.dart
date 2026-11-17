import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/progress/domain/records.dart';

/// "November 2026".
String monthTitle(DateTime month) => DateFormat('MMMM yyyy').format(month);

/// "November".
String monthName(DateTime month) => DateFormat('MMMM').format(month);

/// "6 h 12 min", "47 min".
String longDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} min';
}

/// A record value with its unit: "42.5 kg", "16 reps", "1:20".
String seriesValueText(SeriesKey series, double value, UnitLookup units) =>
    switch (series) {
      LoadSeries(:final unitId) => PlanFormat.load(value, unitId, units) ?? '',
      RepsSeries() => Strings.repsCount(value.round()),
      TimeSeries() => PlanFormat.clock(value.round()),
    };

/// The headline record of an exercise: the record of the series it was
/// done in last ("42.5 kg"), or null when nothing is logged.
PersonalRecord? headlineRecord(List<LoggedSet> sets) {
  if (sets.isEmpty) return null;
  final records = Records.current(sets);
  if (records.isEmpty) return null;
  final lastKey = SeriesKey.of(sets.last)?.$1;
  for (final r in records) {
    if (r.series == lastKey) return r;
  }
  return records.first;
}

/// The small trend line of an exercise (64 × 28 in lists).
class Sparkline extends StatelessWidget {
  const new({
    required this.values,
    this.width = 64,
    this.height = 28,
    this.color,
    super.key,
  });

  final List<double> values;
  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: values.length < 2
        ? null
        : CustomPaint(
            painter: _SparkPainter(
              values,
              color ?? context.appColors.chartAt(0),
            ),
          ),
  );
}

class _SparkPainter extends CustomPainter {
  new(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var low = values.reduce((a, b) => a < b ? a : b);
    var high = values.reduce((a, b) => a > b ? a : b);
    if (high - low < 1e-9) {
      low -= 1;
      high += 1;
    }
    const pad = 2.0;
    final h = size.height - 2 * pad;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = pad + (size.width - 2 * pad) * i / (values.length - 1);
      final y = pad + h - h * (values[i] - low) / (high - low);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.color != color || old.values != values;
}

/// A rounded tile: label (with optional icon) and a big value.
class StatTile extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    this.icon,
    this.footer,
    super.key,
  });

  final String label;

  /// Usually built with [statValue] ("6 h 12 m" with small units).
  final InlineSpan value;
  final IconData? icon;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            value,
            maxLines: 1,
            style: context.text.headlineMedium!.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: AppTheme.tabular,
              color: colors.onSurface,
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}

/// "6 h 12 m" with the units small and grey.
InlineSpan statValue(BuildContext context, List<(String, String?)> parts) {
  final unitStyle = context.text.titleMedium!.copyWith(
    fontWeight: FontWeight.w400,
    color: context.colors.onSurfaceVariant,
  );
  return TextSpan(
    children: [
      for (final (i, (value, unit)) in parts.indexed) ...[
        if (i > 0) const TextSpan(text: ' '),
        TextSpan(text: value),
        if (unit != null) TextSpan(text: unit, style: unitStyle),
      ],
    ],
  );
}

/// "6 h 12 m" parts for [seconds].
List<(String, String?)> durationParts(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return [('$minutes', Strings.minutesUnit)];
  return [
    ('${minutes ~/ 60}', Strings.hoursUnit),
    ((minutes % 60).toString().padLeft(2, '0'), Strings.minutesUnit),
  ];
}

/// Yellow pill with a trophy and a count (history rows).
class RecordCountBadge extends StatelessWidget {
  const new({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
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
          size: 16,
          fill: 1,
          color: Color(0xFF181B1E),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: context.text.labelMedium!.copyWith(
            height: 1,
            color: const Color(0xFF181B1E),
            fontFeatures: AppTheme.tabular,
          ),
        ),
      ],
    ),
  );
}
