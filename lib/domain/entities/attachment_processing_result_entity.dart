import 'package:equatable/equatable.dart';

/// Outcome of running one [ChatAttachmentEntity] through
/// [AttachmentProcessorService].
///
/// - [success]: text was extracted (it may still be empty, e.g. a
///   scanned PDF with no selectable text — check [extractedText]).
/// - [unsupported]: this file type is never going to be readable by
///   this layer (e.g. legacy .doc) or wasn't a type the app accepts
///   at all. Not an error — a permanent, known limitation.
/// - [notYetImplemented]: extraction for this category is planned
///   but deliberately out of scope for this part (images, ZIP).
/// - [error]: extraction was attempted and failed unexpectedly
///   (missing file, corrupted content, encoding failure, etc).
enum AttachmentProcessingStatus {
  success,
  unsupported,
  notYetImplemented,
  error,
}

/// Result of running one attachment through the extraction layer.
///
/// This is the boundary object the next part (wiring extracted text
/// into the Groq request) is meant to consume — it deliberately says
/// nothing about Groq, prompts, or agents. [extractedText] is null
/// for every status except [AttachmentProcessingStatus.success].
class AttachmentProcessingResult extends Equatable {
  /// Matches [ChatAttachmentEntity.id], so a result can be paired
  /// back up with the attachment it came from.
  final String attachmentId;

  final String attachmentName;

  final AttachmentProcessingStatus status;

  /// The extracted text. Only ever non-null when [status] is
  /// [AttachmentProcessingStatus.success]. May still be an empty
  /// string on success (e.g. an image-only PDF page) — see [message]
  /// for a human-readable note about that case.
  final String? extractedText;

  /// Short, user-safe explanation. Always present for
  /// [AttachmentProcessingStatus.unsupported],
  /// [AttachmentProcessingStatus.notYetImplemented], and
  /// [AttachmentProcessingStatus.error]. Optional on
  /// [AttachmentProcessingStatus.success] (e.g. to flag "no text
  /// found" or "some characters may not have decoded correctly").
  final String? message;

  const AttachmentProcessingResult({
    required this.attachmentId,
    required this.attachmentName,
    required this.status,
    this.extractedText,
    this.message,
  });

  factory AttachmentProcessingResult.success({
    required String attachmentId,
    required String attachmentName,
    required String extractedText,
    String? message,
  }) {
    return AttachmentProcessingResult(
      attachmentId: attachmentId,
      attachmentName: attachmentName,
      status: AttachmentProcessingStatus.success,
      extractedText: extractedText,
      message: message,
    );
  }

  factory AttachmentProcessingResult.unsupported({
    required String attachmentId,
    required String attachmentName,
    required String message,
  }) {
    return AttachmentProcessingResult(
      attachmentId: attachmentId,
      attachmentName: attachmentName,
      status: AttachmentProcessingStatus.unsupported,
      message: message,
    );
  }

  factory AttachmentProcessingResult.notYetImplemented({
    required String attachmentId,
    required String attachmentName,
    required String message,
  }) {
    return AttachmentProcessingResult(
      attachmentId: attachmentId,
      attachmentName: attachmentName,
      status: AttachmentProcessingStatus.notYetImplemented,
      message: message,
    );
  }

  factory AttachmentProcessingResult.error({
    required String attachmentId,
    required String attachmentName,
    required String message,
  }) {
    return AttachmentProcessingResult(
      attachmentId: attachmentId,
      attachmentName: attachmentName,
      status: AttachmentProcessingStatus.error,
      message: message,
    );
  }

  bool get isSuccess => status == AttachmentProcessingStatus.success;

  @override
  List<Object?> get props => [
    attachmentId,
    attachmentName,
    status,
    extractedText,
    message,
  ];
}
