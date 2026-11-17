import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_flows.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/workout_providers.dart';

/// The 4-tab scaffold around Today, Program, Progress and Profile. At
/// launch it asks once whether to resume a workout left in progress.
class AppShell extends ConsumerStatefulWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const List<({IconData icon, String label})> _destinations = [
    (icon: Symbols.today_rounded, label: Strings.tabToday),
    (icon: Symbols.fitness_center_rounded, label: Strings.tabProgram),
    (icon: Symbols.monitoring_rounded, label: Strings.tabProgress),
    (icon: Symbols.person_rounded, label: Strings.tabProfile),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_promptResume());
  }

  Future<void> _promptResume() async {
    final prompt = ref.read(resumePromptProvider);
    if (prompt.shown) return;
    prompt.shown = true;
    final detail = await ref.read(activeWorkoutProvider.future);
    if (detail == null || !mounted) return;
    await showResumeDialog(context, ref, detail);
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          // Tapping the active tab again returns to its first screen.
          initialLocation: index == shell.currentIndex,
        ),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.icon, fill: 1, weight: 500),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
