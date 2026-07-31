import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart' as xml;

import '../../core/utils/logger.dart';
import '../../domain/entities/attachment_processing_result_entity.dart';
import '../../domain/entities/chat_attachment_entity.dart';

/// Reads the contents of a [ChatAttachmentEntity] and turns it into
/// an [AttachmentProcessingResult].
///
/// Scope (Phase 2.2 Part 8B.1 — attachment reading/extraction only):
/// - Plain text/code files are read as-is.
/// - PDF and DOCX have their text extracted.
/// - Legacy DOC, images, and ZIP are detected and reported as
///   unsupported / not-yet-implemented — never attempted.
///
/// Explicitly OUT of scope here: this service never sends anything to
/// Groq, never touches agent/CEO logic, and never does Phase 3 work.
/// It only turns a file on disk into text (or a clear reason it
/// couldn't).
///
/// [process] is designed to never throw. Every failure mode —
/// missing file, corrupted content, a decode error, an unexpected
/// exception from a parsing library — is caught and reported as an
/// [AttachmentProcessingStatus.error] result instead.
class AttachmentProcessorService {
  static const _imageMessage =
      'Image attachment detected. Vision processing is not enabled yet.';

  static const _zipMessage =
      'ZIP file detected. Extracting its contents is not implemented yet.';

  static const _docMessage =
      "This is a legacy .doc file. Reliable text extraction isn't "
      'available for this format yet — try re-saving it as .docx.';

  static const _genericUnsupportedMessage =
      "This file type isn't supported yet.";

  static const _genericErrorMessage =
      "Something went wrong while reading this file.";

  /// Processes every attachment, one at a time. A failure on one file
  /// never stops the rest — each attachment always gets exactly one
  /// result back, in the same order as [attachments].
  Future<List<AttachmentProcessingResult>> processAll(
    List<ChatAttachmentEntity> attachments,
  ) async {
    final results = <AttachmentProcessingResult>[];
    for (final attachment in attachments) {
      results.add(await process(attachment));
    }
    return results;
  }

  /// Processes a single attachment. Never throws — any unexpected
  /// failure is converted into an [AttachmentProcessingStatus.error]
  /// result and logged.
  Future<AttachmentProcessingResult> process(
    ChatAttachmentEntity attachment,
  ) async {
    try {
      final file = File(attachment.path);
      if (!await file.exists()) {
        return AttachmentProcessingResult.error(
          attachmentId: attachment.id,
          attachmentName: attachment.name,
          message: 'This file is no longer available on the device.',
        );
      }

      final extension = _extensionOf(attachment.name);

      switch (attachment.category) {
        case AttachmentCategory.text:
        case AttachmentCategory.code:
          return _extractPlainText(attachment, file);

        case AttachmentCategory.pdf:
          return _extractPdf(attachment, file);

        case AttachmentCategory.document:
          if (extension == 'docx') {
            return _extractDocx(attachment, file);
          }
          // .doc (legacy binary format) — no reliable extraction
          // available. Detect and report clearly, never attempt it.
          return AttachmentProcessingResult.unsupported(
            attachmentId: attachment.id,
            attachmentName: attachment.name,
            message: _docMessage,
          );

        case AttachmentCategory.image:
          return AttachmentProcessingResult.notYetImplemented(
            attachmentId: attachment.id,
            attachmentName: attachment.name,
            message: _imageMessage,
          );

        case AttachmentCategory.archive:
          return AttachmentProcessingResult.notYetImplemented(
            attachmentId: attachment.id,
            attachmentName: attachment.name,
            message: _zipMessage,
          );

        case AttachmentCategory.other:
          return AttachmentProcessingResult.unsupported(
            attachmentId: attachment.id,
            attachmentName: attachment.name,
            message: _genericUnsupportedMessage,
          );
      }
    } catch (error, stackTrace) {
      // Final safety net: whatever kind of file this was, and
      // whatever library was involved, a bug or an unforeseen edge
      // case must never crash the caller.
      AppLogger.error(
        'AttachmentProcessorService: failed to process ${attachment.name}',
        error,
        stackTrace,
      );
      return AttachmentProcessingResult.error(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        message: _genericErrorMessage,
      );
    }
  }

