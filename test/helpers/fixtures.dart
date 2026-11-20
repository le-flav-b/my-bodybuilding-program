import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';

const kg = LoadUnit(
  id: 'kg',
  name: 'kg',
  step: 0.5,
  decimals: 1,
  isBuiltin: true,
);
const level = LoadUnit(id: 'level', name: 'level', step: 1, decimals: 0);

LoadUnit? unitLookup(String id) => switch (id) {
  'kg' => kg,
  'level' => level,
  _ => null,
};

var _counter = 0;

/// A logged set on January [day] 2026 at 18:00 UTC, in workout [workout].
LoggedSet logged(
  String workout,
  int day, {
  String exercise = 'bench',
  Measure measure = Measure.reps,
  int? reps,
  int? seconds,
  double? load,
  String? unit,
  int order = 0,
  String? id,
}) {
  final start = DateTime.utc(2026, 1, day, 18);
  return LoggedSet(
    setId: id ?? 'set${_counter++}',
    workoutId: workout,
    workoutStartedAt: start,
    exerciseId: exercise,
    measure: measure,
    completedAt: start.add(Duration(minutes: 5 + order)),
    order: order,
    reps: reps,
    seconds: seconds,
    load: load,
    unitId: load == null ? null : unit ?? 'kg',
  );
}
