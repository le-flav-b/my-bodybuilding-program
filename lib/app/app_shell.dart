import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';

/// The 4-tab scaffold around Today, Program, Progress and Profile.
class AppShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<({IconData icon, String label})> _destinations = [
    (icon: Symbols.today_rounded, label: Strings.tabToday),
    (icon: Symbols.fitness_center_rounded, label: Strings.tabProgram),
    (icon: Symbols.monitoring_rounded, label: Strings.tabProgress),
    (icon: Symbols.person_rounded, label: Strings.tabProfile),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab again returns to its first screen.
          initialLocation: index == navigationShell.currentIndex,
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
