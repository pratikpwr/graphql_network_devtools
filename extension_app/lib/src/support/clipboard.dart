import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/services.dart';

/// Copies [text] to the system clipboard.
///
/// A DevTools extension runs in an iframe. In an IDE web view (VS Code,
/// Android Studio, IntelliJ) the browser blocks clipboard access from the
/// iframe, so `Clipboard.setData` alone fails without an error. This
/// function asks DevTools to copy the text, because DevTools knows how to
/// reach the clipboard in each host. It also tries `Clipboard.setData`
/// directly, for the standalone and simulated environments.
Future<void> copyText(
  String text, {
  String message = 'Copied to clipboard',
}) async {
  try {
    extensionManager.copyToClipboard(text, successMessage: message);
  } catch (_) {
    // Not running inside DevTools, for example in a widget test.
  }
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } catch (_) {
    // The browser can block clipboard access from an iframe. DevTools copied
    // the text above.
  }
}
