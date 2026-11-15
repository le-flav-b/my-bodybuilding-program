import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/core/images/image_storage.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';

/// The white rounded tile behind exercise illustrations, in both themes.
class ImageWell extends StatelessWidget {
  const new({
    required this.child,
    this.width,
    this.height,
    this.radius = AppRadius.md,
    super.key,
  });

  final Widget child;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isLight = context.theme.brightness == Brightness.light;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appColors.imageWell,
        borderRadius: BorderRadius.circular(radius),
      ),
      foregroundDecoration: isLight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: context.colors.outlineVariant),
            )
          : null,
      child: child,
    );
  }
}

/// Region photos used when an exercise has no image, by the seed key of its
/// first primary muscle (design/README > Images).
abstract final class MusclePlaceholder {
  static const String _chest = 'assets/images/placeholder_chest.png';
  static const String _back = 'assets/images/placeholder_back.png';
  static const String _legs = 'assets/images/placeholder_legs.png';
  static const String _abs = 'assets/images/placeholder_abs.png';

  static const Map<String, String> _bySeedKey = {
    'chest': _chest,
    'triceps': _chest,
    'shoulders': _chest,
    'back': _back,
    'biceps': _back,
    'traps': _back,
    'forearms': _back,
    'lower_back': _back,
    'quads': _legs,
    'hamstrings': _legs,
    'glutes': _legs,
    'calves': _legs,
    'abs': _abs,
  };

  /// The region photo for [muscle], or null (neutral tile) for a muscle the
  /// user added.
  static String? assetFor(Muscle? muscle) => _bySeedKey[muscle?.seedKey];
}

/// The picture of an exercise: bundled illustration, the user's photo, or
/// the placeholder of its first primary muscle.
class ExerciseImageView extends ConsumerWidget {
  const new({required this.exercise, this.labelSize = 9, super.key});

  final Exercise? exercise;

  /// Font size of the muscle label on the placeholder.
  final double labelSize;

  static const List<double> _desaturate = [
    0.685, 0.286, 0.029, 0, 0, //
    0.085, 0.886, 0.029, 0, 0, //
    0.085, 0.286, 0.629, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = exercise?.image;
    switch (image) {
      case SeedImage():
        return Image.asset(
          image.assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _placeholder(context, ref),
        );
      case UserImage():
        final storage = ref.watch(imageStorageProvider).value;
        if (storage == null) return _placeholder(context, ref);
        return Image.file(
          storage.fileOf(image),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => _placeholder(context, ref),
        );
      case null:
        return _placeholder(context, ref);
    }
  }

  Widget _placeholder(BuildContext context, WidgetRef ref) {
    final muscle = ref.watch(musclesByIdProvider)[exercise?.mainMuscleId];
    final asset = MusclePlaceholder.assetFor(muscle);
    if (asset == null) {
      return ColoredBox(
        color: context.colors.surfaceContainerHigh,
        child: Center(
          child: Icon(
            Symbols.exercise_rounded,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.55,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(_desaturate),
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
        ),
        if (muscle != null)
          Positioned(
            left: 4,
            right: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xD9FCFCFC),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  muscle.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: labelSize,
                    height: 12 / 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: const Color(0xFF181B1E),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A square thumbnail of an exercise in an image well.
class ExerciseThumb extends ConsumerWidget {
  const new({
    required this.exerciseId,
    this.size = 64,
    this.radius = AppRadius.md,
    super.key,
  });

  final String exerciseId;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ImageWell(
      width: size,
      height: size,
      radius: radius,
      child: ExerciseImageView(
        exercise: ref.watch(exerciseProvider(exerciseId)),
        labelSize: size >= 64 ? 9 : 8,
      ),
    );
  }
}
