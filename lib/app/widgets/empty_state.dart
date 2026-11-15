import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';

/// Centered empty state: art or icon, title, body and an optional action.
class EmptyState extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    this.icon,
    this.artAsset,
    this.action,
    this.largeTitle = false,
    super.key,
  }) : assert(
         icon != null || artAsset != null,
         'An empty state needs an icon or an art asset',
       );

  final String title;
  final String body;

  /// Shown in a 96 circle when there is no [artAsset].
  final IconData? icon;

  /// Illustration shown on a 200 round tile.
  final String? artAsset;

  /// Usually a button.
  final Widget? action;

  /// 24 sp title (first-launch welcome) instead of 20 sp.
  final bool largeTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLight = context.theme.brightness == Brightness.light;
    final Widget visual;
    if (artAsset != null) {
      visual = Container(
        width: 200,
        height: 200,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // A light tile in both themes so dark outlines stay readable.
          color: isLight
              ? colors.surfaceContainerLow
              : context.appColors.imageWell,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Image.asset(artAsset!, fit: BoxFit.contain),
      );
    } else {
      visual = Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceContainer,
        ),
        child: Icon(icon, size: 40, color: colors.onSurfaceVariant),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            visual,
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: largeTitle
                  ? context.text.headlineSmall
                  : context.text.titleLarge!.copyWith(
                      fontSize: 20,
                      height: 28 / 20,
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
