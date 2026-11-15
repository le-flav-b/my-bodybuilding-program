import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/widgets/big_button.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';

/// Tab 1: what to do now.
class TodayScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Strings.appName,
          style: AppTheme.logo.copyWith(color: context.appColors.brand),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 64),
        child: EmptyState(
          artAsset: 'assets/images/sleep.png',
          title: Strings.todayWelcomeTitle,
          body: Strings.todayWelcomeBody,
          largeTitle: true,
          action: BigButton(
            icon: Symbols.add_rounded,
            label: Strings.todayCreateFirstSession,
            onPressed: () => context.go(Routes.program),
          ),
        ),
      ),
    );
  }
}
