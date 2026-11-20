import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';

import '../helpers/test_env.dart';

void main() {
  late TestEnv env;
  late String bench;
  late String plank;

  setUp(() async {
    env = TestEnv();
    bench = await env.exercise('Bench press');
    plank = await env.exercise('Plank', measure: Measure.time);
  });
  tearDown(() => env.close());

  PersonalRecordDraft draft({
    int day = 1,
    double? load,
    String? unitId = FixedIds.kgUnit,
    int? reps,
    int? seconds,
    String? note,
  }) => PersonalRecordDraft(
    achievedAt: DateTime.utc(2026, 11, day, 18),
    load: load,
    unitId: unitId,
    reps: reps,
    seconds: seconds,
    note: note,
  );

  test('adds, reads back newest first, per exercise', () async {
    await env.records.addRecord(bench, draft(load: 100, note: ' 1RM '));
    await env.records.addRecord(bench, draft(day: 5, load: 90, reps: 5));
    await env.records.addRecord(plank, draft(day: 3, seconds: 95));

    final benchPrs = await env.records.getRecords(exerciseId: bench);
    expect(benchPrs.map((r) => r.reps), [5, null]);
    expect(benchPrs.last.load, 100);
    expect(benchPrs.last.unitId, FixedIds.kgUnit);
    expect(benchPrs.last.note, '1RM');
    expect(benchPrs.last.achievedAt, DateTime.utc(2026, 11, 1, 18));
    final all = await env.records.getRecords();
    expect(all.map((r) => r.exerciseId), [bench, plank, bench]);
  });

  test('stamps the sync columns', () async {
    final id = await env.records.addRecord(bench, draft(reps: 20));
    final row = await (env.db.select(
      env.db.personalRecords,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.id[14], '7');
    expect(row.createdAt, env.clock.now);
    expect(row.dirty, isTrue);
    expect(row.unitId, isNull, reason: 'no load, no unit');
  });

  test('rejects values that do not fit the measure', () async {
    expect(() => env.records.addRecord(bench, draft()), throwsArgumentError);
    expect(
      () => env.records.addRecord(bench, draft(reps: 5, seconds: 30)),
      throwsArgumentError,
    );
    expect(
      () => env.records.addRecord(plank, draft(load: 20)),
      throwsArgumentError,
    );
    expect(await env.records.getRecords(), isEmpty);
  });

  test('edits and soft-deletes', () async {
    final id = await env.records.addRecord(bench, draft(load: 100));
    env.clock.advance(const Duration(hours: 1));
    await env.records.updateRecord(
      id,
      draft(day: 2, load: 102.5, reps: 1, note: 'paused'),
    );
    final edited = (await env.records.getRecord(id))!;
    expect(edited.load, 102.5);
    expect(edited.reps, 1);
    expect(edited.note, 'paused');
    expect(edited.achievedAt, DateTime.utc(2026, 11, 2, 18));

    await env.records.deleteRecord(id);
    expect(await env.records.getRecords(), isEmpty);
    final row = await (env.db.select(
      env.db.personalRecords,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.deletedAt, env.clock.now);
  });

  test('watchRecords follows the table', () async {
    final stream = env.records.watchRecords(exerciseId: bench);
    final seen = <int>[];
    final sub = stream.listen((list) => seen.add(list.length));
    await pumpEventQueue();
    await env.records.addRecord(bench, draft(reps: 12));
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [0, 1]);
  });

  test('never mixes with the training sets', () async {
    await env.records.addRecord(bench, draft(load: 140));
    expect(await env.history.getLoggedSets(), isEmpty);
    expect(await env.history.getWorkoutSummaries(), isEmpty);
  });

  test('an exercise with PRs can only be archived', () async {
    await env.records.addRecord(bench, draft(reps: 30));
    expect(await env.catalogue.exerciseHasHistory(bench), isTrue);
    expect(
      () => env.catalogue.deleteExercise(bench),
      throwsA(isA<InUseException>()),
    );
    expect(await env.catalogue.exerciseHasHistory(plank), isFalse);
  });

  test('a unit used by a PR is in use', () async {
    final level = await env.units.createUnit(
      const LoadUnitDraft(name: 'level', step: 1, decimals: 0),
    );
    await env.records.addRecord(bench, draft(load: 9, unitId: level));
    expect((await env.units.usageByUnit())[level], 1);
    expect(() => env.units.deleteUnit(level), throwsA(isA<InUseException>()));
  });
}
