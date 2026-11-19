import 'dart:math' as math;

/// A "nice" value axis: round bounds and a round step.
class ChartScale {
  const new({required this.min, required this.max, required this.step});

  /// A scale covering [low]..[high] with about [ticks] intervals whose step
  /// is 1, 2, 2.5 or 5 times a power of ten. A flat series gets a band
  /// around its value.
  factory nice(double low, double high, {int ticks = 3}) {
    var lo = math.min(low, high);
    var hi = math.max(low, high);
    if (hi - lo < 1e-9) {
      final pad = lo.abs() < 1e-9 ? 1.0 : lo.abs() * 0.1;
      lo -= pad;
      hi += pad;
    }
    final raw = (hi - lo) / ticks;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final step = [
      1.0,
      2.0,
      2.5,
      5.0,
      10.0,
    ].map((f) => f * magnitude).firstWhere((s) => s >= raw - 1e-9);
    final min = (lo / step).floor() * step;
    var max = (hi / step).ceil() * step;
    if (max - min < step * ticks) max = min + step * ticks;
    return ChartScale(min: min, max: max, step: step);
  }

  final double min;
  final double max;
  final double step;

  /// [value] mapped to 0..1 on this scale.
  double normalize(double value) => (value - min) / (max - min);

  /// The value at [fraction] (0..1) of this scale.
  double valueAt(double fraction) => min + fraction * (max - min);

  /// The tick values, min to max.
  List<double> get ticks => [
    for (var v = min; v <= max + step / 1000; v += step)
      double.parse(v.toStringAsFixed(6)),
  ];

  /// Number of intervals between ticks.
  int get intervals => ((max - min) / step).round();
}
