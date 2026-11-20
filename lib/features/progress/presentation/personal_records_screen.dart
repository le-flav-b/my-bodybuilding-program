import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/app/widgets/common.dart';
import 'package:my_bodybuilding_program/app/widgets/empty_state.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/personal_records_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/pr_flows.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';
import 'package:my_bodybuilding_program/features/workout/presentation/player_widgets.dart';

/// The personal records of one exercise: the current best (per series) and
/// every PR, newest first, with add / edit / delete.
class PersonalRecordsScreen extends ConsumerWidget {
  const new({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseProvider(exerciseId));
    final records = ref.watch(exercisePersonalRecordsProvider(exerciseId));
    final units = ref.watch(unitLookupProvider);
    final colors = context.colors;
    final bests = exercise == null
        ? const <PrBest>[]
        : PrRule.bests(records, exercise.measure);

    void add() => unawaited(addPrFlow(context, ref, exerciseId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(Strings.personalRecords),
            Text(
              exercise?.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium!.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: Strings.exerciseInfo,
            icon: const Icon(Symbols.info_rounded),
            onPressed: () => context.push(Routes.exercise(exerciseId)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: records.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Symbols.add_rounded),
              label: const Text(Strings.addPr),
            ),
      body: records.isEmpty
          ? EmptyState(
              icon: Symbols.trophy_rounded,
              title: Strings.noPrYet,
              body: Strings.noPrBody,
              action: FilledButton.icon(
                onPressed: add,
                icon: const Icon(Symbols.add_rounded),
                label: const Text(Strings.addPr),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                96,
              ),
              children: [
                _BestCard(bests: bests),
                const SizedBox(height: AppSpacing.xl),
                Overline(
                  Strings.prHistory(records.length),
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final (i, r) in records.indexed) ...[
                  if (i > 0) Divider(height: 1, color: colors.outlineVariant),
                  _PrRow(
                    record: r,
                    value: prValueText(r, units),
                    isBest: bests.any((b) => b.record.id == r.id),
                    onEdit: () => unawaited(editPrFlow(context, ref, r)),
                    onDelete: () => unawaited(deletePrFlow(context, ref, r)),
                  ),
                ],
              ],
            ),
    );
  }
}

/// The current best PR, big, on a yellow-tinted card; the bests of the
/// other series (other units, or no load) below it.
class _BestCard extends ConsumerWidget {
  const new({required this.bests});

  final List<PrBest> bests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(unitLookupProvider);
    final best = bests.first.record;
    final note = best.note;
    final onCard = colors.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrophyChip(label: Strings.bestPr),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              prValueText(best, units),
              style: context.text.displaySmall!.copyWith(
                color: onCard,
                fontWeight: FontWeight.w700,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ),
          Text(
            DateFormat('EEE d MMM y').format(best.achievedAt.toLocal()),
            style: context.text.bodyLarge!.copyWith(color: onCard),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: context.text.bodyMedium!.copyWith(color: onCard)),
          ],
          if (bests.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: onCard.withValues(alpha: 0.2)),
            const SizedBox(height: AppSpacing.sm),
            Overline(Strings.prOtherUnits, color: onCard),
            for (final b in bests.skip(1))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        prValueText(b.record, units),
                        style: context.text.titleMedium!.copyWith(
                          color: onCard,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('d MMM y')
                          .format(b.record.achievedAt.toLocal()),
                      style: context.text.bodyMedium!.copyWith(color: onCard),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PrRow extends StatelessWidget {
  const new({
    required this.record,
    required this.value,
    required this.isBest,
    required this.onEdit,
    required this.onDelete,
  });

  final PersonalRecord record;
  final String value;
  final bool isBest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final note = record.note;
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: context.text.titleMedium!.copyWith(
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const TrophyChip(label: Strings.bestPr),
                      ],
                    ],
                  ),
                  Text(
                    [
                      DateFormat('EEE d MMM y')
                          .format(record.achievedAt.toLocal()),
                      ?note,
                    ].join(' ${PlanFormat.dot} '),
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: Strings.more,
              icon: Icon(
                Symbols.more_vert_rounded,
                color: colors.onSurfaceVariant,
              ),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Symbols.edit_rounded),
                    title: Text(Strings.editPr),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Symbols.delete_rounded, color: colors.error),
                    title: Text(
                      Strings.deletePr,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
