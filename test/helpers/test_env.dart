import 'package:drift/native.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/db/seed/seed_importer.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/data/catalogue_repository.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/profile/data/body_weight_repository.dart';
import 'package:my_bodybuilding_program/features/program/data/program_repository.dart';
import 'package:my_bodybuilding_program/features/program/domain/set_target.dart';
import 'package:my_bodybuilding_program/features/progress/data/history_repository.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/data/units_repository.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';
import 'package:my_bodybuilding_program/features/workout/domain/workout_draft.dart';

/// A clock tests move by hand.
class FakeClock {
  new([DateTime? start]) : now = start ?? DateTime.utc(2026, 11, 15, 18);

  DateTime now;

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

/// An in-memory database with every repository on top of it.
class TestEnv {
  new({FakeClock? clock}) : clock = clock ?? FakeClock() {
    db = AppDatabase(NativeDatabase.memory(), clock: this.clock.call);
    catalogue = CatalogueRepository(db, this.clock.call, newId);
    units = UnitsRepository(db, this.clock.call, newId);
    settings = SettingsRepository(db, this.clock.call);
    bodyWeights = BodyWeightRepository(db, this.clock.call, newId);
    program = ProgramRepository(db, this.clock.call, newId);
    workouts = WorkoutRepository(db, program, this.clock.call, newId);
    history = HistoryRepository(db);
    seed = SeedImporter(db, this.clock.call, newId);
  }

  final FakeClock clock;
  late final AppDatabase db;
  late final CatalogueRepository catalogue;
  late final UnitsRepository units;
  late final SettingsRepository settings;
  late final BodyWeightRepository bodyWeights;
  late final ProgramRepository program;
  late final WorkoutRepository workouts;
  late final HistoryRepository history;
  late final SeedImporter seed;

  Future<void> close() => db.close();

  /// Adds an exercise to the catalogue and returns its id.
  Future<String> exercise(
    String name, {
    Measure measure = Measure.reps,
    List<String> primary = const [],
  }) => catalogue.createExercise(
    ExerciseDraft(name: name, measure: measure, primaryMuscleIds: primary),
  );

  /// Creates a session with [plan] and returns its id.
  Future<String> session(String name, List<PlannedExercise> plan) async {
    final id = await program.createSession(name);
    await program.savePlan(id, plan);
    return id;
  }

  /// Starts a workout from a session, as the preview does.
  Future<String> startFromSession(String sessionId) async {
    final plan = (await program.getSessionPlan(sessionId))!;
    return await workouts.startWorkout(
      sessionId: sessionId,
      sessionName: plan.session.name,
      planSnapshot: plan.toPlan(),
      exercises: [for (final e in plan.toPlan()) WorkoutDraftExercise(plan: e)],
    );
  }

  /// Logs every remaining set of the workout at its target.
  Future<void> logEverything(String workoutId) async {
    final detail = (await workouts.getWorkout(workoutId))!;
    for (final e in detail.exercises) {
      for (final s in e.sets) {
        if (s.isDone) continue;
        clock.advance(const Duration(minutes: 2));
        await workouts.logSet(
          s.id,
          reps: s.target.reps,
          seconds: s.target.seconds,
          load: s.target.load,
          unitId: s.target.unitId,
        );
      }
    }
  }
}

/// `n` identical sets.
List<SetTarget> sets(int n, SetTarget target) => List.filled(n, target);

const String kgId = FixedIds.kgUnit;
