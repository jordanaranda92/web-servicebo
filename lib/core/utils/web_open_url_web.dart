import 'package:web/web.dart' as web;

/// Opens [url] in a new browser tab/window.
///
/// Only allows `https://` URLs and relative paths. Blocks `javascript:`,
/// `data:`, and other potentially dangerous schemes.
void openUrlInNewTab(String url) {
  final trimmed = url.trim();

  // Allow relative paths (e.g. AppRoutes) and https URLs only
  final isRelative = trimmed.startsWith('/');
  final isHttps = trimmed.startsWith('https://');

  if (!isRelative && !isHttps) return;

  web.window.open(trimmed, '_blank', 'noopener,noreferrer');
}
