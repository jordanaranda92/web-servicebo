import '../../domain/entities/order_sheet.dart';
import '../models/order_document_model.dart';
import '../models/order_row_model.dart';

/// Builds an [OrderSheet] from Firestore models and name resolution maps.
///
/// Shared between `OrdersTodayRepositoryImpl` and
/// `OrdersHistoryRepositoryImpl` to avoid duplication.
OrderSheet buildOrderSheet(
  OrderDocumentModel doc,
  List<OrderRowModel> rows,
  Map<String, String> clientNameMap,
  Map<String, String> productNameMap,
  Map<String, int?> productOrderMap,
) {
  final clientIds = List<String>.from(doc.clientIds);
  final productIds = _sortIdsByOrder(doc.productIds, productOrderMap);

  // Build a map of productId → OrderRowModel for ordered access
  final rowMap = {for (final r in rows) r.productId: r};

  final clientNames = clientIds.map((id) => clientNameMap[id] ?? id).toList();
  final productNames = productIds
      .map((id) => productNameMap[id] ?? id)
      .toList();

  final quantities = <List<num>>[];
  final pedidos = <num>[];
  final stocks = <num>[];
  final quedan = <num>[];
  final cellFlags = <Map<String, String>>[];
  final strictStocks = <bool>[];
  final cellNotes = <Map<String, String>>[];
  final cellRefunds = <Map<String, num>>[];

  for (final productId in productIds) {
    final row = rowMap[productId];
    final rowQuantities = <num>[];

    for (final clientId in clientIds) {
      rowQuantities.add(row?.quantities[clientId] ?? 0);
    }

    quantities.add(rowQuantities);
    final totalPedidos = rowQuantities.fold<num>(0, (a, b) => a + b);
    final totalRefunds = (row?.refunds ?? {}).values.fold<num>(
      0,
      (a, b) => a + b,
    );
    final stock = row?.stock ?? 0;
    pedidos.add(totalPedidos + totalRefunds);
    stocks.add(stock);
    quedan.add(stock - (totalPedidos + totalRefunds));
    cellFlags.add(row?.flags ?? {});
    strictStocks.add(row?.strictStock ?? false);
    cellNotes.add(row?.notes ?? {});
    cellRefunds.add(row?.refunds ?? {});
  }

  return OrderSheet(
    date: doc.date,
    clients: clientNames,
    products: productNames,
    clientIds: clientIds,
    productIds: productIds,
    quantities: quantities,
    pedidos: pedidos,
    stocks: stocks,
    quedan: quedan,
    cellFlags: cellFlags,
    strictStocks: strictStocks,
    cellNotes: cellNotes,
    cellRefunds: cellRefunds,
    clientOrders: List.generate(clientIds.length, (i) => i + 1),
    invoicedBy: {
      for (final entry in doc.invoicedBy.entries)
        entry.key: InvoicedByInfo(
          userId: entry.value['userId'] ?? '',
          userName: entry.value['userName'] ?? '',
          color: entry.value['color'] ?? '',
        ),
    },
    lastModifiedAt: doc.lastModifiedAt,
  );
}

/// Fallback order value for items without an explicit sort position.
const defaultSortOrder = 9999;

/// Sorts [ids] by the `order` field from [orderMap], falling back to
/// [defaultSortOrder].
List<String> _sortIdsByOrder(List<String> ids, Map<String, int?> orderMap) {
  return List<String>.from(ids)..sort(
    (a, b) => (orderMap[a] ?? defaultSortOrder).compareTo(
      orderMap[b] ?? defaultSortOrder,
    ),
  );
}
