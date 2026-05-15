import 'dart:convert';

import 'app_logger.dart';

class FirebaseOperationsLogger {
  FirebaseOperationsLogger(this._logger);

  final AppLogger _logger;

  // ── Firestore operations ────────────────────────────────────────

  void logRead(String collectionPath, int docCount, [dynamic data]) {
    _logFirestore('READ', collectionPath, docCount, data);
  }

  void logStreamRead(String collectionPath, int docCount, [dynamic data]) {
    _logFirestore('READ (stream)', collectionPath, docCount, data);
  }

  void logWrite(String collectionPath, int docCount, [dynamic data]) {
    if (docCount == 0) return;
    _logFirestore('WRITE', collectionPath, docCount, data);
  }

  void logBatchWrite(String collectionPath, int docCount, [dynamic data]) {
    if (docCount == 0) return;
    _logFirestore('BATCH WRITE', collectionPath, docCount, data);
  }

  void logDelete(String collectionPath, int docCount) {
    if (docCount == 0) return;
    final docLabel = docCount == 1 ? '1 doc' : '$docCount docs';
    _logger.info('[Firestore] DELETE $collectionPath — $docLabel');
  }

  // ── Cloud Functions operations ──────────────────────────────────

  void logCloudFunctionCall(
    String functionName,
    String method,
    String path, [
    dynamic responseData,
  ]) {
    try {
      final sizePart = _estimateSize(responseData);
      final sizeStr = sizePart != null
          ? ' — response ~${_formatBytes(sizePart)}'
          : '';
      _logger.info(
        '[CloudFunctions] CALL $functionName — $method $path$sizeStr',
      );
    } catch (_) {
      _logger.info('[CloudFunctions] CALL $functionName — $method $path');
    }
  }

  // ── Internal helpers ────────────────────────────────────────────

  void _logFirestore(
    String operation,
    String collectionPath,
    int docCount,
    dynamic data,
  ) {
    try {
      final docLabel = docCount == 1 ? '1 doc' : '$docCount docs';
      final sizePart = _estimateSize(data);
      final sizeStr = sizePart != null ? ' — ~${_formatBytes(sizePart)}' : '';
      _logger.info(
        '[Firestore] $operation $collectionPath — $docLabel$sizeStr',
      );
    } catch (_) {
      final docLabel = docCount == 1 ? '1 doc' : '$docCount docs';
      _logger.info('[Firestore] $operation $collectionPath — $docLabel');
    }
  }

  int? _estimateSize(dynamic data) {
    if (data == null) return null;
    try {
      final jsonStr = jsonEncode(data);
      return utf8.encode(jsonStr).length;
    } catch (_) {
      return null;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
