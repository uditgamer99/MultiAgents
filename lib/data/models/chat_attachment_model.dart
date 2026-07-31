import '../../domain/entities/chat_attachment_entity.dart';

/// Maps between Firestore's plain-map representation and the domain
/// [ChatAttachmentEntity]. Attachments are stored as a small array of
/// maps embedded directly in their parent message document — no
/// separate collection, and no file bytes ever touch Firestore.
class ChatAttachmentModel extends ChatAttachmentEntity {
  const ChatAttachmentModel({
    required super.id,
    required super.name,
    required super.path,
    required super.sizeBytes,
    required super.category,
    super.mimeType,
  });

  factory ChatAttachmentModel.fromEntity(ChatAttachmentEntity entity) {
    return ChatAttachmentModel(
      id: entity.id,
      name: entity.name,
      path: entity.path,
      sizeBytes: entity.sizeBytes,
      category: entity.category,
      mimeType: entity.mimeType,
    );
  }

  factory ChatAttachmentModel.fromMap(Map<String, dynamic> map) {
    return ChatAttachmentModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'file',
      path: map['path'] as String? ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      category: _categoryFromName(map['category'] as String?),
      mimeType: map['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'sizeBytes': sizeBytes,
      'category': category.name,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }

  static AttachmentCategory _categoryFromName(String? name) {
    return AttachmentCategory.values.firstWhere(
      (category) => category.name == name,
      orElse: () => AttachmentCategory.other,
    );
  }
}
