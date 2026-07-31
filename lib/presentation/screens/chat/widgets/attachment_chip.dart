import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../domain/entities/chat_attachment_entity.dart';

/// One attachment, rendered either in the pending-send preview strip
/// (pass [onRemove]) or read-only inside a sent message bubble (pass
/// [compact]: true, no [onRemove]). Purely presentational — never
/// reads file contents beyond showing an image thumbnail from the
/// on-device path.
class AttachmentChip extends StatelessWidget {
  final ChatAttachmentEntity attachment;
  final VoidCallback? onRemove;

  /// True inside a message bubble, where the chip should shrink to
  /// its content instead of taking a fixed width in a horizontally
  /// scrolling strip.
  final bool compact;

  const AttachmentChip({
    super.key,
    required this.attachment,
    this.onRemove,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: compact ? null : 168,
      margin: EdgeInsets.only(right: compact ? 6 : 8, bottom: compact ? 6 : 0),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AttachmentThumbnail(attachment: attachment),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  formatAttachmentSize(attachment.sizeBytes),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 2),
            Tooltip(
              message: 'Remove',
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentThumbnail extends StatelessWidget {
  final ChatAttachmentEntity attachment;

  const _AttachmentThumbnail({required this.attachment});

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    final isImage = attachment.category == AttachmentCategory.image;

    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(attachment.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // The file might be removed/inaccessible after being
          // picked — fall back to the generic icon instead of
          // crashing or showing a broken-image placeholder.
          errorBuilder: (_, __, ___) => _fallbackIcon(context, size),
        ),
      );
    }

    return _fallbackIcon(context, size);
  }

  Widget _fallbackIcon(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_iconFor(attachment.category), size: 18),
    );
  }

  IconData _iconFor(AttachmentCategory category) {
    switch (category) {
      case AttachmentCategory.image:
        return Icons.image_outlined;
      case AttachmentCategory.pdf:
        return Icons.picture_as_pdf_outlined;
      case AttachmentCategory.document:
        return Icons.description_outlined;
      case AttachmentCategory.archive:
        return Icons.folder_zip_outlined;
      case AttachmentCategory.code:
        return Icons.code;
      case AttachmentCategory.text:
        return Icons.article_outlined;
      case AttachmentCategory.other:
        return Icons.insert_drive_file_outlined;
    }
  }
}

/// Human-readable file size, e.g. "482 KB" or "3.1 MB". Shared by the
/// preview strip and message bubble so both agree on formatting.
String formatAttachmentSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
