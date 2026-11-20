import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';
import 'package:my_bodybuilding_program/app/theme/app_theme.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:my_bodybuilding_program/features/settings/domain/load_unit.dart';

/// Add or edit a personal record of an exercise measured by [measure]:
/// date, load + unit, reps (reps exercise) or time (time exercise), note.
/// [units] are all the units, archived ones included.
Future<PersonalRecordDraft?> showPrDialog(
  BuildContext context, {
  required Measure measure,
  required List<LoadUnit> units,
  required String defaultUnitId,
  required DateTime now,
  PersonalRecord? initial,
}) => showDialog<PersonalRecordDraft>(
  context: context,
  builder: (context) => _PrDialog(
    measure: measure,
    units: units,
    defaultUnitId: defaultUnitId,
    now: now,
    initial: initial,
  ),
);

/// A load typed by the user ("102.5", "102,5", "-10"): null when empty,
/// [double.nan] when not a number.
double? parsePrLoad(String text) {
  final clean = text.trim().replaceAll(',', '.').replaceAll('−', '-');
  if (clean.isEmpty) return null;
  return double.tryParse(clean) ?? double.nan;
}

/// A time typed by the user, in seconds: "1:20" or "80" (also "1:02:03").
/// Null when empty, -1 when not a time.
int? parsePrTime(String text) {
  final clean = text.trim();
  if (clean.isEmpty) return null;
  final parts = clean.split(':');
  if (parts.length > 3) return -1;
  var total = 0;
  for (final (i, part) in parts.indexed) {
    final n = int.tryParse(part);
    if (n == null || n < 0 || (i > 0 && n > 59)) return -1;
    total = total * 60 + n;
  }
  return total;
}

class _PrDialog extends StatefulWidget {
  const new({
    required this.measure,
    required this.units,
    required this.defaultUnitId,
    required this.now,
    this.initial,
  });

  final Measure measure;
  final List<LoadUnit> units;
  final String defaultUnitId;
  final DateTime now;
  final PersonalRecord? initial;

  @override
  State<_PrDialog> createState() => _PrDialogState();
}

class _PrDialogState extends State<_PrDialog> {
  late final PersonalRecord? _initial = widget.initial;
  late final _load = TextEditingController(text: _loadText(_initial?.load));
  late final _reps = TextEditingController(
    text: _initial?.reps?.toString() ?? '',
  );
  late final _time = TextEditingController(
    text: _initial?.seconds == null ? '' : _clock(_initial!.seconds!),
  );
  late final _note = TextEditingController(text: _initial?.note ?? '');
  late DateTime _at = (_initial?.achievedAt ?? widget.now).toLocal();
  late String _unitId = _initial?.unitId ?? widget.defaultUnitId;
  String? _loadError;
  String? _valueError;

  bool get _isTime => widget.measure == Measure.time;

  static String _loadText(double? value) {
    if (value == null) return '';
    final text = formatLoadValue(value, 3);
    return text.replaceAll('−', '-');
  }

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _load.dispose();
    _reps.dispose();
    _time.dispose();
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
    if (date == null) return;
    setState(() {
      _at = DateTime(
        date.year,
        date.month,
        date.day,
        _at.hour,
        _at.minute,
        _at.second,
      );
    });
  }

  void _clearErrors() {
    if (_loadError != null || _valueError != null) {
      setState(() => _loadError = _valueError = null);
    }
  }

  void _save() {
    final load = parsePrLoad(_load.text);
    if (load != null && load.isNaN) {
      setState(() => _loadError = Strings.prLoadInvalid);
      return;
    }
    int? reps;
    int? seconds;
    if (_isTime) {
      seconds = parsePrTime(_time.text);
      if (seconds == -1) {
        setState(() => _valueError = Strings.prTimeInvalid);
        return;
      }
    } else if (_reps.text.trim().isNotEmpty) {
      reps = int.tryParse(_reps.text.trim());
      if (reps == null) {
        setState(() => _valueError = Strings.prRepsInvalid);
        return;
      }
    }
    final draft = PersonalRecordDraft(
      achievedAt: _at.toUtc(),
      load: load == 0 ? null : load,
      unitId: _unitId,
      reps: reps,
      seconds: seconds,
      note: _note.text,
    );
    final error = draft.errorFor(widget.measure);
    if (error != null) {
      setState(
        () => _valueError = switch (error) {
          PrDraftError.repsOrLoadNeeded => Strings.prRepsOrLoadNeeded,
          PrDraftError.timeNeeded => Strings.prTimeNeeded,
          PrDraftError.timeInvalid => Strings.prTimeInvalid,
          _ => Strings.prRepsInvalid,
        },
      );
      return;
    }
    Navigator.of(context).pop(draft.normalizedFor(widget.measure));
  }

  @override
  Widget build(BuildContext context) {
    // Archived units are left out, except the one this PR was logged in.
    final units = [
      for (final u in widget.units)
        if (!u.isArchived || u.id == _unitId) u,
    ];
    final numberStyle = context.text.headlineSmall!.copyWith(
      fontFeatures: AppTheme.tabular,
    );
    final loadRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('pr-load'),
            controller: _load,
            autofocus: _initial == null && !_isTime,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            style: numberStyle,
            decoration: InputDecoration(
              labelText: Strings.prLoadOptional,
              errorText: _loadError,
            ),
            onChanged: (_) => _clearErrors(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        DropdownButton<String>(
          key: const ValueKey('pr-unit'),
          value: _unitId,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          padding: const EdgeInsets.only(top: AppSpacing.md),
          style: context.text.titleMedium!.copyWith(
            color: context.colors.onSurface,
          ),
          items: [
            for (final u in units)
              DropdownMenuItem(value: u.id, child: Text(u.name)),
          ],
          onChanged: (id) {
            if (id != null) setState(() => _unitId = id);
          },
        ),
      ],
    );
    final valueField = _isTime
        ? TextField(
            key: const ValueKey('pr-time'),
            controller: _time,
            autofocus: _initial == null,
            keyboardType: TextInputType.datetime,
            style: numberStyle,
            decoration: InputDecoration(
              labelText: Strings.prTime,
              helperText: Strings.prTimeHelper,
              errorText: _valueError,
            ),
            onChanged: (_) => _clearErrors(),
          )
        : TextField(
            key: const ValueKey('pr-reps'),
            controller: _reps,
            keyboardType: TextInputType.number,
            style: numberStyle,
            decoration: InputDecoration(
              labelText: Strings.prReps,
              helperText: Strings.prRepsOrLoadHelper,
              errorText: _valueError,
            ),
            onChanged: (_) => _clearErrors(),
          );
    return AlertDialog(
      title: Text(_initial == null ? Strings.addPr : Strings.editPr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Symbols.event_rounded),
              label: Text(DateFormat('EEE d MMM y').format(_at)),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Time exercise: the time first. Reps exercise: the load first
            // (a 1-rep max is a load alone), then the reps.
            if (_isTime) valueField else loadRow,
            const SizedBox(height: AppSpacing.md),
            if (_isTime) loadRow else valueField,
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('pr-note'),
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
