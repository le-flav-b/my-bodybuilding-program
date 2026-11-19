import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';

/// What the weigh-in dialog returns.
typedef WeighIn = ({DateTime measuredAt, double weightKg, String note});

/// Log or edit a weigh-in: weight in kg, date and time, optional note.
Future<WeighIn?> showBodyWeightDialog(
  BuildContext context, {
  required DateTime now,
  BodyWeight? initial,
  double? suggestion,
}) => showDialog<WeighIn>(
  context: context,
  builder: (context) =>
      _BodyWeightDialog(now: now, initial: initial, suggestion: suggestion),
);

/// "78.4" from user input ("78,4" too). Null when not a sensible weight.
double? parseWeight(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value < 20 || value > 400) return null;
  return (value * 10).round() / 10;
}

class _BodyWeightDialog extends StatefulWidget {
  const new({required this.now, this.initial, this.suggestion});

  final DateTime now;
  final BodyWeight? initial;
  final double? suggestion;

  @override
  State<_BodyWeightDialog> createState() => _BodyWeightDialogState();
}

class _BodyWeightDialogState extends State<_BodyWeightDialog> {
  late final TextEditingController _weight = TextEditingController(
    text: _format(widget.initial?.weightKg ?? widget.suggestion),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.initial?.note ?? '',
  );
  late DateTime _at = (widget.initial?.measuredAt ?? widget.now).toLocal();
  bool _showError = false;

  static String _format(double? value) =>
      value == null ? '' : value.toStringAsFixed(1);

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: widget.now.toLocal(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    setState(() {
      _at = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _at.hour,
        time?.minute ?? _at.minute,
      );
    });
  }

  void _save() {
    final weight = parseWeight(_weight.text);
    if (weight == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(
      context,
    ).pop((measuredAt: _at.toUtc(), weightKg: weight, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? Strings.logWeight : Strings.editWeight,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Symbols.event_rounded),
              label: Text(DateFormat('EEE d MMM · HH:mm').format(_at)),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _weight,
              autofocus: widget.initial == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: context.text.headlineSmall,
              decoration: InputDecoration(
                labelText: Strings.weightKg,
                suffixText: 'kg',
                errorText: _showError ? Strings.weightInvalid : null,
              ),
              onChanged: (_) {
                if (_showError) setState(() => _showError = false);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: Strings.noteOptional,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(onPressed: _save, child: const Text(Strings.save)),
      ],
    );
  }
}
