import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';

/// Tab 2: the loop of sessions and the exercise catalogue.
class ProgramScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.tabProgram)),
      body: const EmptyState(
        icon: Symbols.fitness_center_rounded,
        title: Strings.programEmptyTitle,
        body: Strings.programEmptyBody,
      ),
    );
  }
}
