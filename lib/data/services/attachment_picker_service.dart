import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

import '../../core/constants/attachment_config.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/chat_attachment_entity.dart';

/// One file the user picked that could NOT be turned into an
/// attachment, plus a short, user-safe reason why.
class RejectedAttachment {
  final String name;
  final String reason;

  const RejectedAttachment({required this.name, required this.reason});
}

/// Result of one picker invocation. Never throws for a per-file
/// problem (oversized, unsupported, unreadable) — those are reported
/// via [rejected] so a bad file in a multi-select never sinks the
/// good ones. [AttachmentException] is reserved for the picker itself
/// failing to open at all.
class AttachmentPickResult {
  final List<ChatAttachmentEntity> attachments;
  final List<RejectedAttachment> rejected;

  const AttachmentPickResult({
    required this.attachments,
    required this.rejected,
  });

  /// True when the user cancelled (nothing picked, nothing rejected)
  /// — distinct from picking files that were all rejected.
  bool get wasCancelled => attachments.isEmpty && rejected.isEmpty;
}

/// Wraps the platform file picker and turns raw picker results into
/// validated [ChatAttachmentEntity]s.
///
/// Part 8A scope: this only *selects and describes* files — it never
/// reads a file's contents (beyond letting the UI render an image
/// thumbnail from its on-device path). Text extraction, PDF parsing,
/// and sending any file content to Groq are Part 8B's job.
class AttachmentPickerService {
  Future<AttachmentPickResult> pickFiles() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: AttachmentConfig.allowedExtensions,
        withData: false,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'AttachmentPickerService: file picker failed to open',
        error,
        stackTrace,
      );
      throw const AttachmentException(
        "Couldn't open the file picker. Please try again.",
      );
    }

    // A null result (or an empty file list) means the user backed
    // out of the picker — not an error, just nothing to do.
    if (result == null || result.files.isEmpty) {
      return const AttachmentPickResult(attachments: [], rejected: []);
    }

    final attachments = <ChatAttachmentEntity>[];
    final rejected = <RejectedAttachment>[];

    for (final file in result.files) {
      try {
        final outcome = _evaluate(file);
        if (outcome.attachment != null) {
          attachments.add(outcome.attachment!);
        } else {
          rejected.add(
            RejectedAttachment(name: file.name, reason: outcome.reason!),
          );
        }
      } catch (error, stackTrace) {
        // Any unexpected failure while inspecting one file (odd
        // content-provider path, permission denial on that specific
        // file, etc.) should never crash the whole selection — skip
        // just that file.
        AppLogger.error(
          'AttachmentPickerService: could not read ${file.name}',
          error,
          stackTrace,
        );
        rejected.add(
          RejectedAttachment(
            name: file.name,
            reason: "couldn't be accessed",
          ),
        );
      }
    }

    return AttachmentPickResult(attachments: attachments, rejected: rejected);
  }

  _Evaluation _evaluate(PlatformFile file) {
    final path = file.path;
    if (path == null || path.isEmpty) {
      // No filesystem path was exposed for this pick (can happen for
      // some content-provider-backed sources). Reading bytes instead
      // is out of scope for local attachment metadata in Part 8A.
      return const _Evaluation.rejected("couldn't be accessed");
    }

    final onDisk = File(path);
    if (!onDisk.existsSync()) {
      return const _Evaluation.rejected('is no longer available');
    }

    if (file.size > AttachmentConfig.maxFileSizeBytes) {
      return _Evaluation.rejected(
        'is larger than ${AttachmentConfig.maxFileSizeLabel}',
      );
    }

    final extension = (file.extension ?? '').toLowerCase();
    if (!AttachmentConfig.isSupportedExtension(extension)) {
      return const _Evaluation.rejected('is not a supported file type');
    }

    final category = AttachmentConfig.categoryForExtension(extension);
    final mimeType = lookupMimeType(path);

    return _Evaluation.accepted(
      ChatAttachmentEntity(
        id: '${DateTime.now().microsecondsSinceEpoch}_${file.name}',
        name: file.name,
        path: path,
        sizeBytes: file.size,
        category: category,
        mimeType: mimeType,
      ),
    );
  }
}

class _Evaluation {
  final ChatAttachmentEntity? attachment;
  final String? reason;

  const _Evaluation.accepted(this.attachment) : reason = null;
  const _Evaluation.rejected(this.reason) : attachment = null;
}
