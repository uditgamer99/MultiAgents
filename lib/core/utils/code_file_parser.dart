/// One file extracted from an agent's "📄 filename" formatted reply.
class ParsedCodeFile {
  final String filename;
  final String content;

  const ParsedCodeFile({required this.filename, required this.content});
}

/// Parses a message like:
///
/// ```
/// Here's your page:
///
/// 📄 index.html
/// ```html
/// <!DOCTYPE html>
/// ...
/// ```
///
/// 📄 style.css
/// ```css
/// ...
/// ```
/// ```
///
/// into a leading text blurb plus a list of [ParsedCodeFile]s, with
/// any ```code fence``` markers stripped from each file's content.
/// Returns an empty file list (and the whole text as [introText]) if
/// the message contains no "📄 " markers — i.e. an ordinary reply.
class CodeFileParseResult {
  final String introText;
  final List<ParsedCodeFile> files;

  const CodeFileParseResult({required this.introText, required this.files});

  bool get hasFiles => files.isNotEmpty;
}

CodeFileParseResult parseCodeFiles(String text) {
  final marker = RegExp(r'^📄[ \t]*(.+)$', multiLine: true);
  final matches = marker.allMatches(text).toList();

  if (matches.isEmpty) {
    return CodeFileParseResult(introText: text, files: const []);
  }

  final introText = text.substring(0, matches.first.start).trim();
  final files = <ParsedCodeFile>[];

  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final filename = match.group(1)!.trim();
    final contentStart = match.end;
    final contentEnd =
        i + 1 < matches.length ? matches[i + 1].start : text.length;
    final rawContent = text.substring(contentStart, contentEnd).trim();
    files.add(
      ParsedCodeFile(filename: filename, content: _stripCodeFence(rawContent)),
    );
  }

  return CodeFileParseResult(introText: introText, files: files);
}

final _fencePattern = RegExp(r'^```[a-zA-Z0-9_+-]*\n([\s\S]*?)\n?```$');

String _stripCodeFence(String content) {
  final match = _fencePattern.firstMatch(content.trim());
  if (match != null) {
    return match.group(1)!.trim();
  }
  return content;
}
