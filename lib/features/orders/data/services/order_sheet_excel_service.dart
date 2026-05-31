import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/order_sheet.dart';
import '../../domain/services/order_sheet_excel_generator.dart';

/// Colores de fondo para celdas con flags.
const _colorReservation = 'FFBBDEFB'; // Azul claro
const _colorCompensation = 'FFC8E6C9'; // Verde claro
const _colorQuedanNegative = 'FFEF9A9A'; // Rojo claro (quedan negativo)
const _colorQuedanPositive = 'FFC8E6C9'; // Verde claro (quedan >= 0)
const _colorPedidos = 'FFF5F0C0'; // Amarillo crema (PEDIDOS)
const _colorHeaderProduct = 'FF37474F'; // Azul gris (col producto)
const _colorHeaderPedidos = 'FF6A5ACD'; // Morado (PEDIDOS)
const _colorHeaderStocks = 'FFD32F2F'; // Rojo (STOCKS)
const _colorHeaderQuedan = 'FF00ACC1'; // Azul cyan (QUEDAN)

class OrderSheetExcelService implements OrderSheetExcelGenerator {
  /// Genera el archivo .xlsx en memoria para el [orderSheet] dado.
  /// Retorna los bytes del archivo listos para guardar.
  @override
  Future<Uint8List> generate({
    required OrderSheet orderSheet,
    required String sheetName,
  }) async {
    final excel = Excel.createExcel();

    // Crear la hoja destino primero; luego eliminar la hoja por defecto.
    // El orden importa: no se puede eliminar la única hoja existente.
    final sheet = excel[sheetName];
    excel.delete('Sheet1');

    // Formatear cabecera de fecha: "SÁBADO , 28\nMARZO"
    final date = DateTime.tryParse(orderSheet.date) ?? DateTime.now();
    final dayName = DateFormat('EEEE', 'es').format(date); // "lunes"
    final dayNameCapitalized =
        dayName[0].toUpperCase() + dayName.substring(1); // "Lunes"
    final day = DateFormat('d', 'es').format(date); // "11"
    final month = DateFormat('MMMM', 'es').format(date); // "mayo"
    final headerDateLabel = '$dayNameCapitalized,\n$day de $month';

    final numClients = orderSheet.clients.length;
    final pedidosCol = numClients + 1;
    final stocksCol = numClients + 2;
    final quedanCol = numClients + 3;

    // ── Fila 0: números de orden de cliente (encima de los nombres) ──
    _setCell(
      sheet,
      col: 0,
      row: 0,
      value: TextCellValue(''),
      bgColor: _colorHeaderProduct,
    );
    for (var c = 0; c < numClients; c++) {
      _setCell(
        sheet,
        col: c + 1,
        row: 0,
        value: IntCellValue(
          c < orderSheet.clientOrders.length
              ? orderSheet.clientOrders[c]
              : c + 1,
        ),
        bgColor: 'FFFFFFFF',
        bold: true,
        fontSize: 13,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
    // Celdas vacías en columnas resumen (fila 0) — sin sombreado
    for (final col in [pedidosCol, stocksCol, quedanCol]) {
      _setCell(sheet, col: col, row: 0, value: TextCellValue(''));
    }

    // ── Fila 1: nombres de clientes + etiquetas resumen ───────────
    _setCell(
      sheet,
      col: 0,
      row: 1,
      value: TextCellValue(headerDateLabel),
      bgColor: 'FFFFFFFF',
      bold: true,
      fontSize: 20,
      verticalAlign: VerticalAlign.Center,
      wrap: TextWrapping.WrapText,
    );

    for (var c = 0; c < numClients; c++) {
      _setCell(
        sheet,
        col: c + 1,
        row: 1,
        value: TextCellValue('  ${orderSheet.clients[c]}'),
        bgColor: 'FFFFFFFF',
        bold: true,
        rotation: 90,
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    _setCell(
      sheet,
      col: pedidosCol,
      row: 1,
      value: TextCellValue('  PEDIDOS'),
      bgColor: _colorHeaderPedidos,
      fontColor: 'FFFFFFFF',
      bold: true,
      rotation: 90,
      horizontalAlign: HorizontalAlign.Center,
    );
    _setCell(
      sheet,
      col: stocksCol,
      row: 1,
      value: TextCellValue('  STOCKS'),
      bgColor: _colorHeaderStocks,
      fontColor: 'FFFFFFFF',
      bold: true,
      rotation: 90,
      horizontalAlign: HorizontalAlign.Center,
    );
    _setCell(
      sheet,
      col: quedanCol,
      row: 1,
      value: TextCellValue('  QUEDAN'),
      bgColor: _colorHeaderQuedan,
      fontColor: 'FFFFFFFF',
      bold: true,
      rotation: 90,
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Filas de producto ─────────────────────────────────────────
    for (var p = 0; p < orderSheet.products.length; p++) {
      final rowIdx = p + 2;

      // Col 0: nombre del producto
      _setCell(
        sheet,
        col: 0,
        row: rowIdx,
        value: TextCellValue(orderSheet.products[p]),
        bold: true,
        verticalAlign: VerticalAlign.Center,
      );

      // Celdas de cliente
      for (var c = 0; c < numClients; c++) {
        final clientId = c < orderSheet.clientIds.length
            ? orderSheet.clientIds[c]
            : '';

        final qty =
            (p < orderSheet.quantities.length &&
                c < orderSheet.quantities[p].length)
            ? orderSheet.quantities[p][c]
            : 0;

        final refund =
            (p < orderSheet.cellRefunds.length && clientId.isNotEmpty)
            ? (orderSheet.cellRefunds[p][clientId] ?? 0)
            : 0;

        final cellValue = (qty + refund).toDouble();

        final flag = (p < orderSheet.cellFlags.length && clientId.isNotEmpty)
            ? orderSheet.cellFlags[p][clientId]
            : null;

        String? bgColor;
        if (flag == 'reservation') {
          bgColor = _colorReservation;
        } else if (flag == 'compensation') {
          bgColor = _colorCompensation;
        }

        _setCell(
          sheet,
          col: c + 1,
          row: rowIdx,
          value: cellValue == 0
              ? TextCellValue('')
              : DoubleCellValue(cellValue),
          bgColor: bgColor,
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      // PEDIDOS
      final pedidos = p < orderSheet.pedidos.length ? orderSheet.pedidos[p] : 0;
      _setCell(
        sheet,
        col: pedidosCol,
        row: rowIdx,
        value: DoubleCellValue(pedidos.toDouble()),
        bgColor: _colorPedidos,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // STOCKS
      final stock = p < orderSheet.stocks.length ? orderSheet.stocks[p] : 0;
      final isStrict =
          p < orderSheet.strictStocks.length && orderSheet.strictStocks[p];
      _setCell(
        sheet,
        col: stocksCol,
        row: rowIdx,
        value: DoubleCellValue(stock.toDouble()),
        fontColor: isStrict ? 'FFFF0000' : 'FF000000',
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // QUEDAN
      final quedan = p < orderSheet.quedan.length ? orderSheet.quedan[p] : 0;
      _setCell(
        sheet,
        col: quedanCol,
        row: rowIdx,
        value: DoubleCellValue(quedan.toDouble()),
        bgColor: quedan < 0 ? _colorQuedanNegative : _colorQuedanPositive,
        bold: true,
        fontSize: 13,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // Ajustar anchura de columnas
    sheet.setColumnWidth(0, 30); // columna de productos
    for (var c = 1; c <= numClients; c++) {
      sheet.setColumnWidth(c, 5); // columnas de clientes
    }
    for (final col in [pedidosCol, stocksCol, quedanCol]) {
      sheet.setColumnWidth(col, 5); // columnas resumen
    }
    sheet.setRowHeight(0, 28); // fila de números más alta

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('excel.save() returned null');
    }
    return Uint8List.fromList(bytes);
  }

  void _setCell(
    Sheet sheet, {
    required int col,
    required int row,
    required CellValue value,
    String? bgColor,
    String fontColor = 'FF000000',
    bool bold = false,
    int? fontSize,
    int rotation = 0,
    HorizontalAlign horizontalAlign = HorizontalAlign.Left,
    VerticalAlign verticalAlign = VerticalAlign.Bottom,
    TextWrapping? wrap,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value;
    final border = Border(borderStyle: BorderStyle.Thin);
    cell.cellStyle = CellStyle(
      backgroundColorHex: bgColor != null
          ? ExcelColor.fromHexString(bgColor)
          : ExcelColor.none,
      fontColorHex: ExcelColor.fromHexString(fontColor),
      bold: bold,
      fontSize: fontSize,
      rotation: rotation,
      horizontalAlign: horizontalAlign,
      verticalAlign: verticalAlign,
      textWrapping: wrap,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
  }
}
