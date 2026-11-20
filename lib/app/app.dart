import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/bootstrap.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/reminder_runtime.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_providers.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_runtime.dart';

/// Root widget: theme (light/dark from the design tokens) and router.
class App extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    if (!bootstrap.hasValue) {
      // Database not ready yet: a bare themed surface (no data is read).
      return MaterialApp(
        title: Strings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: _StartupScreen(error: bootstrap.error),
      );
    }

    // Follows the workout in progress (notification, rest timer) from now
    // on. Started here, in the app's zone, so its timers are the app's.
    ref
      ..watch(workoutRuntimeProvider)
      // Keeps the training and weigh-in reminders scheduled.
      ..watch(reminderRuntimeProvider);

    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const new({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: error == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${Strings.startupError}\n\n$error',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
              ),
      ),
    );
  }
}
