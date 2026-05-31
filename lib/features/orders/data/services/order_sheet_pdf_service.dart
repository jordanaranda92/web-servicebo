import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/services/order_sheet_pdf_generator.dart';

class OrderSheetPdfService implements OrderSheetPdfGenerator {
  @override
  Future<Uint8List> generate({
    required String clientName,
    required String dateTime,
    required int orderNumber,
    required List<OrderSheetPdfRow> rows,
    required OrderSheetPdfLabels labels,
    String? shippingMethod,
    int? totalProducts,
    String? subtotal,
  }) async {
    final pdf = pw.Document();

    final clientNameStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 18,
    );
    final headerLabelStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 11,
    );
    final headerValueStyle = const pw.TextStyle(fontSize: 11);

    final summaryLabelStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 13,
    );
    final summaryValueStyle = const pw.TextStyle(fontSize: 13);

    final tableHeaderStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
      color: PdfColors.white,
    );
    const tableHeaderColor = PdfColor.fromInt(0xFF37474F); // Blue Grey 800
    const zebraLight = PdfColor.fromInt(0xFFF5F5F5); // Grey 100

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ── Header table ──────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(3),
            },
            children: [
              _headerRow(
                labels.client,
                clientName,
                headerLabelStyle,
                clientNameStyle,
              ),
              _headerRow(
                labels.dateTime,
                dateTime,
                headerLabelStyle,
                headerValueStyle,
              ),
              _headerRow(
                labels.orderNumber,
                '$orderNumber',
                headerLabelStyle,
                headerValueStyle,
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Products table ────────────────────────────────────
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: tableHeaderStyle,
            headerDecoration: const pw.BoxDecoration(color: tableHeaderColor),
            headerPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            oddRowDecoration: const pw.BoxDecoration(color: zebraLight),
            headers: [labels.product, labels.quantity, labels.notes],
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
            },
            data: rows
                .map((r) => [r.product, r.quantity, r.notes ?? ''])
                .toList(),
          ),

          // ── Summary rows (shipping, total, subtotal) ────────────
          if (shippingMethod != null ||
              totalProducts != null ||
              subtotal != null) ...[
            pw.SizedBox(height: 24),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(2.5),
              },
              children: [
                if (shippingMethod != null)
                  _headerRow(
                    labels.shippingMethod,
                    shippingMethod,
                    summaryLabelStyle,
                    summaryValueStyle,
                  ),
                if (totalProducts != null)
                  _headerRow(
                    labels.totalProducts,
                    '$totalProducts',
                    summaryLabelStyle,
                    summaryValueStyle,
                  ),
                if (subtotal != null)
                  _headerRow(
                    labels.subtotal,
                    subtotal,
                    summaryLabelStyle,
                    summaryValueStyle,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.TableRow _headerRow(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(),
      children: [
        pw.Container(
          color: const PdfColor.fromInt(0xFFE0E0E0), // Grey 300
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(label, style: labelStyle),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(value, style: valueStyle),
        ),
      ],
    );
  }
}
