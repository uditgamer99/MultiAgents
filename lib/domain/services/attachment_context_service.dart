import '../../core/utils/send_stage.dart';
import '../entities/attachment_context_result_entity.dart';
import '../entities/chat_attachment_entity.dart';

/// Abstraction over "read these attachments and turn them into
/// Groq-ready context text". [AttachmentContextBuilder] (data layer)
/// is the current implementation — usecases depend only on this
/// interface, the same way they depend on [AgentResponseService]
/// rather than [GroqService] directly.
abstract class AttachmentContextService {
  /// Processes [attachments] and returns the formatted context block
  /// (see [AttachmentContextResult]). Implementations must never
  /// throw — any failure should be reflected in the result instead,
  /// so a caller can always proceed with sending the message.
  ///
  /// [onStage], if provided, is called with the real step currently
  /// running (never simulated/timed) so a caller closer to the UI can
  /// surface genuine progress.
  Future<AttachmentContextResult> build(
    List<ChatAttachmentEntity> attachments, {
    void Function(SendStage stage)? onStage,
  });
}
