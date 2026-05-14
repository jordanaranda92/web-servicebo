import 'dart:typed_data';

/// Data class for a row in the PDF.
class OrderSheetPdfRow {
  final String product;
  final String quantity;
  final String? notes;

  const OrderSheetPdfRow({
    required this.product,
    required this.quantity,
    this.notes,
  });
}

/// Contract for generating PDF files from order data.
abstract class OrderSheetPdfGenerator {
  Future<Uint8List> generate({
    required String clientName,
    required String dateTime,
    required int orderNumber,
    required List<OrderSheetPdfRow> rows,
    String? shippingMethod,
  });
}
