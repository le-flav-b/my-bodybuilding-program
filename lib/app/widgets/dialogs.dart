import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/app/theme/app_colors.dart';

/// Two-choice confirmation (right-aligned text + filled). Returns true when
/// confirmed. A destructive confirmation uses a red text button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = Strings.cancel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        if (destructive)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for a short text (a name). Returns null when cancelled; the result
/// is trimmed and never empty.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String confirmLabel = Strings.save,
  String? helper,
  List<Widget> Function(BuildContext context)? extraActions,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextPromptDialog(
      title: title,
      label: label,
      initial: initial,
      confirmLabel: confirmLabel,
      helper: helper,
      extraActions: extraActions,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const new({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirmLabel,
    this.helper,
    this.extraActions,
  });

  final String title;
  final String label;
  final String initial;
  final String confirmLabel;
  final String? helper;
  final List<Widget> Function(BuildContext context)? extraActions;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
        ),
      ),
      actionsAlignment: widget.extraActions == null
          ? null
          : MainAxisAlignment.spaceBetween,
      actions: [
        if (widget.extraActions != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: widget.extraActions!(context),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(Strings.cancel),
            ),
            const SizedBox(width: 8),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => FilledButton(
                onPressed: _controller.text.trim().isEmpty ? null : _submit,
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shows a short message at the bottom, with an optional action (Undo).
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}
