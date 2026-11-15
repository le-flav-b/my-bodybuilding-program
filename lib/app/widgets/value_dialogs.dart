import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/program/domain/plan_format.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';

/// Result of [showGoalDialog]: a number, or "max".
typedef GoalValue = ({int? value, bool isMax});

/// Picks a whole number with − / + (reps, seconds, rest), optionally with a
/// "to the max" switch. [asClock] shows seconds as m:ss.
Future<GoalValue?> showGoalDialog(
  BuildContext context, {
  required String title,
  required int initial,
  required int step,
  int min = 0,
  int max = 9999,
  bool asClock = false,
  bool allowMax = false,
  bool initialIsMax = false,
  List<int> presets = const [],
}) => showDialog<GoalValue>(
  context: context,
  builder: (context) => _GoalDialog(
    title: title,
    initial: initial,
    step: step,
    min: min,
    max: max,
    asClock: asClock,
    allowMax: allowMax,
    initialIsMax: initialIsMax,
    presets: presets,
  ),
);

class _GoalDialog extends StatefulWidget {
  const new({
    required this.title,
    required this.initial,
    required this.step,
    required this.min,
    required this.max,
    required this.asClock,
    required this.allowMax,
    required this.initialIsMax,
    required this.presets,
  });

  final String title;
  final int initial;
  final int step;
  final int min;
  final int max;
  final bool asClock;
  final bool allowMax;
  final bool initialIsMax;
  final List<int> presets;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late int _value = widget.initial.clamp(widget.min, widget.max);
  late bool _isMax = widget.initialIsMax;

  void _bump(int direction) => setState(() {
    final snapped = (_value / widget.step).round() * widget.step;
    final base = snapped == _value
        ? _value
        : (direction > 0 ? snapped - widget.step : snapped + widget.step);
    _value = (base + direction * widget.step).clamp(widget.min, widget.max);
  });

  String _format(int value) =>
      widget.asClock ? PlanFormat.clock(value) : '$value';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: _isMax ? 0.38 : 1,
            child: IgnorePointer(
              ignoring: _isMax,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip: '−${_format(widget.step)}',
                        onPressed: _value > widget.min ? () => _bump(-1) : null,
                        icon: const Icon(Symbols.remove_rounded),
                      ),
                      SizedBox(
                        width: 128,
                        child: Text(
                          _format(_value),
                          textAlign: TextAlign.center,
                          style: context.text.displaySmall!.copyWith(
                            fontSize: 32,
                            height: 40 / 32,
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: '+${_format(widget.step)}',
                        onPressed: _value < widget.max ? () => _bump(1) : null,
                        icon: const Icon(Symbols.add_rounded),
                      ),
                    ],
                  ),
                  if (widget.presets.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final preset in widget.presets)
                          ActionChip(
                            label: Text(_format(preset)),
                            onPressed: () => setState(() => _value = preset),
                            side: BorderSide(color: colors.outlineVariant),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.allowMax) ...[
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.toMax),
              subtitle: const Text(Strings.toMaxHint),
              value: _isMax,
              onChanged: (v) => setState(() => _isMax = v),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop((value: _isMax ? null : _value, isMax: _isMax)),
          child: const Text(Strings.ok),
        ),
      ],
    );
  }
}

/// Result of [showLoadDialog]: a load, or none (bodyweight).
typedef LoadValue = ({double? load});

/// Enters a load in [unit]: empty = bodyweight, negative = assisted.
Future<LoadValue?> showLoadDialog(
  BuildContext context, {
  required LoadUnit unit,
  double? initial,
}) => showDialog<LoadValue>(
  context: context,
  builder: (context) => _LoadDialog(unit: unit, initial: initial),
);

class _LoadDialog extends StatefulWidget {
  const new({required this.unit, required this.initial});

  final LoadUnit unit;
  final double? initial;

  @override
  State<_LoadDialog> createState() => _LoadDialogState();
}

class _LoadDialogState extends State<_LoadDialog> {
  late final _controller = TextEditingController(
    text: widget.initial == null ? '' : _plain(widget.initial!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Keyboard-friendly form (ASCII minus).
  String _plain(double value) =>
      widget.unit.formatValue(value).replaceAll('−', '-');

  double? get _value {
    final text = _controller.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  bool get _valid => _controller.text.trim().isEmpty || _value != null;

  void _bump(int steps) => setState(() {
    final next = widget.unit.stepBy(_value ?? 0, steps);
    _controller.text = _plain(next);
  });

  @override
  Widget build(BuildContext context) {
    final step = formatLoadValue(widget.unit.step, 2);
    return AlertDialog(
      title: const Text(Strings.loadDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: '−$step',
                onPressed: () => _bump(-1),
                icon: const Icon(Symbols.remove_rounded),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  style: context.text.headlineSmall!.copyWith(
                    fontFeatures: AppTheme.tabular,
                  ),
                  decoration: InputDecoration(
                    hintText: Strings.bodyweight,
                    suffixText: widget.unit.name,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton.filledTonal(
                tooltip: '+$step',
                onPressed: () => _bump(1),
                icon: const Icon(Symbols.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(Strings.loadNoneHint, style: context.text.bodySmall),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop((load: null)),
          child: const Text(Strings.noLoad),
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
              onPressed: _valid
                  ? () => Navigator.of(context).pop((load: _value))
                  : null,
              child: const Text(Strings.ok),
            ),
          ],
        ),
      ],
    );
  }
}
