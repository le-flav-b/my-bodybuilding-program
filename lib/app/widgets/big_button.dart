import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';

/// The one main action of a screen: 64 high, 18 sp (Start, Done, Finish…).
class BigButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tonal = false,
    this.expand = false,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Tonal (primaryContainer) instead of filled.
  final bool tonal;

  /// Take the full available width.
  final bool expand;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: Size(
        expand ? double.infinity : 64,
        AppSizes.bigButtonHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      textStyle: context.text.labelLarge!.copyWith(
        fontSize: 18,
        height: 24 / 18,
      ),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      iconSize: 28,
    );
    final child = Text(label);
    if (icon == null) {
      return tonal
          ? FilledButton.tonal(onPressed: onPressed, style: style, child: child)
          : FilledButton(onPressed: onPressed, style: style, child: child);
    }
    final iconWidget = Icon(icon, fill: 1);
    return tonal
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            style: style,
            icon: iconWidget,
            label: child,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: iconWidget,
            label: child,
          );
  }
}
