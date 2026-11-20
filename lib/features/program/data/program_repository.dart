import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/database_provider.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/program/domain/program.dart';
import 'package:my_bodybuilding_program/features/program/domain/rotation.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'program_repository.g.dart';

/// Plan layer: the single program, its loop of sessions and their plans.
class ProgramRepository {
  new(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  List<ResultSetImplementation<dynamic, dynamic>> get _tables => [
    _db.programs,
    _db.sessions,
    _db.sessionExercises,
    _db.plannedSets,
  ];

  Stream<ProgramOverview> watchOverview() =>
      _db.planDao.watching(_tables, getOverview);

  Future<ProgramOverview> getOverview() async {
    final program = await _db.planDao.program(FixedIds.program);
    final sessions = await _db.planDao.allSessions();
    final exercises = await _db.planDao.exercisesOfSession();
    final sets = await _db.planDao.setsOfExercises([
      for (final e in exercises) e.id,
    ]);
    final plans = [for (final s in sessions) _plan(s, exercises, sets)];
    return ProgramOverview(
      sessions: plans,
      nextSessionId: Rotation.resolve([
        for (final s in sessions) s.id,
      ], program.nextSessionId),
    );
  }

  Stream<SessionPlan?> watchSessionPlan(String sessionId) =>
      _db.planDao.watching(_tables, () => getSessionPlan(sessionId));

  Future<SessionPlan?> getSessionPlan(String sessionId) async {
    final session = await _db.planDao.sessionById(sessionId);
    if (session == null) return null;
    final exercises = await _db.planDao.exercisesOfSession(
      sessionId: sessionId,
    );
    final sets = await _db.planDao.setsOfExercises([
      for (final e in exercises) e.id,
    ]);
    return _plan(session, exercises, sets);
  }

  /// Appends a session to the loop. The first one becomes the next session.
  Future<String> createSession(String name) async {
    final id = _newId();
    final now = _clock();
    await _db.transaction(() async {
      final sessions = await _db.planDao.allSessions();
      await _db.planDao.insertSynced(
        _db.sessions,
        SessionsCompanion(
          id: Value(id),
          programId: const Value(FixedIds.program),
          name: Value(name.trim()),
          position: Value(sessions.length),
        ),
        now,
      );
      if (sessions.isEmpty) await _setPointer(id, now);
    });
    return id;
  }

  Future<void> renameSession(String sessionId, String name) =>
      _db.planDao.patch(
        _db.sessions,
        sessionId,
        SessionsCompanion(name: Value(name.trim())),
        _clock(),
      );

  /// Deletes a session and its plan. Past workouts keep their own copy.
  Future<void> deleteSession(String sessionId) async {
    final now = _clock();
    await _db.transaction(() async {
      final sessions = await _db.planDao.allSessions();
      final ids = [for (final s in sessions) s.id];
      final program = await _db.planDao.program(FixedIds.program);
      final pointer = Rotation.afterDelete(
        ids,
        program.nextSessionId,
        sessionId,
      );
      for (final e in await _db.planDao.exercisesOfSession(
        sessionId: sessionId,
      )) {
        await _db.planDao.softDeleteWhere(
          _db.plannedSets,
          (t) => t.sessionExerciseId.equals(e.id),
          now,
        );
        await _db.planDao.softDelete(_db.sessionExercises, e.id, now);
      }
      await _db.planDao.softDelete(_db.sessions, sessionId, now);
      await _writeOrder([
        for (final id in ids)
          if (id != sessionId) id,
      ], now);
      await _setPointer(pointer, now);
    });
  }

  /// Sets the order of the loop.
  Future<void> reorderSessions(List<String> orderedIds) =>
      _db.transaction(() => _writeOrder(orderedIds, _clock()));

  /// Rewrites the plan of a session (exercises, sets, rest), reusing the
  /// existing rows in order so edits do not pile up deleted rows.
  Future<void> savePlan(String sessionId, List<PlannedExercise> plan) async {
    final now = _clock();
    await _db.transaction(() async {
      final slots = await _db.planDao.sessionExerciseSlots(sessionId);
      for (final (i, exercise) in plan.indexed) {
        final String rowId;
        if (i < slots.length) {
          final slot = slots[i];
          rowId = slot.id;
          final same =
              slot.deletedAt == null &&
              slot.exerciseId == exercise.exerciseId &&
              slot.position == i &&
              slot.restSeconds == exercise.restSeconds;
          if (!same) {
            await _db.planDao.patch(
              _db.sessionExercises,
              slot.id,
              SessionExercisesCompanion(
                exerciseId: Value(exercise.exerciseId),
                position: Value(i),
                restSeconds: Value(exercise.restSeconds),
                deletedAt: const Value(null),
              ),
              now,
            );
          }
        } else {
          rowId = _newId();
          await _db.planDao.insertSynced(
            _db.sessionExercises,
            SessionExercisesCompanion(
              id: Value(rowId),
              sessionId: Value(sessionId),
              exerciseId: Value(exercise.exerciseId),
              position: Value(i),
              restSeconds: Value(exercise.restSeconds),
            ),
            now,
          );
        }
        await _saveSets(rowId, exercise.sets, now);
      }
      for (final slot in slots.skip(plan.length)) {
        if (slot.deletedAt != null) continue;
        await _db.planDao.softDeleteWhere(
          _db.plannedSets,
          (t) => t.sessionExerciseId.equals(slot.id),
          now,
        );
        await _db.planDao.softDelete(_db.sessionExercises, slot.id, now);
      }
    });
  }

  Future<void> _saveSets(
    String sessionExerciseId,
    List<SetTarget> sets,
    DateTime now,
  ) async {
    final slots = await _db.planDao.plannedSetSlots(sessionExerciseId);
    for (final (i, raw) in sets.indexed) {
      final target = raw.normalized(defaultUnitId: FixedIds.kgUnit);
      if (i < slots.length) {
        final slot = slots[i];
        final same =
            slot.deletedAt == null &&
            slot.position == i &&
            slot.targetReps == target.reps &&
            slot.targetSeconds == target.seconds &&
            slot.isMax == target.isMax &&
            slot.load == target.load &&
            slot.unitId == target.unitId;
        if (same) continue;
        await _db.planDao.patch(
          _db.plannedSets,
          slot.id,
          PlannedSetsCompanion(
            position: Value(i),
            targetReps: Value(target.reps),
            targetSeconds: Value(target.seconds),
            isMax: Value(target.isMax),
            load: Value(target.load),
            unitId: Value(target.unitId),
            deletedAt: const Value(null),
          ),
          now,
        );
      } else {
        await _db.planDao.insertSynced(
          _db.plannedSets,
          PlannedSetsCompanion(
            id: Value(_newId()),
            sessionExerciseId: Value(sessionExerciseId),
            position: Value(i),
            targetReps: Value(target.reps),
            targetSeconds: Value(target.seconds),
            isMax: Value(target.isMax),
            load: Value(target.load),
            unitId: Value(target.unitId),
          ),
          now,
        );
      }
    }
    for (final slot in slots.skip(sets.length)) {
      if (slot.deletedAt == null) {
        await _db.planDao.softDelete(_db.plannedSets, slot.id, now);
      }
    }
  }

  /// Makes [sessionId] the next session (also used to undo a skip).
  Future<void> setNextSession(String? sessionId) =>
      _setPointer(sessionId, _clock());

  /// "Skip": moves the pointer to the following session without training.
  /// Returns the session that was skipped, to allow an undo.
  Future<String?> skipNext() => _db.transaction(() async {
    final ids = await _sessionIds();
    final program = await _db.planDao.program(FixedIds.program);
    final skipped = Rotation.resolve(ids, program.nextSessionId);
    await _setPointer(Rotation.afterSkip(ids, program.nextSessionId), _clock());
    return skipped;
  });

  /// Moves the pointer after a finished workout (see [Rotation.afterWorkout]).
  Future<void> advanceAfterWorkout(String? finishedSessionId) =>
      _db.transaction(() async {
        final ids = await _sessionIds();
        final program = await _db.planDao.program(FixedIds.program);
        await _setPointer(
          Rotation.afterWorkout(ids, program.nextSessionId, finishedSessionId),
          _clock(),
        );
      });

  Future<List<String>> _sessionIds() async => [
    for (final s in await _db.planDao.allSessions()) s.id,
  ];

  Future<void> _setPointer(String? sessionId, DateTime now) async {
    final program = await _db.planDao.program(FixedIds.program);
    if (program.nextSessionId == sessionId) return;
    await _db.planDao.patch(
      _db.programs,
      FixedIds.program,
      ProgramsCompanion(nextSessionId: Value(sessionId)),
      now,
    );
  }

  Future<void> _writeOrder(List<String> orderedIds, DateTime now) async {
    final current = {
      for (final s in await _db.planDao.allSessions()) s.id: s.position,
    };
    for (final (i, id) in orderedIds.indexed) {
      if (current[id] == i) continue;
      await _db.planDao.patch(
        _db.sessions,
        id,
        SessionsCompanion(position: Value(i)),
        now,
      );
    }
  }

  SessionPlan _plan(
    SessionRow session,
    List<SessionExerciseRow> exercises,
    List<PlannedSetRow> sets,
  ) => SessionPlan(
    session: Session(
      id: session.id,
      name: session.name,
      position: session.position,
    ),
    exercises: [
      for (final e in exercises)
        if (e.sessionId == session.id)
          SessionExercise(
            id: e.id,
            sessionId: e.sessionId,
            exerciseId: e.exerciseId,
            position: e.position,
            restSeconds: e.restSeconds,
            sets: [
              for (final s in sets)
                if (s.sessionExerciseId == e.id)
                  PlannedSet(
                    id: s.id,
                    position: s.position,
                    target: SetTarget(
                      reps: s.targetReps,
                      seconds: s.targetSeconds,
                      isMax: s.isMax,
                      load: s.load,
                      unitId: s.unitId,
                    ),
                  ),
            ],
          ),
    ],
  );
}

@Riverpod(keepAlive: true)
ProgramRepository programRepository(Ref ref) => ProgramRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
  ref.watch(idGeneratorProvider),
);
