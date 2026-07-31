import 'package:equatable/equatable.dart';

/// Broad category an attachment falls into. Drives which icon is
/// shown in the UI and, later (Part 8B), which extraction strategy
/// applies — it has no effect on how the attachment is stored.
enum AttachmentCategory { image, pdf, document, archive, code, text, other }

/// Domain-layer representation of one file attached to a chat
/// message. This is metadata only — it never holds file bytes and
/// nothing in Part 8A reads the file at [path] beyond rendering an
/// image thumbnail. Content extraction/analysis is Part 8B's job.
class ChatAttachmentEntity extends Equatable {
  /// Locally-generated id (not a Firestore doc id) — unique enough to
  /// let the UI find-and-remove one pending attachment among several.
  final String id;

  /// Original file name, e.g. "invoice.pdf".
  final String name;

  /// On-device path/URI the file was picked from. Never copied
  /// elsewhere by this system — removing an attachment from a
  /// pending message never touches the file this points to.
  final String path;

  /// Best-effort MIME type, when the platform/file extension makes
  /// one determinable. Null if unknown.
  final String? mimeType;

  final int sizeBytes;

  final AttachmentCategory category;

  const ChatAttachmentEntity({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.category,
    this.mimeType,
  });

  @override
  List<Object?> get props => [id, name, path, mimeType, sizeBytes, category];
}
