import '../../core/utils/logger.dart';
import '../../core/utils/send_stage.dart';
import '../../domain/entities/attachment_context_result_entity.dart';
import '../../domain/entities/attachment_processing_result_entity.dart';
import '../../domain/entities/chat_attachment_entity.dart';
import '../../domain/services/attachment_context_service.dart';
import 'attachment_processor_service.dart';

/// Bridges Part 8B.1's [AttachmentProcessorService] to the Groq
/// request: runs every attachment through extraction, then formats
/// the results into the
///
/// ```
/// Attached file: main.dart
/// [extracted content]
///
/// Attached file: notes.txt
/// [extracted content]
/// ```
///
/// block described in Part 8B.2. Every file's content is bounded in
/// size (never blindly forwarded in full), and unsupported/failed
/// attachments (DOC, image, ZIP, extraction errors) are still listed
/// by name with a short bracketed status instead of being silently
/// dropped — so the agent can honestly tell the user "I can see you
/// attached an image, but I can't read images yet" instead of
/// ignoring it.
///
/// This class only builds text — it has no opinion on trust. Making
/// sure the model treats that text as data, not instructions, is
/// [GroqService]'s job (it wraps this output with an explicit
/// system-prompt clause), so the untrusted-content handling lives in
/// exactly one place.
class AttachmentContextBuilder implements AttachmentContextService {
  /// Per-file cap. Keeps one huge file from eating the whole budget
  /// below on its own (~1000 tokens at ~4 chars/token).
  static const int maxCharsPerFile = 4000;

  /// Total cap across every attachment on one message. Sized to
  /// leave headroom under Groq's per-request token cap (see
  /// GroqService) once the system prompt, conversation history, and
  /// reserved output tokens are also counted — attachment content is
  /// the one part of the request whose size is otherwise unbounded,
  /// so it gets the tightest limit.
  static const int maxTotalContextChars = 8000;

  final AttachmentProcessorService _processor;

  AttachmentContextBuilder({AttachmentProcessorService? processor})
      : _processor = processor ?? AttachmentProcessorService();

  @override
  Future<AttachmentContextResult> build(
    List<ChatAttachmentEntity> attachments, {
    void Function(SendStage stage)? onStage,
  }) async {
    if (attachments.isEmpty) {
      return const AttachmentContextResult(contextText: null, results: []);
    }

    try {
      onStage?.call(SendStage.readingAttachments);
      onStage?.call(SendStage.extractingText);
      final results = await _processor.processAll(attachments);

      onStage?.call(SendStage.preparingContext);
      final contextText = _format(results);

      return AttachmentContextResult(
        contextText: contextText,
        results: results,
      );
    } catch (error, stackTrace) {
      // Never let a bug here stop the message itself from sending —
      // fall back to a minimal block that at least names every
      // attachment.
      AppLogger.error(
        'AttachmentContextBuilder: failed to build context for '
        '${attachments.length} attachment(s)',
        error,
        stackTrace,
      );
      final fallback = attachments
          .map(
            (a) =>
                'Attached file: ${a.name}\n'
                "[This attachment couldn't be processed.]",
          )
          .join('\n\n');
      return AttachmentContextResult(
        contextText: fallback,
        results: const [],
      );
    }
  }

  String _format(List<AttachmentProcessingResult> results) {
    final buffer = StringBuffer();
    var remainingBudget = maxTotalContextChars;

    for (final result in results) {
      buffer.writeln('Attached file: ${result.attachmentName}');

      if (remainingBudget <= 0) {
        buffer.writeln('[Skipped — attachment context limit reached.]');
        buffer.writeln();
        continue;
      }

      final block = _blockFor(result);
      final perFileCap = maxCharsPerFile < remainingBudget
          ? maxCharsPerFile
          : remainingBudget;
      final capped = _truncate(block, perFileCap);

      buffer.writeln(capped);
      buffer.writeln();
      remainingBudget -= capped.length;
    }

    return buffer.toString().trimRight();
  }

  /// The text that goes under one "Attached file: <name>" header.
  /// Successful extractions get their real content; everything else
  /// (unsupported, not-yet-implemented, error, or a success with no
  /// text found) gets a short bracketed status instead, so the block
  /// always honestly reflects what the app could actually read.
  String _blockFor(AttachmentProcessingResult result) {
    if (result.status == AttachmentProcessingStatus.success) {
      final text = result.extractedText ?? '';
      if (text.trim().isEmpty) {
        final reason = result.message ?? 'no text content was found';
        return '[No readable text was found in this file — $reason]';
      }
      return text;
    }
    return '[${result.message ?? "This attachment couldn't be processed."}]';
  }

  String _truncate(String text, int maxChars) {
    if (maxChars <= 0) return '[Skipped — attachment context limit reached.]';
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n…(truncated)';
  }
}
