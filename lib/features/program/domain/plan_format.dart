import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';

/// Looks a unit up by id (null when unknown).
typedef UnitLookup = LoadUnit? Function(String unitId);

/// Text forms of sets, loads and durations shared by the whole app.
abstract final class PlanFormat {
  static const String max = 'max';
  static const String bodyweight = 'Body';
  static const String times = '×';
  static const String dot = '·';

  /// "0:45", "1:30", "12:05"; hours appear only when needed ("1:02:03").
  static String clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$sec';
    return '$m:$sec';
  }

  /// "52 min", "1 h 05".
  static String duration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
  }

  /// The reps/time part of a target: "10", "0:45" or "max".
  static String goal(SetTarget target) {
    if (target.isMax) return max;
    if (target.seconds case final s?) return clock(s);
    if (target.reps case final r?) return '$r';
    return max;
  }

  /// A load with its unit ("42.5 kg", "−10 kg", "5 level"), or null when
  /// there is no load.
  static String? load(double? value, String? unitId, UnitLookup units) {
    if (value == null) return null;
    final unit = unitId == null ? null : units(unitId);
    if (unit == null) return formatLoadValue(value, 2);
    return unit.format(value);
  }

  /// A logged or planned set: "10 × 40 kg", "12" (bodyweight), "0:45",
  /// "0:45 · 10 kg".
  static String set({
    required int? reps,
    required int? seconds,
    required double? loadValue,
    required String? unitId,
    required UnitLookup units,
    bool isMax = false,
  }) {
    final value = goal(SetTarget(reps: reps, seconds: seconds, isMax: isMax));
    final loadText = load(loadValue, unitId, units);
    if (loadText == null) return value;
    return seconds != null && reps == null
        ? '$value $dot $loadText'
        : '$value $times $loadText';
  }

  /// One-line summary of the planned sets of an exercise:
  /// "4 × 10 · 40 kg", pyramid "12, 10, 8 · 5–7 level", "3 × 0:45",
  /// "3 × max".
  static String summary(List<SetTarget> sets, UnitLookup units) {
    if (sets.isEmpty) return 'No sets';
    final goals = [for (final s in sets) goal(s)];
    final sameGoal = goals.toSet().length == 1;
    final goalText = sameGoal
        ? '${sets.length} $times ${goals.first}'
        : goals.join(', ');
    final loadText = _loads(sets, units);
    return loadText == null ? goalText : '$goalText $dot $loadText';
  }

  static String? _loads(List<SetTarget> sets, UnitLookup units) {
    final loaded = [
      for (final s in sets)
        if (s.load != null) s,
    ];
    if (loaded.isEmpty) return null;
    final unitIds = {for (final s in loaded) s.unitId};
    if (unitIds.length > 1) {
      // Several units in one exercise: list each set.
      return [for (final s in loaded) load(s.load, s.unitId, units)].join(', ');
    }
    final unitId = unitIds.single;
    final values = [for (final s in loaded) s.load!];
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    if (low == high) return load(low, unitId, units);
    final unit = unitId == null ? null : units(unitId);
    final decimals = unit?.decimals ?? 2;
    final range =
        '${formatLoadValue(low, decimals)}–${formatLoadValue(high, decimals)}';
    return unit == null ? range : '$range ${unit.name}';
  }
}
