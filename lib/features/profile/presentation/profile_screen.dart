import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';

/// Tab 4: bodyweight, stats and settings.
class ProfileScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.tabProfile)),
      body: const EmptyState(
        icon: Symbols.person_rounded,
        title: Strings.profileEmptyTitle,
        body: Strings.profileEmptyBody,
      ),
    );
  }
}
