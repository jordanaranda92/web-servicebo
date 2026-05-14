import 'dart:typed_data';

import '../../features/orders_today/domain/entities/order_sheet.dart';

/// Service for parsing and encoding Excel (.xlsx) bytes to/from [OrderSheet].
///
/// This service is infrastructure-agnostic — it works with raw bytes and does
/// not depend on dart:io or any storage mechanism.
abstract class ExcelParserService {
  /// Parses raw .xlsx bytes into an [OrderSheet].
  OrderSheet parseExcelBytes(Uint8List bytes);

  /// Reads only the product header names from raw .xlsx bytes.
  List<String> parseHeadersFromBytes(Uint8List bytes);

  /// Encodes an [OrderSheet] into .xlsx bytes.
  Uint8List encodeOrderSheet(OrderSheet sheet);

  /// Updates the structure of an existing Excel (given as [existingBytes])
  /// to match [newHeaders], preserving existing data where column names match.
  /// Returns the encoded bytes of the updated Excel.
  Uint8List updateStructureBytes(
    Uint8List existingBytes,
    List<String> newHeaders,
  );

  /// Updates a single cell value in the Excel given as [bytes].
  /// Returns the encoded bytes of the updated Excel.
  Uint8List updateCellBytes(
    Uint8List bytes,
    String clientName,
    String product,
    num value,
  );

  /// Renames a client row in the Excel given as [bytes].
  /// Returns the encoded bytes of the updated Excel.
  Uint8List renameClientBytes(Uint8List bytes, String oldName, String newName);

  /// Adds a new client row in the Excel given as [bytes].
  /// Returns the encoded bytes of the updated Excel.
  Uint8List addRowBytes(Uint8List bytes, String clientName);

  /// Deletes client rows from the Excel given as [bytes].
  /// Returns the encoded bytes of the updated Excel.
  Uint8List deleteRowsBytes(Uint8List bytes, Set<String> clientNames);
}
