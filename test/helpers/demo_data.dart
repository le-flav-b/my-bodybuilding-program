import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/settings/data/units_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';

/// A small program on top of the shipped catalogue, close to the design's
/// sample data: Pull A → Push A (next) → Legs, with a custom "level" unit.
class DemoData {
  new(this.container);

  final ProviderContainer container;

  late final Map<String, Exercise> bySeedKey;
  late final String levelUnitId;
  late final String pullId;
  late final String pushId;
  late final String legsId;

  String ex(String seedKey) => bySeedKey[seedKey]!.id;

  static PlannedExercise plan(
    String exerciseId,
    List<SetTarget> sets, {
    int rest = 90,
  }) => PlannedExercise(exerciseId: exerciseId, restSeconds: rest, sets: sets);

  static List<SetTarget> straight(
    int count, {
    int? reps,
    int? seconds,
    double? load,
    String unitId = FixedIds.kgUnit,
  }) => List.filled(
    count,
    SetTarget(
      reps: reps,
      seconds: seconds,
      load: load,
      unitId: load == null ? null : unitId,
    ),
  );

  /// Requires the seed to be imported (the app bootstrap does it).
  Future<void> create() async {
    final catalogue = container.read(catalogueRepositoryProvider);
    final program = container.read(programRepositoryProvider);
    final units = container.read(unitsRepositoryProvider);

    bySeedKey = {
      for (final e in await catalogue.getExercises())
        if (e.seedKey != null) e.seedKey!: e,
    };
    levelUnitId = await units.createUnit(
      const LoadUnitDraft(name: 'level', step: 1, decimals: 0),
    );
    await units.createUnit(
      const LoadUnitDraft(name: 'plates', step: 1, decimals: 0),
    );

    pullId = await program.createSession('Pull A');
    pushId = await program.createSession('Push A');
    legsId = await program.createSession('Legs');

    await program.savePlan(pullId, [
      plan(ex('lat_pulldown'), straight(4, reps: 10, load: 50), rest: 120),
      plan(ex('barbell_row'), straight(4, reps: 8, load: 45), rest: 120),
      plan(ex('dumbbell_row'), straight(3, reps: 10, load: 18)),
      plan(ex('reverse_fly'), straight(3, reps: 12, load: 6)),
      plan(ex('barbell_curl'), straight(3, reps: 10, load: 25)),
      plan(ex('hammer_curl'), straight(3, reps: 12, load: 10)),
    ]);
    await program.savePlan(pushId, [
      plan(
        ex('barbell_bench_press'),
        straight(4, reps: 10, load: 40),
        rest: 120,
      ),
      plan(ex('bench_dip'), const [
        SetTarget(reps: 12),
        SetTarget(reps: 10, load: 5, unitId: FixedIds.kgUnit),
        SetTarget(isMax: true),
      ]),
      plan(ex('plank'), straight(3, seconds: 45), rest: 60),
      plan(ex('leg_curl'), [
        SetTarget(reps: 12, load: 5, unitId: levelUnitId),
        SetTarget(reps: 10, load: 6, unitId: levelUnitId),
        SetTarget(reps: 8, load: 7, unitId: levelUnitId),
      ]),
      plan(ex('dumbbell_fly'), straight(3, reps: 12, load: 10)),
      plan(ex('overhead_triceps_extension'), straight(3, reps: 12, load: 15)),
    ]);
    await program.savePlan(legsId, [
      plan(ex('back_squat'), straight(4, reps: 8, load: 70), rest: 150),
      plan(ex('lunge'), straight(3, reps: 12, load: 12)),
      plan(ex('leg_extension'), straight(3, reps: 12, load: 35)),
      plan(
        ex('standing_calf_raise'),
        straight(4, reps: 15, load: 40),
        rest: 60,
      ),
      plan(ex('wall_sit'), straight(3, seconds: 45), rest: 60),
    ]);
    await program.setNextSession(pushId);
    await catalogue.saveNote(
      ex('barbell_bench_press'),
      'Bench 3rd hole, feet flat, grip on the rings.',
    );
  }
}
