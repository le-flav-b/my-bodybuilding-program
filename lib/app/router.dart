import 'package:go_router/go_router.dart';
import 'package:my_bodybuilding_program/app/app_shell.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/profile_screen.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_screen.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/progress_screen.dart';
import 'package:my_bodybuilding_program/features/today/presentation/today_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// Route locations. Screens navigate with these, never with raw strings.
abstract final class Routes {
  static const String today = '/today';
  static const String program = '/program';
  static const String progress = '/progress';
  static const String profile = '/profile';
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
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
