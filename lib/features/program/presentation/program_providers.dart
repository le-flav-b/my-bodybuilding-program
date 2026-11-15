import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/program/domain/estimated_duration.dart';
import 'package:my_bodybuilding_program/features/program/domain/program.dart';
import 'package:my_bodybuilding_program/features/progress/domain/stats.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/history_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'program_providers.g.dart';

/// The loop of sessions with their plans and the next session.
@Riverpod(keepAlive: true)
Stream<ProgramOverview> programOverview(Ref ref) =>
    ref.watch(programRepositoryProvider).watchOverview();

/// One session with its plan (null once deleted).
@riverpod
SessionPlan? sessionPlan(Ref ref, String sessionId) =>
    ref.watch(programOverviewProvider).value?.session(sessionId);

/// Estimated duration of each session in seconds, from the plan and the
/// last workouts done from it.
@Riverpod(keepAlive: true)
Map<String, int> sessionEstimates(Ref ref) {
  final overview = ref.watch(programOverviewProvider).value;
  if (overview == null) return const {};
  final past = <String, List<int>>{};
  for (final w
      in ref.watch(workoutSummariesProvider).value ??
          const <WorkoutSummary>[]) {
    final id = w.sessionId;
    if (id != null) past.putIfAbsent(id, () => []).add(w.durationSeconds);
  }
  return {
    for (final plan in overview.sessions)
      plan.session.id: EstimatedDuration.ofSession(
        plan.toPlan(),
        pastDurations: past[plan.session.id] ?? const [],
      ),
  };
}

/// When each session was last done (completed workouts only).
@Riverpod(keepAlive: true)
Map<String, DateTime> sessionLastDone(Ref ref) {
  final result = <String, DateTime>{};
  for (final w
      in ref.watch(workoutSummariesProvider).value ??
          const <WorkoutSummary>[]) {
    final id = w.sessionId;
    if (id == null) continue;
    final current = result[id];
    if (current == null || w.startedAt.isAfter(current)) {
      result[id] = w.startedAt;
    }
  }
  return result;
}
