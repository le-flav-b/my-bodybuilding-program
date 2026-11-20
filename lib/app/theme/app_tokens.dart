import 'dart:ui';

/// Design tokens, mirrored 1:1 from `design/tokens.json`.
///
/// `test/app/tokens_test.dart` fails if this file and the JSON disagree, so
/// change the JSON first (design decision) and then this file.
abstract final class AppTokens {
  /// `color.light` in tokens.json.
  static const Map<String, Color> light = {
    'primary': Color(0xFFC23E27),
    'onPrimary': Color(0xFFFCFCFC),
    'primaryContainer': Color(0xFFFFDAD2),
    'onPrimaryContainer': Color(0xFF4A1006),
    'secondary': Color(0xFFFFC854),
    'onSecondary': Color(0xFF181B1E),
    'secondaryContainer': Color(0xFFFFEFC7),
    'onSecondaryContainer': Color(0xFF3D2A00),
    'error': Color(0xFFBA1A1A),
    'onError': Color(0xFFFFFFFF),
    'errorContainer': Color(0xFFFFDAD6),
    'onErrorContainer': Color(0xFF410002),
    'surface': Color(0xFFFCFCFC),
    'onSurface': Color(0xFF181B1E),
    'onSurfaceVariant': Color(0xFF5A5F64),
    'surfaceContainerLowest': Color(0xFFFFFFFF),
    'surfaceContainerLow': Color(0xFFF6F6F6),
    'surfaceContainer': Color(0xFFEEEEEE),
    'surfaceContainerHigh': Color(0xFFE6E6E6),
    'surfaceContainerHighest': Color(0xFFDEDFE0),
    'outline': Color(0xFF82878C),
    'outlineVariant': Color(0xFFD3D5D7),
    'inverseSurface': Color(0xFF2D3135),
    'onInverseSurface': Color(0xFFEEEEEE),
    'inversePrimary': Color(0xFFF68974),
    'scrim': Color(0xFF000000),
    'brand': Color(0xFFF55E42),
    'brandLight': Color(0xFFF68974),
    'trophy': Color(0xFFFFC854),
    'trophyText': Color(0xFF8A5A00),
    'success': Color(0xFF2E7D4F),
    'imageWell': Color(0xFFFCFCFC),
    'chart1': Color(0xFFE04A2E),
    'chart2': Color(0xFF2F7BC4),
    'chart3': Color(0xFF7A55C9),
    'chart4': Color(0xFF23885F),
  };

  /// `color.dark` in tokens.json.
  static const Map<String, Color> dark = {
    'primary': Color(0xFFF68974),
    'onPrimary': Color(0xFF181B1E),
    'primaryContainer': Color(0xFF6B2416),
    'onPrimaryContainer': Color(0xFFFFDAD2),
    'secondary': Color(0xFFFFC854),
    'onSecondary': Color(0xFF181B1E),
    'secondaryContainer': Color(0xFF5A4300),
    'onSecondaryContainer': Color(0xFFFFEFC7),
    'error': Color(0xFFFFB4AB),
    'onError': Color(0xFF690005),
    'errorContainer': Color(0xFF93000A),
    'onErrorContainer': Color(0xFFFFDAD6),
    'surface': Color(0xFF181B1E),
    'onSurface': Color(0xFFEEEEEE),
    'onSurfaceVariant': Color(0xFFB4B8BC),
    'surfaceContainerLowest': Color(0xFF121417),
    'surfaceContainerLow': Color(0xFF202327),
    'surfaceContainer': Color(0xFF2D3135),
    'surfaceContainerHigh': Color(0xFF373B40),
    'surfaceContainerHighest': Color(0xFF42464B),
    'outline': Color(0xFF8C9196),
    'outlineVariant': Color(0xFF43474C),
    'inverseSurface': Color(0xFFEEEEEE),
    'onInverseSurface': Color(0xFF2D3135),
    'inversePrimary': Color(0xFFC23E27),
    'scrim': Color(0xFF000000),
    'brand': Color(0xFFF55E42),
    'brandLight': Color(0xFFF68974),
    'trophy': Color(0xFFFFC854),
    'trophyText': Color(0xFFFFC854),
    'success': Color(0xFF6FD49B),
    'imageWell': Color(0xFFFCFCFC),
    'chart1': Color(0xFFF68974),
    'chart2': Color(0xFF6CB4F5),
    'chart3': Color(0xFFB79BF2),
    'chart4': Color(0xFF5FD3A0),
  };

  /// `type` in tokens.json.
  static const Map<String, TypeToken> type = {
    'timer': TypeToken(96, 104, 600, -2, tabular: true),
    'displaySmall': TypeToken(40, 48, 600, -0.5, tabular: true),
    'headlineLarge': TypeToken(32, 40, 700, -0.5),
    'headlineMedium': TypeToken(28, 36, 700, -0.25),
    'headlineSmall': TypeToken(24, 32, 600, 0),
    'titleLarge': TypeToken(22, 28, 600, 0),
    'titleMedium': TypeToken(16, 24, 600, 0.1),
    'titleSmall': TypeToken(14, 20, 600, 0.1),
    'bodyLarge': TypeToken(16, 24, 400, 0.15),
    'bodyMedium': TypeToken(14, 20, 400, 0.2),
    'bodySmall': TypeToken(12, 16, 400, 0.3),
    'labelLarge': TypeToken(14, 20, 600, 0.1),
    'labelMedium': TypeToken(12, 16, 600, 0.4),
    'labelSmall': TypeToken(11, 16, 600, 0.5),
    'logo': TypeToken(22, 28, 700, 0, font: AppFonts.logo),
  };
}

/// One entry of the type scale.
class TypeToken {
  const new(
    this.size,
    this.lineHeight,
    this.weight,
    this.letterSpacing, {
    this.tabular = false,
    this.font = AppFonts.ui,
  });

  final double size;
  final double lineHeight;
  final int weight;
  final double letterSpacing;
  final bool tabular;
  final String font;
}

/// `font` in tokens.json.
abstract final class AppFonts {
  static const String logo = 'Kameron';
  static const String ui = 'Inter';
}

/// `spacing` in tokens.json (4-pt grid).
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const Map<String, double> values = {
    'xxs': xxs,
    'xs': xs,
    'sm': sm,
    'md': md,
    'lg': lg,
    'xl': xl,
    'xxl': xxl,
    'xxxl': xxxl,
  };
}

/// `radius` in tokens.json.
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
  static const double full = 999;

  static const Map<String, double> values = {
    'xs': xs,
    'sm': sm,
    'md': md,
    'lg': lg,
    'xl': xl,
    'full': full,
  };
}

/// `size` in tokens.json.
abstract final class AppSizes {
  static const double touchTarget = 48;
  static const double buttonHeight = 48;
  static const double bigButtonHeight = 64;
  static const double navBarHeight = 80;
  static const double appBarHeight = 64;
  static const double screenWidth = 412;
  static const double screenHeight = 915;
  static const double screenPadding = 16;

  static const Map<String, double> values = {
    'touchTarget': touchTarget,
    'buttonHeight': buttonHeight,
    'bigButtonHeight': bigButtonHeight,
    'navBarHeight': navBarHeight,
    'appBarHeight': appBarHeight,
    'screenWidth': screenWidth,
    'screenHeight': screenHeight,
    'screenPadding': screenPadding,
  };
}
