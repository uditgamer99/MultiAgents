/// One step of sending a message or regenerating a reply, reported
/// via an `onStage` callback so the UI can reflect what is *actually*
/// happening right now — never a simulated/timed progress bar.
///
/// Only [readingAttachments], [extractingText], and [preparingContext]
/// are skipped when there are no attachments; [sendingToAi] always
/// fires right before the request goes out, attachments or not.
enum SendStage {
  readingAttachments,
  extractingText,
  preparingContext,
  sendingToAi,
}
