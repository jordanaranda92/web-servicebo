import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.EventListener? _listener;

/// Prevents the browser-native context menu by adding a direct
/// `contextmenu` event listener on the document that calls
/// `preventDefault()`. Unlike `BrowserContextMenu.disableContextMenu()`,
/// this does not use a reference-counted mechanism and is therefore immune
/// to counter de-sync caused by `EditableText` focus changes.
void preventBrowserContextMenu() {
  if (_listener != null) return; // already active
  _listener = ((web.Event event) {
    event.preventDefault();
  }).toJS;
  web.document.addEventListener('contextmenu', _listener);
}

void restoreBrowserContextMenu() {
  if (_listener == null) return;
  web.document.removeEventListener('contextmenu', _listener!);
  _listener = null;
}
