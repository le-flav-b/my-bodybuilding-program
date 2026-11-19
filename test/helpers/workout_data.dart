import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/profile/data/body_weight_repository.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_draft.dart';

import 'demo_data.dart';
import 'test_app.dart';

/// Workouts on top of [DemoData]: a past history (so "last time" and
/// records exist) and Push A in progress at various points.
class WorkoutData {
  new(this.app, this.demo);

  final TestApp app;
  final DemoData demo;

  WorkoutRepository get _workouts =>
      app.container.read(workoutRepositoryProvider);
  ProgramRepository get _program =>
      app.container.read(programRepositoryProvider);

  /// Push A a week ago (bench 10, 10, 9, 8 × 40 kg, dips 14, plank 0:40),
  /// Pull A yesterday. The pointer ends on Push A.
  Future<void> pastWorkouts() async {
    final clock = app.clock;
    final now = clock.now;
    clock.now = now.subtract(const Duration(days: 7));
    final push = await startPush();
    final detail = (await _workouts.getWorkout(push))!;
    const benchReps = [10, 10, 9, 8];
    for (final e in detail.exercises) {
      for (final (i, s) in e.sets.indexed) {
        clock.advance(const Duration(minutes: 1));
        final t = s.target;
        final isBench = e.exerciseId == demo.ex('barbell_bench_press');
        await _workouts.logSet(
          s.id,
          reps: t.seconds != null
              ? null
              : isBench
              ? benchReps[i]
              : t.reps ?? 14,
          seconds: t.seconds == null ? null : 40,
          load: t.load,
          unitId: t.unitId,
          startRest: false,
        );
      }
    }
    clock.advance(const Duration(minutes: 5));
    await _workouts.finish(push);

    clock.now = now.subtract(const Duration(days: 1));
    final pull = await _start(demo.pullId);
    final pullDetail = (await _workouts.getWorkout(pull))!;
    for (final e in pullDetail.exercises) {
      for (final s in e.sets) {
        clock.advance(const Duration(minutes: 1));
        await _workouts.logSet(
          s.id,
          reps: s.target.reps,
          load: s.target.load,
          unitId: s.target.unitId,
          startRest: false,
        );
      }
    }
    await _workouts.finish(pull);
    clock.now = now;
    await _program.setNextSession(demo.pushId);
  }

  /// Twelve weeks of Pull A / Push A / Legs on Mon, Wed and Fri up to
  /// now, with loads going up. Leg curl moves from kg to "level" halfway
  /// (two units on one chart). The pointer ends on Push A.
  Future<void> richHistory({int weeks = 12}) async {
    final clock = app.clock;
    final now = clock.now;
    final sessions = [demo.pullId, demo.pushId, demo.legsId];
    final thisMonday = DateTime.utc(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
      18,
    );
    var n = 0;
    for (var w = 0; w < weeks; w++) {
      final monday = thisMonday.subtract(Duration(days: 7 * (weeks - 1 - w)));
      final p = weeks == 1 ? 1.0 : w / (weeks - 1);
      for (final dayOffset in const [0, 2, 4]) {
        final start = monday.add(Duration(days: dayOffset));
        if (!start.isBefore(now)) continue;
        clock.now = start;
        final id = await _start(sessions[n++ % sessions.length]);
        final detail = (await _workouts.getWorkout(id))!;
        for (final e in detail.exercises) {
          final key = demo.bySeedKey.entries
              .firstWhere((x) => x.value.id == e.exerciseId)
              .key;
          for (final (i, s) in e.sets.indexed) {
            clock.advance(const Duration(minutes: 2));
            final t = s.target;
            var load = t.load;
            var unitId = t.unitId;
            if (key == 'barbell_bench_press') {
              load = 32.5 + ((p * 10) / 2.5).round() * 2.5;
            } else if (key == 'leg_curl') {
              if (w < weeks ~/ 2) {
                load = 30 + w * 2.5;
                unitId = FixedIds.kgUnit;
              } else {
                load = 5.0 + (w - weeks ~/ 2) ~/ 2;
                unitId = demo.levelUnitId;
              }
            } else if (load != null) {
              load = load + (p * 4).round();
            }
            await _workouts.logSet(
              s.id,
              reps: t.seconds != null
                  ? null
                  : t.isMax
                  ? 10 + w ~/ 3
                  : (t.reps ?? 10) - (i == e.sets.length - 1 ? 1 : 0),
              seconds: t.seconds == null ? null : 30 + w * 3,
              load: load,
              unitId: load == null ? null : unitId,
              startRest: false,
            );
          }
        }
        clock.advance(const Duration(minutes: 5));
        await _workouts.finish(id);
      }
    }
    clock.now = now;
    await _program.setNextSession(demo.pushId);
  }

