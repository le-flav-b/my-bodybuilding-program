import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';

/// The colour roles of the design that Material 3's [ColorScheme] lacks.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const new({
    required this.brand,
    required this.brandLight,
    required this.trophy,
    required this.trophyText,
    required this.success,
    required this.imageWell,
    required this.chart,
  });

  factory fromTokens(Map<String, Color> t) => AppColors(
    brand: t['brand']!,
    brandLight: t['brandLight']!,
    trophy: t['trophy']!,
    trophyText: t['trophyText']!,
    success: t['success']!,
    imageWell: t['imageWell']!,
    chart: [t['chart1']!, t['chart2']!, t['chart3']!, t['chart4']!],
  );

  static final AppColors light = AppColors.fromTokens(AppTokens.light);
  static final AppColors dark = AppColors.fromTokens(AppTokens.dark);

  /// Coral: logo, rest-timer ring, large graphics. Never behind text.
  final Color brand;
  final Color brandLight;

  /// Yellow fill reserved for records.
  final Color trophy;

  /// Record text on a surface.
  final Color trophyText;
  final Color success;

  /// White tile behind exercise illustrations, in both themes.
  final Color imageWell;

  /// One colour per load unit on charts, in order of first use.
  final List<Color> chart;

  /// Chart colour for the unit at [index]; wraps after the fourth.
  Color chartAt(int index) => chart[index % chart.length];

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandLight,
    Color? trophy,
    Color? trophyText,
    Color? success,
    Color? imageWell,
    List<Color>? chart,
  }) => AppColors(
    brand: brand ?? this.brand,
    brandLight: brandLight ?? this.brandLight,
    trophy: trophy ?? this.trophy,
    trophyText: trophyText ?? this.trophyText,
    success: success ?? this.success,
    imageWell: imageWell ?? this.imageWell,
    chart: chart ?? this.chart,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandLight: Color.lerp(brandLight, other.brandLight, t)!,
      trophy: Color.lerp(trophy, other.trophy, t)!,
      trophyText: Color.lerp(trophyText, other.trophyText, t)!,
      success: Color.lerp(success, other.success, t)!,
      imageWell: Color.lerp(imageWell, other.imageWell, t)!,
      chart: [
        for (var i = 0; i < chart.length; i++)
          Color.lerp(chart[i], other.chart[i], t)!,
      ],
    );
  }
}

/// Shortcuts to the theme from a [BuildContext].
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
