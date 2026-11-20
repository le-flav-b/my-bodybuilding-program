import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/settings/data/units_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'units_providers.g.dart';

/// Every load unit, archived ones included; `kg` first.
@Riverpod(keepAlive: true)
Stream<List<LoadUnit>> loadUnits(Ref ref) =>
    ref.watch(unitsRepositoryProvider).watchUnits();

@Riverpod(keepAlive: true)
Map<String, LoadUnit> loadUnitsById(Ref ref) => {
  for (final u in ref.watch(loadUnitsProvider).value ?? const <LoadUnit>[])
    u.id: u,
};

/// The units offered when choosing one (archived ones left out).
@Riverpod(keepAlive: true)
List<LoadUnit> activeLoadUnits(Ref ref) => [
  for (final u in ref.watch(loadUnitsProvider).value ?? const <LoadUnit>[])
    if (!u.isArchived) u,
];

/// Looks a unit up by id, for the formatters.
@Riverpod(keepAlive: true)
UnitLookup unitLookup(Ref ref) {
  final units = ref.watch(loadUnitsByIdProvider);
  return (id) => units[id];
}

/// Number of exercises each unit is used in.
@riverpod
Stream<Map<String, int>> unitUsage(Ref ref) =>
    ref.watch(unitsRepositoryProvider).watchUsageByUnit();
