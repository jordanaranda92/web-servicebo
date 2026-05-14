// Implementación web de la descarga de archivos en el navegador.
// Este archivo solo se compila en plataforma web (dart.library.html).
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Descarga [bytes] como un archivo con nombre [fileName] en el navegador.
void downloadFileOnWeb(List<int> bytes, String fileName) {
  final data = Uint8List.fromList(bytes);
  final blob = web.Blob([data.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
