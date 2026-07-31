import '../../domain/entities/chat_attachment_entity.dart';

/// Central place for every attachment-related limit and extension
/// mapping. Both [AttachmentPickerService] (data layer, does the
/// validating) and the preview/composer widgets (presentation layer,
/// need the same list to configure the file picker) read from here
/// so the two can never drift apart.
class AttachmentConfig {
  AttachmentConfig._();

  static const int maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB

  static const String maxFileSizeLabel = '25 MB';

  /// Every extension (lowercase, no leading dot) the picker will
  /// offer, mapped to the broad category it renders as.
  static const Map<String, AttachmentCategory> extensionCategories = {
    // Images
    'png': AttachmentCategory.image,
    'jpg': AttachmentCategory.image,
    'jpeg': AttachmentCategory.image,
    'webp': AttachmentCategory.image,
    // Documents
    'pdf': AttachmentCategory.pdf,
    'doc': AttachmentCategory.document,
    'docx': AttachmentCategory.document,
    // Archives
    'zip': AttachmentCategory.archive,
    // Text / code
    'txt': AttachmentCategory.text,
    'md': AttachmentCategory.text,
    'json': AttachmentCategory.code,
    'html': AttachmentCategory.code,
    'css': AttachmentCategory.code,
    'js': AttachmentCategory.code,
    'dart': AttachmentCategory.code,
    'py': AttachmentCategory.code,
  };

  static List<String> get allowedExtensions =>
      extensionCategories.keys.toList(growable: false);

  static AttachmentCategory categoryForExtension(String extension) {
    return extensionCategories[extension.toLowerCase()] ??
        AttachmentCategory.other;
  }

  static bool isSupportedExtension(String extension) {
    return extensionCategories.containsKey(extension.toLowerCase());
  }
}
