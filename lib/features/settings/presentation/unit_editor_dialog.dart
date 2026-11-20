import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/settings_controller.dart';

/// Creates ([unit] null) or edits a custom load unit: name, step, decimals,
/// with a live preview. Editing offers Archive (in use) or Delete (never
/// used) on the left.
Future<void> showUnitEditor(
  BuildContext context, {
  LoadUnit? unit,
  int usage = 0,
}) => showDialog<void>(
  context: context,
  builder: (context) => _UnitEditorDialog(unit: unit, usage: usage),
);

class _UnitEditorDialog extends ConsumerStatefulWidget {
  const new({required this.unit, required this.usage});

  final LoadUnit? unit;
  final int usage;

  @override
  ConsumerState<_UnitEditorDialog> createState() => _UnitEditorDialogState();
}

class _UnitEditorDialogState extends ConsumerState<_UnitEditorDialog> {
  late final _name = TextEditingController(text: widget.unit?.name ?? '');
  late final _step = TextEditingController(
    text: widget.unit == null ? '1' : formatLoadValue(widget.unit!.step, 2),
  );
  late int _decimals = widget.unit?.decimals ?? 0;

  @override
  void dispose() {
    _name.dispose();
    _step.dispose();
    super.dispose();
  }

  LoadUnitDraft get _draft => LoadUnitDraft(
    name: _name.text.trim(),
    step: double.tryParse(_step.text.replaceAll(',', '.')) ?? 0,
    decimals: _decimals,
  );

  String get _preview {
    final draft = _draft;
    if (draft.error != null) return '…';
    final unit = LoadUnit(
      id: '',
      name: draft.name,
      step: draft.step,
      decimals: draft.decimals,
    );
    final start = unit.stepBy(draft.step * 5, 0);
    return '${unit.formatValue(start)} → '
        '${unit.formatValue(unit.stepBy(start, 1))} → '
        '${unit.format(unit.stepBy(start, 2))}';
  }

  Future<void> _save() async {
    await ref
        .read(settingsControllerProvider)
        .saveUnit(widget.unit?.id, _draft);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archiveOrDelete() async {
    final controller = ref.read(settingsControllerProvider);
    if (widget.usage > 0) {
      await controller.archiveUnit(widget.unit!.id);
    } else {
      await controller.deleteUnit(widget.unit!.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final editing = widget.unit != null;
    return AlertDialog(
      title: Text(editing ? Strings.editUnit : Strings.newUnit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: !editing,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: Strings.unitName,
                helperText: Strings.unitNameHelper,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _step,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: Strings.unitStepLabel,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Strings.unitDecimals, style: context.text.bodySmall),
                      const SizedBox(height: AppSpacing.xs),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 0, label: Text('0')),
                          ButtonSegment(value: 1, label: Text('1')),
                          ButtonSegment(value: 2, label: Text('2')),
                        ],
                        selected: {_decimals},
                        onSelectionChanged: (s) =>
                            setState(() => _decimals = s.single),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              Strings.unitPreview(_preview),
              style: context.text.bodyMedium!.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: editing
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.end,
      actions: [
        if (editing)
          TextButton(
            style: widget.usage > 0
                ? null
                : TextButton.styleFrom(foregroundColor: colors.error),
            onPressed: _archiveOrDelete,
            child: Text(widget.usage > 0 ? Strings.archive : Strings.delete),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(Strings.cancel),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: _draft.error == null ? _save : null,
              child: const Text(Strings.save),
            ),
          ],
        ),
      ],
    );
  }
}
