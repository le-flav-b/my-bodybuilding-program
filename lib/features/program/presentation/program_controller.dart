import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'program_controller.g.dart';

/// Actions of the Program tab and the session editor. Every change is
/// written at once: there is no Save button.
class ProgramController {
  new(this._ref);

  final Ref _ref;

  /// Sets a new exercise starts with in a session.
  static const int defaultSetCount = 3;

  ProgramRepository get _program => _ref.read(programRepositoryProvider);

  Future<String> createSession(String name) => _program.createSession(name);

  Future<void> renameSession(String sessionId, String name) async {
    if (name.trim().isEmpty) return;
    await _program.renameSession(sessionId, name);
  }

  Future<void> deleteSession(String sessionId) =>
      _program.deleteSession(sessionId);

  Future<void> reorderSessions(List<String> orderedIds) =>
      _program.reorderSessions(orderedIds);

  Future<void> savePlan(String sessionId, List<PlannedExercise> plan) =>
      _program.savePlan(sessionId, plan);

  /// The plan a newly added exercise starts with: three sets at the default
  /// target and the default rest time from Settings.
  Future<PlannedExercise> defaultPlanFor(Exercise exercise) async {
    final settings = await _ref.read(settingsRepositoryProvider).getSettings();
    return PlannedExercise(
      exerciseId: exercise.id,
      restSeconds: settings.defaultRestSeconds,
      sets: List.filled(
        defaultSetCount,
        exercise.measure == Measure.reps
            ? SetTarget.defaultReps
            : SetTarget.defaultTime,
      ),
    );
  }

  /// "Skip": returns the skipped session id (for Undo).
  Future<String?> skipNext() => _program.skipNext();

  Future<void> setNextSession(String? sessionId) =>
      _program.setNextSession(sessionId);
}

@Riverpod(keepAlive: true)
ProgramController programController(Ref ref) => ProgramController(ref);
