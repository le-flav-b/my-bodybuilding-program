import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';

/// Tab 3: calendar, exercise charts and history.
class ProgressScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const TabTitle(Strings.tabProgress)),
      body: const EmptyState(
        icon: Symbols.monitoring_rounded,
        title: Strings.progressEmptyTitle,
        body: Strings.progressEmptyBody,
      ),
    );
  }
}