  /// TXT, MD, JSON, HTML, CSS, JS, Dart, Python — read as UTF-8 with
  /// a best-effort fallback for files that aren't valid UTF-8.
  Future<AttachmentProcessingResult> _extractPlainText(
    ChatAttachmentEntity attachment,
    File file,
  ) async {
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      return AttachmentProcessingResult.success(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        extractedText: '',
        message: 'This file is empty.',
      );
    }

    try {
      final text = utf8.decode(bytes);
      return AttachmentProcessingResult.success(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        extractedText: text,
      );
    } on FormatException catch (error, stackTrace) {
      // Not valid UTF-8 (unusual encoding, or a binary file that
      // slipped through with a text extension). Fall back to a
      // lossy decode rather than failing outright — a best-effort
      // read is more useful than nothing for a text/code file.
      AppLogger.error(
        'AttachmentProcessorService: ${attachment.name} is not valid UTF-8, '
        'falling back to a lossy decode',
        error,
        stackTrace,
      );
      final text = utf8.decode(bytes, allowMalformed: true);
      return AttachmentProcessingResult.success(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        extractedText: text,
        message:
            'Some characters may not have decoded correctly — this '
            "file isn't valid UTF-8.",
      );
    }
  }

  Future<AttachmentProcessingResult> _extractPdf(
    ChatAttachmentEntity attachment,
    File file,
  ) async {
    PdfDocument? document;
    try {
      final bytes = await file.readAsBytes();
      document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();

      if (text.trim().isEmpty) {
        return AttachmentProcessingResult.success(
          attachmentId: attachment.id,
          attachmentName: attachment.name,
          extractedText: text,
          message:
              'No selectable text was found in this PDF — it may be '
              'a scan or contain only images.',
        );
      }

      return AttachmentProcessingResult.success(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        extractedText: text,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'AttachmentProcessorService: PDF extraction failed for '
        '${attachment.name}',
        error,
        stackTrace,
      );
      return AttachmentProcessingResult.error(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        message:
            "Couldn't extract text from this PDF — it may be corrupted "
            'or password-protected.',
      );
    } finally {
      document?.dispose();
    }
  }

  /// DOCX is a ZIP archive containing XML. This unzips it in memory
  /// and pulls the text runs (`<w:t>`) out of `word/document.xml` —
  /// no platform/native code involved, so this works the same on
  /// every platform Flutter targets.
  Future<AttachmentProcessingResult> _extractDocx(
    ChatAttachmentEntity attachment,
    File file,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final documentXmlFile = archive.findFile('word/document.xml');
      if (documentXmlFile == null) {
        return AttachmentProcessingResult.error(
          attachmentId: attachment.id,
          attachmentName: attachment.name,
          message:
              "Couldn't read this DOCX file — it doesn't look like a "
              'valid Word document.',
        );
      }

      final xmlContent = utf8.decode(
        documentXmlFile.content as List<int>,
        allowMalformed: true,
      );
      final xmlDoc = xml.XmlDocument.parse(xmlContent);

      final buffer = StringBuffer();
      for (final paragraph in xmlDoc.findAllElements('w:p')) {
        final runsText = paragraph
            .findAllElements('w:t')
            .map((node) => node.innerText)
            .join();
        buffer.writeln(runsText);
      }

      final text = buffer.toString().trim();

      return AttachmentProcessingResult.success(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        extractedText: text,
        message: text.isEmpty
            ? 'No readable text was found in this document.'
            : null,
      );
    } on ArchiveException catch (error, stackTrace) {
      AppLogger.error(
        'AttachmentProcessorService: DOCX is not a valid ZIP for '
        '${attachment.name}',
        error,
        stackTrace,
      );
      return AttachmentProcessingResult.error(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        message: "Couldn't read this DOCX file — it may be corrupted.",
      );
    } on xml.XmlParserException catch (error, stackTrace) {
      AppLogger.error(
        'AttachmentProcessorService: DOCX XML parse failed for '
        '${attachment.name}',
        error,
        stackTrace,
      );
      return AttachmentProcessingResult.error(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        message: "Couldn't read this DOCX file — it may be corrupted.",
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'AttachmentProcessorService: DOCX extraction failed for '
        '${attachment.name}',
        error,
        stackTrace,
      );
      return AttachmentProcessingResult.error(
        attachmentId: attachment.id,
        attachmentName: attachment.name,
        message: "Couldn't extract text from this DOCX file.",
      );
    }
  }

  String _extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
