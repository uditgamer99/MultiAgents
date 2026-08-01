import 'attachment_processing_result_entity.dart';

/// Output of [AttachmentContextService.build]: the text block to
/// prepend to the outgoing user message, plus the raw per-file
/// results (kept around for logging — nothing currently reads these
/// beyond the send/regenerate usecases, but future parts might).
class AttachmentContextResult {
  /// Null when there were no attachments to begin with. Never null
  /// (though it may be short) once there's at least one attachment —
  /// even attachments that failed or aren't supported still get a
  /// labeled entry, so the agent knows they exist instead of staying
  /// silent about them.
  final String? contextText;

  final List<AttachmentProcessingResult> results;

  const AttachmentContextResult({
    required this.contextText,
    required this.results,
  });
}
