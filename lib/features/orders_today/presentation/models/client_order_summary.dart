import '../../domain/entities/order_sheet.dart';

/// View-model for a single client's order in the mobile cards view.
class ClientOrderSummary {
  final int orderNumber;
  final String clientName;
  final String clientId;

  /// Sum of all quantities + all refunds for this client.
  final num totalProducts;
  final List<ProductLineItem> products;

  const ClientOrderSummary({
    required this.orderNumber,
    required this.clientName,
    required this.clientId,
    required this.totalProducts,
    required this.products,
  });
}

/// A single product line within a client's expanded card.
class ProductLineItem {
  final String productName;
  final num quantity;

  /// `"reservation"`, `"compensation"`, or `null`.
  final String? flag;

  /// Refund quantity, or `null` if none.
  final num? refund;

  /// Cell note text, or `null` if none.
  final String? note;

  const ProductLineItem({
    required this.productName,
    required this.quantity,
    this.flag,
    this.refund,
    this.note,
  });
}

/// Transforms an [OrderSheet] (product×client matrix) into a list of
/// [ClientOrderSummary] (client-oriented), filtering out clients and
/// products with no relevant data.
///
/// The returned list is sorted by [ClientOrderSummary.orderNumber] ascending.
List<ClientOrderSummary> buildClientSummaries(OrderSheet sheet) {
  final summaries = <ClientOrderSummary>[];

  for (var c = 0; c < sheet.clients.length; c++) {
    final clientId = c < sheet.clientIds.length ? sheet.clientIds[c] : '';
    final lineItems = <ProductLineItem>[];
    num totalQty = 0;
    num totalRefund = 0;

    for (var p = 0; p < sheet.products.length; p++) {
      // Quantity
      final qty =
          (p < sheet.quantities.length && c < sheet.quantities[p].length)
          ? sheet.quantities[p][c]
          : 0;

      // Flag
      final flag = (p < sheet.cellFlags.length && clientId.isNotEmpty)
          ? sheet.cellFlags[p][clientId]
          : null;

      // Refund
      final refundRaw = (p < sheet.cellRefunds.length && clientId.isNotEmpty)
          ? sheet.cellRefunds[p][clientId]
          : null;
      final refund = (refundRaw != null && refundRaw > 0) ? refundRaw : null;

      // Note
      final noteRaw = (p < sheet.cellNotes.length && clientId.isNotEmpty)
          ? sheet.cellNotes[p][clientId]
          : null;
      final note = (noteRaw != null && noteRaw.isNotEmpty) ? noteRaw : null;

      // Include product if it has any relevant data
      final hasData = qty > 0 || flag != null || refund != null || note != null;
      if (!hasData) continue;

      totalQty += qty;
      if (refund != null) totalRefund += refund;

      lineItems.add(
        ProductLineItem(
          productName: sheet.products[p],
          quantity: qty,
          flag: flag,
          refund: refund,
          note: note,
        ),
      );
    }

    if (lineItems.isEmpty) continue;

    summaries.add(
      ClientOrderSummary(
        orderNumber: c < sheet.clientOrders.length
            ? sheet.clientOrders[c]
            : c + 1,
        clientName: sheet.clients[c],
        clientId: clientId,
        totalProducts: totalQty + totalRefund,
        products: lineItems,
      ),
    );
  }

  summaries.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
  return summaries;
}
