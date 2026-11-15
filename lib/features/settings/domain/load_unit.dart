import 'package:freezed_annotation/freezed_annotation.dart';

part 'load_unit.freezed.dart';

/// A unit loads are expressed in (kg, or a custom one such as "level").
/// Units are never converted into each other.
@freezed
abstract class LoadUnit with _$LoadUnit {
  const factory({
    required String id,
    required String name,
    required double step,
    required int decimals,
    @Default(false) bool isBuiltin,
    DateTime? archivedAt,
  }) = _LoadUnit;
  const new _();

  bool get isArchived => archivedAt != null;

  /// [value] with this unit's decimals, without trailing zeros
  /// (40 → "40", 42.5 → "42.5"), using a real minus sign for assisted loads.
  String formatValue(double value) => formatLoadValue(value, decimals);

  /// "42.5 kg".
  String format(double value) => '${formatValue(value)} $name';

  /// [value] moved by [steps] steps and snapped to the step grid.
  double stepBy(double value, int steps) {
    final next = ((value / step).round() + steps) * step;
    final factor = _pow10(decimals.clamp(0, 6) + 2);
    return (next * factor).round() / factor;
  }
}

double _pow10(int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

/// Formats a load with at most [decimals] decimals and no trailing zeros.
String formatLoadValue(double value, int decimals) {
  var text = value.abs().toStringAsFixed(decimals.clamp(0, 6));
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  }
  final isZero = double.parse(text) == 0;
  return value < 0 && !isZero ? '−$text' : text;
}

/// The fields of a custom unit the user edits.
@freezed
abstract class LoadUnitDraft with _$LoadUnitDraft {
  const factory({
    required String name,
    required double step,
    required int decimals,
  }) = _LoadUnitDraft;
  const new _();

  /// Null when valid, otherwise what is wrong.
  String? get error {
    if (name.trim().isEmpty) return 'Name is required';
    if (step <= 0) return 'Step must be greater than 0';
    if (decimals < 0 || decimals > 2) return 'Decimals must be 0, 1 or 2';
    return null;
  }
}
