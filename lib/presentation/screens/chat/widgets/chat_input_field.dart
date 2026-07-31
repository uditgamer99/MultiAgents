import 'package:flutter/material.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../data/services/attachment_picker_service.dart';
import '../../../../domain/entities/chat_attachment_entity.dart';
import 'attachment_chip.dart';

/// Bottom message composer: an optional attachment preview strip,
/// expanding text field, paperclip attachment button, and a button
/// that's either Send (idle) or Stop (while a reply is generating).
///
/// Attachments picked here are transient local UI state — they're
/// only handed to the parent screen (via [onSend]) at send time, and
/// removing one before sending never touches the file on the user's
/// device, only this pending list.
class ChatInputField extends StatefulWidget {
  final void Function(String text, List<ChatAttachmentEntity> attachments)
      onSend;
  final VoidCallback? onStop;

  /// True while a reply is being generated — disables the text field,
  /// the attachment button, and swaps the trailing button from Send
  /// to Stop.
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
  final _pickerService = AttachmentPickerService();

  List<ChatAttachmentEntity> _pendingAttachments = const [];
  bool _isPicking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;
    widget.onSend(text, _pendingAttachments);
    _controller.clear();
    setState(() => _pendingAttachments = const []);
  }

  Future<void> _pickAttachments() async {
    if (_isPicking || widget.isGenerating) return;
    setState(() => _isPicking = true);

    try {
      final result = await _pickerService.pickFiles();
      if (!mounted) return;

      if (result.attachments.isNotEmpty) {
        setState(() {
          _pendingAttachments = [
            ..._pendingAttachments,
            ...result.attachments,
          ];
        });
      }

      if (result.rejected.isNotEmpty) {
        _showMessage(_rejectionSummary(result.rejected));
      }
    } on AttachmentException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  String _rejectionSummary(List<RejectedAttachment> rejected) {
    if (rejected.length == 1) {
      final only = rejected.first;
      return '${only.name} ${only.reason}.';
    }
    return "${rejected.length} files couldn't be attached.";
  }

  void _removeAttachment(ChatAttachmentEntity attachment) {
    setState(() {
      _pendingAttachments =
          _pendingAttachments.where((a) => a.id != attachment.id).toList();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pendingAttachments.isNotEmpty) _buildPreviewStrip(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach files',
                  onPressed: widget.isGenerating || _isPicking
                      ? null
                      : _pickAttachments,
                  icon: _isPicking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStrip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _pendingAttachments.length,
          itemBuilder: (context, index) {
            final attachment = _pendingAttachments[index];
            return AttachmentChip(
              attachment: attachment,
              onRemove: () => _removeAttachment(attachment),
            );
          },
        ),
      ),
    );
  }
}
