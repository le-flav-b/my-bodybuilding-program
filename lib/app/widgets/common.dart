import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';

/// Small uppercase label above a group ("SESSIONS · LOOP OF 3").
class Overline extends StatelessWidget {
  const new(this.text, {this.color, this.fontSize = 12, super.key});

  final String text;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.text.labelMedium!.copyWith(
        fontSize: fontSize,
        letterSpacing: 0.6,
        color: color ?? context.colors.onSurfaceVariant,
      ),
    );
  }
}

/// Grey line with an info icon ("Loads are never converted between units.").
class InfoLine extends StatelessWidget {
  const new(this.text, {this.icon = Symbols.info_rounded, super.key});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium!.copyWith(
                fontSize: 13,
                height: 18 / 13,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill ("NEXT", "PR").
class PillBadge extends StatelessWidget {
  const new(this.text, {this.background, this.foreground, super.key});

  final String text;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? context.colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall!.copyWith(
          height: 1,
          color: foreground ?? context.colors.onPrimary,
        ),
      ),
    );
  }
}

/// Title of a tab screen (28 sp), as in the design.
class TabTitle extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.text.headlineMedium);
}

/// The pill search field of lists and pickers.
class SearchField extends StatelessWidget {
  const new({
    required this.controller,
    required this.hint,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.text.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: colors.surfaceContainerHigh,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(Symbols.search_rounded, color: colors.onSurfaceVariant),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 52),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .deleteButtonTooltip,
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: _border,
          enabledBorder: _border,
          focusedBorder: _border,
        ),
      ),
    );
  }

  static final OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.full),
    borderSide: BorderSide.none,
  );
}

/// A filter chip as designed: 32 high, outlined; selected = primary
/// container with a check.
class AppFilterChip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: icon != null && !selected
          ? Icon(icon, size: 18, color: colors.onSurfaceVariant)
          : null,
      showCheckmark: true,
      labelStyle: context.text.labelLarge!.copyWith(
        color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
      ),
      side: selected ? BorderSide.none : BorderSide(color: colors.outline),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(vertical: -2),
    );
  }
}
