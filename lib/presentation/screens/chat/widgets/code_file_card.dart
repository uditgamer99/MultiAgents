import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/code_file_parser.dart';

/// Renders one parsed code file inside a chat bubble: a filename
/// header, the code itself in a monospace block, and two actions —
/// copy to clipboard, and share via Android's share sheet (as a real
/// file, so "Save to Drive" etc. work like they would for any other
/// shared file).
class CodeFileCard extends StatelessWidget {
  final ParsedCodeFile file;

  const CodeFileCard({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            child: Row(
              children: [
                const Text('📄', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    file.filename,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () => _copy(context),
                ),
                IconButton(
                  tooltip: 'Share',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  onPressed: () => _share(context),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SingleChildScrollView(
              child: SelectableText(
                file.content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: file.content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied ${file.filename}')));
  }

  Future<void> _share(BuildContext context) async {
    try {
      // Write to a real temp file (not just shared text) so the
      // receiving app sees an actual .html/.dart/etc file — this is
      // what makes "Save to Drive" and similar share-sheet actions
      // work correctly.
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${file.filename}';
      final tempFile = await File(path).writeAsString(file.content);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(tempFile.path)], text: file.filename),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't share file.")));
    }
  }
}
