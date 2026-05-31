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

/// Localized labels used in the PDF layout.
class OrderSheetPdfLabels {
  final String client;
  final String dateTime;
  final String orderNumber;
  final String product;
  final String quantity;
  final String notes;
  final String shippingMethod;
  final String totalProducts;
  final String subtotal;

  const OrderSheetPdfLabels({
    required this.client,
    required this.dateTime,
    required this.orderNumber,
    required this.product,
    required this.quantity,
    required this.notes,
    required this.shippingMethod,
    required this.totalProducts,
    required this.subtotal,
  });
}

/// Contract for generating PDF files from order data.
abstract class OrderSheetPdfGenerator {
  Future<Uint8List> generate({
    required String clientName,
    required String dateTime,
    required int orderNumber,
    required List<OrderSheetPdfRow> rows,
    required OrderSheetPdfLabels labels,
    String? shippingMethod,
    int? totalProducts,
    String? subtotal,
  });
}
