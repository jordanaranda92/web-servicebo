import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;

import '../../features/orders_today/domain/entities/order_sheet.dart';
import '../error/exceptions.dart';
import '../log/app_logger.dart';
import 'excel_parser_service.dart';

class ExcelParserServiceImpl implements ExcelParserService {
  ExcelParserServiceImpl(this._logger);

  final AppLogger _logger;

  /// Label used as the client column header in Excel files.
  static const _clientHeaderLabel = 'Cliente';

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Finds the header row index and client column index by searching for
  /// a cell whose text value equals [_clientHeaderLabel].
  (int rowIndex, int colIndex)? _findHeaderPosition(xl.Sheet sheet) {
    for (var r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell != null &&
            cell.value != null &&
            cell.value.toString().trim().toLowerCase() ==
                _clientHeaderLabel.toLowerCase()) {
          return (r, c);
        }
      }
    }
    return null;
  }

  ({xl.Excel excel, xl.Sheet sheet, int headerRowIdx, int clientCol})
  _decodeExcel(Uint8List bytes) {
    final excel = xl.Excel.decodeBytes(bytes);
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];

    if (sheet == null || sheet.rows.isEmpty) {
      throw const ParsingException(
        'El archivo Excel está vacío o no tiene hojas',
      );
    }

    final pos = _findHeaderPosition(sheet);
    if (pos == null) {
      throw const ParsingException(
        'No se encontró la cabecera "Cliente" en el archivo',
      );
    }

    final (headerRowIdx, clientCol) = pos;
    return (
      excel: excel,
      sheet: sheet,
      headerRowIdx: headerRowIdx,
      clientCol: clientCol,
    );
  }

  Uint8List _encode(xl.Excel excel) {
    final encoded = excel.encode();
    if (encoded == null) {
      throw const ParsingException('Error al codificar el archivo Excel');
    }
    return Uint8List.fromList(encoded);
  }

  int _findProductCol(List<xl.Data?> headerRow, int clientCol, String product) {
    for (var c = clientCol + 1; c < headerRow.length; c++) {
      final cell = headerRow[c];
      if (cell != null &&
          cell.value != null &&
          cell.value.toString() == product) {
        return c;
      }
    }
    throw ParsingException('Producto "$product" no encontrado');
  }

  int _findClientRow(
    xl.Sheet sheet,
    int headerRowIdx,
    int clientCol,
    String clientName,
  ) {
    for (var r = headerRowIdx + 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (clientCol < row.length) {
        final cell = row[clientCol];
        if (cell != null && cell.value.toString() == clientName) {
          return r;
        }
      }
    }
    throw ParsingException('Cliente "$clientName" no encontrado');
  }

  // ── Public API ──────────────────────────────────────────────────────

  @override
  OrderSheet parseExcelBytes(Uint8List bytes) {
    try {
      final ctx = _decodeExcel(bytes);
      final headerRow = ctx.sheet.rows[ctx.headerRowIdx];
      final products = headerRow
          .skip(ctx.clientCol + 1)
          .where((cell) => cell != null && cell.value != null)
          .map((cell) => cell!.value.toString())
          .toList();

      // Parse client names and build quantities matrix (transposed)
      final clientNames = <String>[];
      final clientQuantities =
          <List<num>>[]; // clientQuantities[clientIdx][productIdx]
      for (var i = ctx.headerRowIdx + 1; i < ctx.sheet.rows.length; i++) {
        final row = ctx.sheet.rows[i];
        if (ctx.clientCol >= row.length) continue;
        final clientCell = row[ctx.clientCol];
        if (clientCell == null || clientCell.value == null) continue;

        final clientName = clientCell.value.toString();
        if (clientName.trim().isEmpty) continue;

        final rowQuantities = <num>[];
        for (var j = 0; j < products.length; j++) {
          final cellIndex = ctx.clientCol + 1 + j;
          if (cellIndex < row.length) {
            final cell = row[cellIndex];
            if (cell != null) {
              final cellValue = cell.value;
              if (cellValue is xl.IntCellValue) {
                rowQuantities.add(cellValue.value);
              } else if (cellValue is xl.DoubleCellValue) {
                rowQuantities.add(cellValue.value);
              } else if (cellValue != null) {
                rowQuantities.add(num.tryParse(cellValue.toString()) ?? 0);
              } else {
                rowQuantities.add(0);
              }
            } else {
              rowQuantities.add(0);
            }
          } else {
            rowQuantities.add(0);
          }
        }

        clientNames.add(clientName);
        clientQuantities.add(rowQuantities);
      }

      // Transpose: quantities[productIdx][clientIdx]
      final quantities = <List<num>>[];
      final pedidos = <num>[];
      for (var p = 0; p < products.length; p++) {
        final row = <num>[];
        num sum = 0;
        for (var c = 0; c < clientNames.length; c++) {
          final val = p < clientQuantities[c].length
              ? clientQuantities[c][p]
              : 0;
          row.add(val);
          sum += val;
        }
        quantities.add(row);
        pedidos.add(sum);
      }

      return OrderSheet(
        date: '',
        clients: clientNames,
        products: products,
        quantities: quantities,
        pedidos: pedidos,
        stocks: List.filled(products.length, 0),
        quedan: List.filled(products.length, 0),
        clientOrders: List.filled(clientNames.length, 0),
      );
    } on ParsingException {
      rethrow;
    } catch (e, st) {
      _logger.error('Error al parsear bytes Excel', e, st);
      throw const ParsingException('Error al leer el archivo Excel');
    }
  }

  @override
  List<String> parseHeadersFromBytes(Uint8List bytes) {
    try {
      final ctx = _decodeExcel(bytes);
      final headerRow = ctx.sheet.rows[ctx.headerRowIdx];
      return headerRow
          .skip(ctx.clientCol + 1)
          .where((cell) => cell != null && cell.value != null)
          .map((cell) => cell!.value.toString())
          .toList();
    } catch (e, st) {
      _logger.error('Error al leer cabeceras de bytes', e, st);
      throw const ParsingException('Error al leer las cabeceras del archivo');
    }
  }

  @override
  Uint8List encodeOrderSheet(OrderSheet sheet) {
    try {
      final excel = xl.Excel.createExcel();
      final sheetName = excel.tables.keys.first;
      final xlSheet = excel[sheetName];

      // Header row
      xlSheet.appendRow([
        xl.TextCellValue(_clientHeaderLabel),
        ...sheet.products.map((h) => xl.TextCellValue(h)),
      ]);

      // Data rows — transpose back: one row per client
      for (var c = 0; c < sheet.clients.length; c++) {
        xlSheet.appendRow([
          xl.TextCellValue(sheet.clients[c]),
          ...List.generate(sheet.products.length, (p) {
            final value =
                p < sheet.quantities.length && c < sheet.quantities[p].length
                ? sheet.quantities[p][c]
                : 0;
            if (value is int) return xl.IntCellValue(value);
            return xl.DoubleCellValue(value.toDouble());
          }),
        ]);
      }

      return _encode(excel);
    } catch (e, st) {
      _logger.error('Error al codificar OrderSheet', e, st);
      throw const ParsingException('Error al codificar el archivo Excel');
    }
  }

  @override
  Uint8List updateStructureBytes(
    Uint8List existingBytes,
    List<String> newHeaders,
  ) {
    try {
      final existingData = parseExcelBytes(existingBytes);

      final excel = xl.Excel.createExcel();
      final sheetName = excel.tables.keys.first;
      final sheet = excel[sheetName];

      sheet.appendRow([
        xl.TextCellValue(_clientHeaderLabel),
        ...newHeaders.map((h) => xl.TextCellValue(h)),
      ]);

      // Transpose back: one row per client, lookup by product name
      for (var c = 0; c < existingData.clients.length; c++) {
        sheet.appendRow([
          xl.TextCellValue(existingData.clients[c]),
          ...newHeaders.map((product) {
            final pIdx = existingData.products.indexOf(product);
            num value = 0;
            if (pIdx >= 0 &&
                pIdx < existingData.quantities.length &&
                c < existingData.quantities[pIdx].length) {
              value = existingData.quantities[pIdx][c];
            }
            if (value is int) return xl.IntCellValue(value);
            return xl.DoubleCellValue(value.toDouble());
          }),
        ]);
      }

      return _encode(excel);
    } on ParsingException {
      rethrow;
    } catch (e, st) {
      _logger.error('Error al actualizar estructura', e, st);
      throw const ParsingException(
        'Error al actualizar la estructura del archivo',
      );
    }
  }

  @override
  Uint8List updateCellBytes(
    Uint8List bytes,
    String clientName,
    String product,
    num value,
  ) {
    try {
      final ctx = _decodeExcel(bytes);
      final headerRow = ctx.sheet.rows[ctx.headerRowIdx];

      final productColIdx = _findProductCol(headerRow, ctx.clientCol, product);
      final clientRowIdx = _findClientRow(
        ctx.sheet,
        ctx.headerRowIdx,
        ctx.clientCol,
        clientName,
      );

      final cellValue = value == value.toInt()
          ? xl.IntCellValue(value.toInt())
          : xl.DoubleCellValue(value.toDouble());
      ctx.sheet.updateCell(
        xl.CellIndex.indexByColumnRow(
          columnIndex: productColIdx,
          rowIndex: clientRowIdx,
        ),
        cellValue,
      );

      return _encode(ctx.excel);
    } on ParsingException {
      rethrow;
    } catch (e, st) {
      _logger.error('Error al actualizar celda en bytes', e, st);
      throw const ParsingException('Error al actualizar el valor');
    }
  }

  @override
  Uint8List renameClientBytes(Uint8List bytes, String oldName, String newName) {
    try {
      final ctx = _decodeExcel(bytes);
      final clientRowIdx = _findClientRow(
        ctx.sheet,
        ctx.headerRowIdx,
        ctx.clientCol,
        oldName,
      );

      ctx.sheet.updateCell(
        xl.CellIndex.indexByColumnRow(
          columnIndex: ctx.clientCol,
          rowIndex: clientRowIdx,
        ),
        xl.TextCellValue(newName),
      );

      return _encode(ctx.excel);
    } on ParsingException {
      rethrow;
    } catch (e, st) {
      _logger.error('Error al renombrar cliente en bytes', e, st);
      throw const ParsingException('Error al renombrar el cliente');
    }
  }

  @override
  Uint8List addRowBytes(Uint8List bytes, String clientName) {
    try {
      final ctx = _decodeExcel(bytes);
      final newRowIdx = ctx.sheet.rows.length;
      ctx.sheet.updateCell(
        xl.CellIndex.indexByColumnRow(
          columnIndex: ctx.clientCol,
          rowIndex: newRowIdx,
        ),
        xl.TextCellValue(clientName),
      );

      return _encode(ctx.excel);
    } on ParsingException {
      rethrow;
    } catch (e, st) {
      _logger.error('Error al añadir fila en bytes', e, st);
      throw const ParsingException('Error al añadir la fila');
    }
  }

  @override
  Uint8List deleteRowsBytes(Uint8List bytes, Set<String> clientNames) {
    try {
      final ctx = _decodeExcel(bytes);

      final rowsToDelete = <int>[];
      for (var r = ctx.headerRowIdx + 1; r < ctx.sheet.rows.length; r++) {
        final row = ctx.sheet.rows[r];
        if (ctx.clientCol < row.length &&
            row[ctx.clientCol] != null &&
            clientNames.contains(row[ctx.clientCol]!.value.toString())) {
          rowsToDelete.add(r);
        }
      }

      for (final rowIdx in rowsToDelete.reversed) {
        ctx.sheet.removeRow(rowIdx);
      }

      return _encode(ctx.excel);
    } on ParsingException {
      rethrow;
    } catch (e, st) {
      _logger.error('Error al eliminar filas en bytes', e, st);
      throw const ParsingException('Error al eliminar las filas');
    }
  }
}
