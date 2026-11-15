import 'package:drift/drift.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/daos/synced_writes.dart';
import 'package:my_bodybuilding_program/core/db/tables/plan_tables.dart';

part 'plan_dao.g.dart';

/// Queries of the plan layer.
@DriftAccessor(tables: [Programs, Sessions, SessionExercises, PlannedSets])
class PlanDao extends DatabaseAccessor<AppDatabase>
    with _$PlanDaoMixin, SyncedWrites {
  new(super.attachedDatabase);

  Future<ProgramRow> program(String id) =>
      (select(programs)..where((t) => t.id.equals(id))).getSingle();

  /// The sessions of the loop, in order.
  Future<List<SessionRow>> allSessions() =>
      (select(sessions)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  Future<SessionRow?> sessionById(String id) => (select(
    sessions,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// Exercises of one session (or of all), in order.
  Future<List<SessionExerciseRow>> exercisesOfSession({String? sessionId}) =>
      (select(sessionExercises)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  (sessionId == null
                      ? const Constant(true)
                      : t.sessionId.equals(sessionId)),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  /// Every row of a session, deleted ones included (slots to reuse).
  Future<List<SessionExerciseRow>> sessionExerciseSlots(String sessionId) =>
      (select(sessionExercises)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  /// Planned sets of the given session exercises, in order.
  Future<List<PlannedSetRow>> setsOfExercises(
    Iterable<String> sessionExerciseIds,
  ) =>
      (select(plannedSets)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.sessionExerciseId.isIn(sessionExerciseIds),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.position),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  /// Every set row of a session exercise, deleted ones included.
  Future<List<PlannedSetRow>> plannedSetSlots(String sessionExerciseId) =>
      (select(plannedSets)
            ..where((t) => t.sessionExerciseId.equals(sessionExerciseId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  /// Number of planned sets that use each unit.
  Future<Map<String, Set<String>>> exercisesByPlannedUnit() async {
    final query =
        select(plannedSets).join([
          innerJoin(
            sessionExercises,
            sessionExercises.id.equalsExp(plannedSets.sessionExerciseId),
          ),
        ])..where(
          plannedSets.deletedAt.isNull() &
              sessionExercises.deletedAt.isNull() &
              plannedSets.unitId.isNotNull() &
              plannedSets.load.isNotNull(),
        );
    final result = <String, Set<String>>{};
    for (final row in await query.get()) {
      final unitId = row.readTable(plannedSets).unitId!;
      result
          .putIfAbsent(unitId, () => {})
          .add(row.readTable(sessionExercises).exerciseId);
    }
    return result;
  }
}
