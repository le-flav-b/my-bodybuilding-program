import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/big_button.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_providers.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_screen.dart';

/// Tab 1: what to do now.
class TodayScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(programOverviewProvider).value;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Text(
          Strings.appName,
          style: AppTheme.logo.copyWith(color: context.appColors.brand),
        ),
      ),
      body: overview == null
          ? const SizedBox.shrink()
          : overview.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: EmptyState(
                artAsset: 'assets/images/sleep.png',
                title: Strings.todayWelcomeTitle,
                body: Strings.todayWelcomeBody,
                largeTitle: true,
                action: BigButton(
                  icon: Symbols.add_rounded,
                  label: Strings.todayCreateFirstSession,
                  onPressed: () => createSessionFlow(context, ref),
                ),
              ),
            )
          : const EmptyState(
              icon: Symbols.today_rounded,
              title: Strings.todayComingTitle,
              body: Strings.todayComingBody,
            ),
    );
  }
}
