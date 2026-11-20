import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/widgets/dialogs.dart';
import 'package:my_bodybuilding_program/core/utils/clock.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_providers.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/progress/data/personal_records_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/personal_records_providers.dart';
import 'package:my_bodybuilding_program/features/progress/presentation/pr_dialog.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/units_providers.dart';

/// "120 kg", "5 × 100 kg", "15 reps", "1:20", "1:20 · 20 kg".
String prValueText(PersonalRecord r, UnitLookup units) {
  final load = PlanFormat.load(r.load, r.unitId, units);
  if (r.seconds case final s?) {
    final time = PlanFormat.clock(s);
    return load == null ? time : '$time ${PlanFormat.dot} $load';
  }
  if (load == null) return Strings.repsCount(r.reps ?? 0);
  final reps = r.reps;
  return reps == null ? load : '$reps ${PlanFormat.times} $load';
}

/// Asks for a new PR of [exerciseId] and saves it.
Future<void> addPrFlow(
  BuildContext context,
  WidgetRef ref,
  String exerciseId,
) async {
  final exercise = ref.read(exerciseProvider(exerciseId));
  if (exercise == null) return;
  final records = ref.read(exercisePersonalRecordsProvider(exerciseId));
  final draft = await showPrDialog(
    context,
    measure: exercise.measure,
    units: ref.read(loadUnitsProvider).value ?? const <LoadUnit>[],
    // The unit of my latest loaded PR, or kg.
    defaultUnitId:
        records.where((r) => r.unitId != null).firstOrNull?.unitId ??
        FixedIds.kgUnit,
    now: ref.read(clockProvider)(),
  );
  if (draft == null) return;
  await ref
      .read(personalRecordsRepositoryProvider)
      .addRecord(exerciseId, draft);
  if (context.mounted) showAppSnackBar(context, Strings.prSaved);
}

/// Edits the PR [record].
Future<void> editPrFlow(
  BuildContext context,
  WidgetRef ref,
  PersonalRecord record,
) async {
  final exercise = ref.read(exerciseProvider(record.exerciseId));
  if (exercise == null) return;
  final draft = await showPrDialog(
    context,
    measure: exercise.measure,
    units: ref.read(loadUnitsProvider).value ?? const <LoadUnit>[],
    defaultUnitId: record.unitId ?? FixedIds.kgUnit,
    now: ref.read(clockProvider)(),
    initial: record,
  );
  if (draft == null) return;
  await ref
      .read(personalRecordsRepositoryProvider)
      .updateRecord(record.id, draft);
}

/// Deletes the PR [record] after a confirmation.
Future<void> deletePrFlow(
  BuildContext context,
  WidgetRef ref,
  PersonalRecord record,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: Strings.deletePrTitle,
    message: Strings.deletePrBody,
    confirmLabel: Strings.delete,
    destructive: true,
  );
  if (!confirmed) return;
  await ref.read(personalRecordsRepositoryProvider).deleteRecord(record.id);
  if (context.mounted) showAppSnackBar(context, Strings.prDeleted);
}
