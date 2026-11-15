import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';

import '../helpers/test_env.dart';

void main() {
  late TestEnv env;
  late String bench;
  late String row;

  setUp(() async {
    env = TestEnv();
    bench = await env.exercise('Bench');
    row = await env.exercise('Row');
  });
  tearDown(() => env.close());

  PlannedExercise planOf(String exercise, {int count = 3, double? load}) =>
      PlannedExercise(
        exerciseId: exercise,
        restSeconds: 90,
        sets: sets(
          count,
          SetTarget(reps: 10, load: load, unitId: load == null ? null : kgId),
        ),
      );

  test('the first session becomes the next one', () async {
    final push = await env.program.createSession('Push');
    final pull = await env.program.createSession('Pull');
    final overview = await env.program.getOverview();
    expect(overview.sessionIds, [push, pull]);
    expect(overview.nextSessionId, push);
    expect(overview.nextSession!.session.name, 'Push');
  });

  test('saves and reads back a plan with per-set targets', () async {
    final push = await env.program.createSession('Push');
    await env.program.savePlan(push, [
      PlannedExercise(
        exerciseId: bench,
        restSeconds: 120,
        sets: const [
          SetTarget(reps: 12, load: 40, unitId: kgId),
          SetTarget(reps: 10, load: 45, unitId: kgId),
          SetTarget(isMax: true),
        ],
      ),
      planOf(row, count: 2),
    ]);
    final plan = (await env.program.getSessionPlan(push))!;
    expect(plan.exercises.map((e) => e.exerciseId), [bench, row]);
    expect(plan.exercises.first.restSeconds, 120);
    expect(plan.exercises.first.sets.map((s) => s.target), const [
      SetTarget(reps: 12, load: 40, unitId: kgId),
      SetTarget(reps: 10, load: 45, unitId: kgId),
      SetTarget(isMax: true),
    ]);
    expect(plan.setCount, 5);
  });

  test('a load without unit is stored in kg; no load has no unit', () async {
    final push = await env.program.createSession('Push');
    await env.program.savePlan(push, [
      PlannedExercise(
        exerciseId: bench,
        restSeconds: 90,
        sets: const [
          SetTarget(reps: 10, load: 20),
          SetTarget(reps: 10, unitId: kgId),
        ],
      ),
    ]);
    final plan = (await env.program.getSessionPlan(push))!;
    expect(plan.exercises.single.sets.map((s) => s.target), const [
      SetTarget(reps: 10, load: 20, unitId: kgId),
      SetTarget.defaultReps,
    ]);
  });

  test('saving again reuses rows instead of piling up deleted ones', () async {
    final push = await env.program.createSession('Push');
    await env.program.savePlan(push, [planOf(bench), planOf(row)]);
    await env.program.savePlan(push, [planOf(row, count: 2)]);
    await env.program.savePlan(push, [
      planOf(row, count: 2),
      planOf(bench, count: 4, load: 40),
    ]);
    final plan = (await env.program.getSessionPlan(push))!;
    expect(plan.exercises.map((e) => e.exerciseId), [row, bench]);
    expect(plan.exercises.map((e) => e.sets.length), [2, 4]);
    expect(await env.db.select(env.db.sessionExercises).get(), hasLength(2));
    expect(await env.db.select(env.db.plannedSets).get(), hasLength(7));
  });

  test('saving an identical plan writes nothing', () async {
    final push = await env.program.createSession('Push');
    await env.program.savePlan(push, [planOf(bench)]);
    env.clock.advance(const Duration(hours: 1));
    await env.program.savePlan(push, [planOf(bench)]);
    final rows = await env.db.select(env.db.plannedSets).get();
    expect(rows.every((r) => r.updatedAt != env.clock.now), isTrue);
  });

  test('rename and reorder sessions', () async {
    final push = await env.program.createSession('Push');
    final pull = await env.program.createSession('Pull');
    final legs = await env.program.createSession('Legs');
    await env.program.renameSession(push, 'Push A');
    await env.program.reorderSessions([legs, push, pull]);
    final overview = await env.program.getOverview();
    expect(overview.sessions.map((s) => s.session.name), [
      'Legs',
      'Push A',
      'Pull',
    ]);
    // The pointer follows the session, not the position.
    expect(overview.nextSessionId, push);
  });

  test('skip moves the pointer and can be undone', () async {
    final push = await env.program.createSession('Push');
    final pull = await env.program.createSession('Pull');
    final skipped = await env.program.skipNext();
    expect(skipped, push);
    expect((await env.program.getOverview()).nextSessionId, pull);
    await env.program.setNextSession(skipped);
    expect((await env.program.getOverview()).nextSessionId, push);
  });

  test('deleting the next session points to the one after it', () async {
    final push = await env.program.createSession('Push');
    final pull = await env.program.createSession('Pull');
    final legs = await env.program.createSession('Legs');
    await env.program.savePlan(push, [planOf(bench)]);
    await env.program.deleteSession(push);
    var overview = await env.program.getOverview();
    expect(overview.sessionIds, [pull, legs]);
    expect(overview.nextSessionId, pull);
    expect(overview.sessions.map((s) => s.session.position), [0, 1]);
    expect(await env.program.getSessionPlan(push), isNull);

    await env.program.deleteSession(pull);
    await env.program.deleteSession(legs);
    overview = await env.program.getOverview();
    expect(overview.isEmpty, isTrue);
    expect(overview.nextSessionId, isNull);
  });

  test('watchOverview emits when the plan changes', () async {
    final counts = <int>[];
    final sub = env.program.watchOverview().listen(
      (o) => counts.add(o.sessions.length),
    );
    await pumpEventQueue();
    await env.program.createSession('Push');
    await pumpEventQueue();
    await sub.cancel();
    expect(counts.first, 0);
    expect(counts.last, 1);
  });
}