  /// A weigh-in every 3 days over [days] days, slowly going down
  /// (80.0 → about 78.4 kg).
  Future<void> bodyWeights({int days = 90}) async {
    final repo = app.container.read(bodyWeightRepositoryProvider);
    final now = app.clock.now;
    for (var d = days; d >= 0; d -= 3) {
      final kg = 78.4 + 1.6 * d / days + (d % 9 == 0 ? 0.2 : 0);
      await repo.addEntry(
        measuredAt: now.subtract(Duration(days: d, hours: 11)),
        weightKg: (kg * 10).round() / 10,
        note: d == 3 ? 'after holidays' : null,
      );
    }
  }

  Future<String> startPush() => _start(demo.pushId);

  Future<String> _start(String sessionId) async {
    final plan = (await _program.getSessionPlan(sessionId))!;
    return await _workouts.startWorkout(
      sessionId: sessionId,
      sessionName: plan.session.name,
      planSnapshot: plan.toPlan(),
      exercises: [for (final e in plan.toPlan()) WorkoutDraftExercise(plan: e)],
    );
  }

  Future<WorkoutDetail> detail(String id) async =>
      (await _workouts.getWorkout(id))!;

  /// Logs the first [count] sets of the current exercise as planned.
  Future<void> logFirstSets(String id, int count) async {
    final exercise = (await detail(id)).currentExercise!;
    for (final s in exercise.sets.take(count)) {
      app.clock.advance(const Duration(minutes: 1));
      await _logAsPlanned(s);
    }
  }

  Future<void> _logAsPlanned(WorkoutSet s, {bool rest = false}) =>
      _workouts.logSet(
        s.id,
        reps: s.target.seconds == null ? s.target.reps ?? 12 : null,
        seconds: s.target.seconds,
        load: s.target.load,
        unitId: s.target.unitId,
        startRest: rest,
      );

  Future<String> _id(String id, String seedKey) async {
    final exerciseId = demo.ex(seedKey);
    return (await detail(id)).exercises
        .firstWhere((e) => e.exerciseId == exerciseId)
        .id;
  }

  Future<void> goToPlank(String id) async {
    final plank = await _id(id, 'plank');
    final d = await detail(id);
    await _logAsPlanned(d.exercise(plank)!.sets.first);
    await _workouts.endRest(id);
    await _workouts.setCurrentExercise(id, plank);
  }

  /// Bench and dips done, plank current with one set, leg curl to do,
  /// triceps skipped.
  Future<void> listState(String id) async {
    final d = await detail(id);
    for (final e in d.exercises.take(2)) {
      for (final s in e.sets.where((s) => !s.isDone)) {
        await _logAsPlanned(s);
      }
    }
    await goToPlank(id);
    await _workouts.skipExercise(await _id(id, 'overhead_triceps_extension'));
    await _workouts.setCurrentExercise(id, await _id(id, 'plank'));
  }

  /// [listState] plus a swap (leg curl → leg extension) and a few more
  /// sets, so the summary asks to update the program.
  Future<void> finishState(String id) async {
    await listState(id);
    final catalogue = app.container.read(catalogueRepositoryProvider);
    final extension = (await catalogue.getExercise(demo.ex('leg_extension')))!;
    final legCurl = (await detail(id)).exercise(await _id(id, 'leg_curl'))!;
    await _workouts.swapExercise(legCurl.id, extension.id, [
      for (final s in legCurl.sets) s.target,
    ]);
    final swapped = (await detail(id)).exercise(legCurl.id)!;
    for (final s in swapped.sets.take(2)) {
      await _logAsPlanned(s);
    }
    app.clock.advance(const Duration(minutes: 30));
  }
}
