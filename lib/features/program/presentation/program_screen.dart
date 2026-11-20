import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/estimated_duration.dart';
import 'package:my_bodybuilding_program/features/program/domain/program.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_controller.dart';
import 'package:my_bodybuilding_program/features/program/presentation/program_providers.dart';

/// Asks for a name, creates the session and opens its editor.
Future<void> createSessionFlow(BuildContext context, WidgetRef ref) async {
  final name = await showTextPrompt(
    context,
    title: Strings.newSessionTitle,
    label: Strings.sessionNameLabel,
    confirmLabel: Strings.create,
  );
  if (name == null) return;
  final id = await ref.read(programControllerProvider).createSession(name);
  if (context.mounted) unawaited(context.push(Routes.session(id)));
}

/// Tab 2: the loop of sessions and the entry to the exercise catalogue.
class ProgramScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(programOverviewProvider).value;
    final exerciseCount =
        (ref.watch(exercisesProvider).value ?? const <Exercise>[])
            .where((e) => !e.isArchived)
            .length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: const TabTitle(Strings.tabProgram),
      ),
      body: overview == null
          ? const SizedBox.shrink()
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _CatalogueEntry(count: exerciseCount),
                  ),
                ),
                if (overview.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Symbols.repeat_rounded,
                      title: Strings.programNoSessionsTitle,
                      body: Strings.programNoSessionsBody,
                      action: FilledButton.icon(
                        onPressed: () => createSessionFlow(context, ref),
                        icon: const Icon(Symbols.add_rounded),
                        label: const Text(Strings.todayCreateFirstSession),
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl - AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Overline(
                              Strings.programLoop(overview.sessions.length),
                            ),
                          ),
                          if (overview.sessions.length > 1)
                            Text(
                              Strings.programDragToReorder,
                              style: context.text.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    sliver: SliverReorderableList(
                      itemCount: overview.sessions.length,
                      onReorderItem: (from, to) {
                        final ids = overview.sessionIds;
                        ids.insert(to, ids.removeAt(from));
                        unawaited(
                          ref
                              .read(programControllerProvider)
                              .reorderSessions(ids),
                        );
                      },
                      itemBuilder: (context, index) {
                        final plan = overview.sessions[index];
                        return Padding(
                          key: ValueKey(plan.session.id),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _SessionRow(
                            index: index,
                            plan: plan,
                            isNext: plan.session.id == overview.nextSessionId,
                          ),
                        );
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      112,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _LoopNote(overview: overview),
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: overview == null || overview.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => createSessionFlow(context, ref),
              icon: const Icon(Symbols.add_rounded),
              label: const Text(Strings.programAddSession),
            ),
    );
  }
}

class _CatalogueEntry extends StatelessWidget {
  const new({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.exercises),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Symbols.menu_book_rounded,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.programExercises,
                      style: context.text.titleMedium,
                    ),
                    Text(
                      Strings.programCatalogueCount(count),
                      style: context.text.bodyMedium!.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right_rounded,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const new({required this.index, required this.plan, required this.isNext});

  final int index;
  final SessionPlan plan;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final estimate = ref.watch(sessionEstimatesProvider)[plan.session.id] ?? 0;
    final foreground = isNext ? colors.onPrimaryContainer : colors.onSurface;
    final muted = isNext ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    final meta = [
      Strings.exerciseCount(plan.exercises.length),
      if (plan.setCount > 0)
        Strings.approxMinutes(EstimatedDuration.minutes(estimate)),
    ].join(' · ');

    return Material(
      color: isNext ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.session(plan.session.id)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: SizedBox(
                    width: 40,
                    height: 48,
                    child: Icon(
                      Symbols.drag_indicator_rounded,
                      color: muted,
                      semanticLabel: Strings.reorder,
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isNext
                        ? colors.primary
                        : colors.surfaceContainerHigh,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: context.text.labelLarge!.copyWith(
                      color: isNext ? colors.onPrimary : colors.onSurface,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.session.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleMedium!.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                          if (isNext) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const PillBadge(Strings.programNext),
                          ],
                        ],
                      ),
                      Text(
                        meta,
                        style: context.text.bodyMedium!.copyWith(
                          color: muted,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: Strings.programStartSession,
                  onPressed: plan.exercises.isEmpty
                      ? null
                      : () => context.push(
                          Routes.sessionPreview(plan.session.id),
                        ),
                  icon: Icon(
                    Symbols.play_circle_rounded,
                    fill: 1,
                    size: 32,
                    color: plan.exercises.isEmpty ? muted : colors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoopNote extends StatelessWidget {
  const new({required this.overview});

  final ProgramOverview overview;

  @override
  Widget build(BuildContext context) {
    if (overview.sessions.length < 2) return const SizedBox.shrink();
    final color = context.colors.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Symbols.replay_rounded, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            Strings.programLoopNote(
              overview.sessions.last.session.name,
              overview.sessions.first.session.name,
            ),
            style: context.text.bodyMedium!.copyWith(
              fontSize: 13,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
