import 'package:flutter/material.dart';

/// Shows a simple rename dialog pre-filled with [currentTitle].
/// Returns the new title, or null if cancelled/unchanged.
Future<String?> showRenameChatDialog(
  BuildContext context, {
  required String currentTitle,
}) {
  final controller = TextEditingController(text: currentTitle);

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename chat'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        decoration: const InputDecoration(hintText: 'Chat title'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
