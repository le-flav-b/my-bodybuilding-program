import 'package:go_router/go_router.dart';
import 'package:my_bodybuilding_program/app/app_shell.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_screen.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/exercise_detail_screen.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/exercise_edit_screen.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/profile_screen.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_screen.dart';
import 'package:my_bodybuilding_program/features/program/presentation/session_editor_screen.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_screen.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/load_units_screen.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/muscles_screen.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_screen.dart';
import 'package:my_bodybuilding_program/features/today/presentation/today_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// Route locations. Screens navigate with these, never with raw strings.
abstract final class Routes {
  // Tabs
  static const String today = '/today';
  static const String program = '/program';
  static const String progress = '/progress';
  static const String profile = '/profile';

  // Full-screen routes, above the tabs
  static const String exercises = '/exercises';
  static String newExercise({String name = ''}) => name.isEmpty
      ? '/exercises/new'
      : '/exercises/new?name=${Uri.encodeQueryComponent(name)}';
  static String exercise(String id) => '/exercises/$id';
  static String editExercise(String id) => '/exercises/$id/edit';
  static String session(String id) => '/sessions/$id';
  static const String settings = '/settings';
  static const String loadUnits = '/settings/units';
  static const String muscles = '/settings/muscles';
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    initialLocation: Routes.today,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.program,
                builder: (context, state) => const ProgramScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.progress,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.exercises,
        builder: (context, state) => const CatalogueScreen(),
      ),
      GoRoute(
        path: '/exercises/new',
        builder: (context, state) =>
            ExerciseEditScreen(initialName: state.uri.queryParameters['name']),
      ),
      GoRoute(
        path: '/exercises/:id',
        builder: (context, state) =>
            ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/exercises/:id/edit',
        builder: (context, state) =>
            ExerciseEditScreen(exerciseId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/sessions/:id',
        builder: (context, state) =>
            SessionEditorScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.loadUnits,
        builder: (context, state) => const LoadUnitsScreen(),
      ),
      GoRoute(
        path: Routes.muscles,
        builder: (context, state) => const MusclesScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
