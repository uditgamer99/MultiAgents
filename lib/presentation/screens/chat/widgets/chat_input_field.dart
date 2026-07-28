import 'package:flutter/material.dart';

/// Bottom message composer: expanding text field + a button that's
/// either Send (idle) or Stop (while a reply is generating). Purely
/// presentational — the parent screen decides what happens on each.
class ChatInputField extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback? onStop;

  /// True while a reply is being generated — disables the text field
  /// and swaps the trailing button from Send to Stop.
  final bool isGenerating;

  const ChatInputField({
    super.key,
    required this.onSend,
    this.onStop,
    this.isGenerating = false,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !widget.isGenerating,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(hintText: 'Message'),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isGenerating)
              IconButton.filled(
                tooltip: 'Stop generating',
                onPressed: widget.onStop,
                icon: const Icon(Icons.stop_rounded),
              )
            else
              IconButton.filled(
                onPressed: _submit,
                icon: const Icon(Icons.arrow_upward),
              ),
          ],
        ),
      ),
    );
  }
}
