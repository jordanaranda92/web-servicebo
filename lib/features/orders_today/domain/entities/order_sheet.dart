import 'package:equatable/equatable.dart';

class OrderSheet extends Equatable {
  /// Date string for this sheet (e.g. "2026-05-07").
  final String date;

  /// Client names (columns), sorted by order field.
  final List<String> clients;

  /// Product names (rows), sorted by order field.
  final List<String> products;

  /// Client Firestore IDs, sorted by order field (parallel to [clients]).
  final List<String> clientIds;

  /// Product Firestore IDs, sorted by order field (parallel to [products]).
  final List<String> productIds;

  /// Quantities matrix: `quantities[productIdx][clientIdx]`.
  final List<List<num>> quantities;

  /// PEDIDOS column — sum of all client quantities per product.
  final List<num> pedidos;

  /// STOCKS column — manually entered stock per product.
  final List<num> stocks;

  /// QUEDAN column — stocks minus pedidos per product.
  final List<num> quedan;

  /// Client order numbers shown in row 2.
  final List<int> clientOrders;

  /// Cell flags per product row: `cellFlags[productIdx]` is a sparse map
  /// `{clientId: flagType}` where flagType is `"compensation"` or `"reservation"`.
  final List<Map<String, String>> cellFlags;

  /// Whether each product's stock is marked as strict (cannot be exceeded).
  final List<bool> strictStocks;

  /// Cell notes per product row: `cellNotes[productIdx]` is a sparse map
  /// `{clientId: noteText}`. Only cells with a note are present.
  final List<Map<String, String>> cellNotes;

  /// Cell refunds per product row: `cellRefunds[productIdx]` is a sparse map
  /// `{clientId: quantity}`. Only cells with a refund are present.
  final List<Map<String, num>> cellRefunds;

  /// Map of clientId → invoiced-by info (userId, userName, color hex).
  /// Only clients with a generated provisional invoice are present.
  final Map<String, InvoicedByInfo> invoicedBy;

  /// Timestamp of the last modification from Firestore.
  final DateTime? lastModifiedAt;

  const OrderSheet({
    required this.date,
    required this.clients,
    required this.products,
    this.clientIds = const [],
    this.productIds = const [],
    required this.quantities,
    required this.pedidos,
    required this.stocks,
    required this.quedan,
    required this.clientOrders,
    this.cellFlags = const [],
    this.strictStocks = const [],
    this.cellNotes = const [],
    this.cellRefunds = const [],
    this.invoicedBy = const {},
    this.lastModifiedAt,
  });

  OrderSheet copyWith({
    String? date,
    List<String>? clients,
    List<String>? products,
    List<String>? clientIds,
    List<String>? productIds,
    List<List<num>>? quantities,
    List<num>? pedidos,
    List<num>? stocks,
    List<num>? quedan,
    List<int>? clientOrders,
    List<Map<String, String>>? cellFlags,
    List<bool>? strictStocks,
    List<Map<String, String>>? cellNotes,
    List<Map<String, num>>? cellRefunds,
    Map<String, InvoicedByInfo>? invoicedBy,
    DateTime? lastModifiedAt,
  }) {
    return OrderSheet(
      date: date ?? this.date,
      clients: clients ?? this.clients,
      products: products ?? this.products,
      clientIds: clientIds ?? this.clientIds,
      productIds: productIds ?? this.productIds,
      quantities: quantities ?? this.quantities,
      pedidos: pedidos ?? this.pedidos,
      stocks: stocks ?? this.stocks,
      quedan: quedan ?? this.quedan,
      clientOrders: clientOrders ?? this.clientOrders,
      cellFlags: cellFlags ?? this.cellFlags,
      strictStocks: strictStocks ?? this.strictStocks,
      cellNotes: cellNotes ?? this.cellNotes,
      cellRefunds: cellRefunds ?? this.cellRefunds,
      invoicedBy: invoicedBy ?? this.invoicedBy,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }

  @override
  List<Object?> get props => [
    date,
    clients,
    products,
    clientIds,
    productIds,
    quantities,
    pedidos,
    stocks,
    quedan,
    clientOrders,
    cellFlags,
    strictStocks,
    cellNotes,
    cellRefunds,
    invoicedBy,
    lastModifiedAt,
  ];
}

/// Information about who generated a provisional invoice for a client.
class InvoicedByInfo extends Equatable {
  final String userId;
  final String userName;
  final String color;

  const InvoicedByInfo({
    required this.userId,
    required this.userName,
    required this.color,
  });

  @override
  List<Object?> get props => [userId, userName, color];
}
