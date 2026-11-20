import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';

/// Trailing "value ›" of a settings tile that opens a dialog.
class ValueChevron extends StatelessWidget {
  const new(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.text.bodyMedium!.copyWith(
            color: color,
            fontFeatures: AppTheme.tabular,
          ),
        ),
        Icon(Symbols.chevron_right_rounded, color: color),
      ],
    );
  }
}
