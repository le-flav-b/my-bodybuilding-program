import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';

part 'program.freezed.dart';

/// The single program: an ordered loop of sessions and a "next" pointer.
@freezed
abstract class Program with _$Program {
  const factory({
    required String id,
    required String name,
    String? nextSessionId,
  }) = _Program;
}

/// A session of the loop.
@freezed
abstract class Session with _$Session {
  const factory({
    required String id,
    required String name,
    required int position,
  }) = _Session;
}

/// A planned set row.
@freezed
abstract class PlannedSet with _$PlannedSet {
  const factory({
    required String id,
    required int position,
    required SetTarget target,
  }) = _PlannedSet;
}

/// An exercise of a session with its planned sets and rest time.
@freezed
abstract class SessionExercise with _$SessionExercise {
  const factory({
    required String id,
    required String sessionId,
    required String exerciseId,
    required int position,
    required int restSeconds,
    @Default(<PlannedSet>[]) List<PlannedSet> sets,
  }) = _SessionExercise;
  const new _();

  PlannedExercise toPlan() => PlannedExercise(
    exerciseId: exerciseId,
    restSeconds: restSeconds,
    sets: [for (final s in sets) s.target],
  );
}

/// A session with everything planned in it.
@freezed
abstract class SessionPlan with _$SessionPlan {
  const factory({
    required Session session,
    @Default(<SessionExercise>[]) List<SessionExercise> exercises,
  }) = _SessionPlan;
  const new _();

  List<PlannedExercise> toPlan() => [for (final e in exercises) e.toPlan()];

  int get setCount => exercises.fold(0, (sum, e) => sum + e.sets.length);
}

/// The program as the UI shows it: the loop in order and the next session.
@freezed
abstract class ProgramOverview with _$ProgramOverview {
  const factory({
    @Default(<SessionPlan>[]) List<SessionPlan> sessions,

    /// The resolved "next session" (null when the program is empty).
    String? nextSessionId,
  }) = _ProgramOverview;
  const new _();

  bool get isEmpty => sessions.isEmpty;

  List<String> get sessionIds => [for (final s in sessions) s.session.id];

  SessionPlan? session(String? id) {
    for (final s in sessions) {
      if (s.session.id == id) return s;
    }
    return null;
  }

  SessionPlan? get nextSession => session(nextSessionId);
}
