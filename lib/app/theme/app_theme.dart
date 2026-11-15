import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';

/// Builds the light and dark [ThemeData] from the design tokens.
abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  /// Text style for a type token, e.g. `AppTheme.style('timer')`.
  static TextStyle style(String token) {
    final t = AppTokens.type[token]!;
    return TextStyle(
      fontFamily: t.font,
      fontSize: t.size,
      height: t.lineHeight / t.size,
      fontWeight: FontWeight.values[(t.weight ~/ 100) - 1],
      letterSpacing: t.letterSpacing,
      fontFeatures: t.tabular ? const [FontFeature.tabularFigures()] : null,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Style of a tonal button as designed (primary container).
  static ButtonStyle tonal(ColorScheme colors) => FilledButton.styleFrom(
    backgroundColor: colors.primaryContainer,
    foregroundColor: colors.onPrimaryContainer,
  );

  /// The big countdown (rest timer, timed sets).
  static final TextStyle timer = style('timer');

  /// The app name in the Today app bar.
  static final TextStyle logo = style('logo');

  /// Tabular figures for any number that changes live.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static ColorScheme _scheme(Brightness brightness) {
    final t = brightness == Brightness.light ? AppTokens.light : AppTokens.dark;
    return ColorScheme(
      brightness: brightness,
      primary: t['primary']!,
      onPrimary: t['onPrimary']!,
      primaryContainer: t['primaryContainer'],
      onPrimaryContainer: t['onPrimaryContainer'],
      secondary: t['secondary']!,
      onSecondary: t['onSecondary']!,
      secondaryContainer: t['secondaryContainer'],
      onSecondaryContainer: t['onSecondaryContainer'],
      error: t['error']!,
      onError: t['onError']!,
      errorContainer: t['errorContainer'],
      onErrorContainer: t['onErrorContainer'],
      surface: t['surface']!,
      onSurface: t['onSurface']!,
      onSurfaceVariant: t['onSurfaceVariant'],
      surfaceContainerLowest: t['surfaceContainerLowest'],
      surfaceContainerLow: t['surfaceContainerLow'],
      surfaceContainer: t['surfaceContainer'],
      surfaceContainerHigh: t['surfaceContainerHigh'],
      surfaceContainerHighest: t['surfaceContainerHighest'],
      outline: t['outline'],
      outlineVariant: t['outlineVariant'],
      inverseSurface: t['inverseSurface'],
      onInverseSurface: t['onInverseSurface'],
      inversePrimary: t['inversePrimary'],
      scrim: t['scrim'],
      surfaceTint: Colors.transparent,
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    TextStyle s(String token, [Color? color]) =>
        style(token).copyWith(color: color ?? scheme.onSurface);
    return TextTheme(
      displaySmall: s('displaySmall'),
      headlineLarge: s('headlineLarge'),
      headlineMedium: s('headlineMedium'),
      headlineSmall: s('headlineSmall'),
      titleLarge: s('titleLarge'),
      titleMedium: s('titleMedium'),
      titleSmall: s('titleSmall'),
      bodyLarge: s('bodyLarge'),
      bodyMedium: s('bodyMedium'),
      bodySmall: s('bodySmall', scheme.onSurfaceVariant),
      labelLarge: s('labelLarge'),
      labelMedium: s('labelMedium'),
      labelSmall: s('labelSmall'),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = _scheme(brightness);
    final text = _textTheme(scheme);
    final appColors = brightness == Brightness.light
        ? AppColors.light
        : AppColors.dark;

    const pill = StadiumBorder();
    const buttonSize = Size(64, AppSizes.buttonHeight);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    final buttonText = text.labelLarge;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.ui,
      textTheme: text,
      extensions: [appColors],
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        toolbarHeight: AppSizes.appBarHeight,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // 4 dp padding + 48 dp button, then the title at 56 dp.
        // Tab screens (no back button) set titleSpacing to 16 themselves.
        titleSpacing: AppSpacing.xs,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navBarHeight,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: pill,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      // Note: FilledButton.tonal reads secondaryContainer (yellow here); the
      // design's tonal buttons are primaryContainer: use AppTheme.tonal.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSizes.touchTarget),
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 3,
        highlightElevation: 3,
        extendedPadding: const EdgeInsets.only(left: 16, right: 20),
        extendedIconLabelSpacing: AppSpacing.md,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.outline),
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall,
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 56,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        textStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
    );
  }
}
