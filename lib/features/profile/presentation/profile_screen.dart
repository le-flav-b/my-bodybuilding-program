import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';

/// Tab 4: bodyweight, stats and settings.
class ProfileScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TabTitle(Strings.tabProfile),
        actions: [
          IconButton(
            tooltip: Strings.settings,
            icon: const Icon(Symbols.settings_rounded),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: const EmptyState(
        icon: Symbols.person_rounded,
        title: Strings.profileEmptyTitle,
        body: Strings.profileEmptyBody,
      ),
    );
  }
}
