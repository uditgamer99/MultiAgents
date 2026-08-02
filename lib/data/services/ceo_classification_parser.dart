import '../../domain/entities/task_classification_entity.dart';

/// Parses the CEO agent's raw Groq reply (see the 'ceo' entry in
/// AgentSystemPrompts, which instructs it to always answer in the
/// "Category: ...\nReason: ..." format this expects) into a
/// [TaskClassificationEntity].
///
/// Deliberately defensive: if the model doesn't follow the format
/// exactly, this never throws — it just falls back to an empty
/// category list with the raw reply as the reason, so a formatting
/// slip can never crash or block the chat.
class CeoClassificationParser {
  CeoClassificationParser._();

  static TaskClassificationEntity parse(String rawReply) {
    final categoryLine = _extractLine(rawReply, 'Category:');
    final reasonLine = _extractLine(rawReply, 'Reason:');
    final confidenceLine = _extractLine(rawReply, 'Confidence:');

    final categories = <TaskCategory>[];
    if (categoryLine != null) {
      for (final token in categoryLine.split(',')) {
        final category = _categoryFromKey(
          token.trim().toLowerCase().replaceAll(' ', '_'),
        );
        if (category != null && !categories.contains(category)) {
          categories.add(category);
        }
      }
    }

    final reason = (reasonLine != null && reasonLine.trim().isNotEmpty)
        ? reasonLine.trim()
        : rawReply.trim();

    final confidence = confidenceLine != null
        ? double.tryParse(confidenceLine.trim())
        : null;

    return TaskClassificationEntity(
      categories: categories,
      reason: reason,
      confidence: confidence,
    );
  }

  static String? _extractLine(String text, String prefix) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith(prefix.toLowerCase())) {
        return trimmed.substring(prefix.length).trim();
      }
    }
    return null;
  }

  static TaskCategory? _categoryFromKey(String key) {
    switch (key) {
      case 'research':
        return TaskCategory.research;
      case 'design':
        return TaskCategory.design;
      case 'web_development':
        return TaskCategory.webDevelopment;
      case 'flutter_development':
        return TaskCategory.flutterDevelopment;
      case 'ai_engineering':
        return TaskCategory.aiEngineering;
      case 'marketing':
        return TaskCategory.marketing;
      default:
        return null;
    }
  }
}
