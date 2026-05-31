import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for the root document at `orders/{YYYY-MM-DD}`.
class OrderDocumentModel {
  final String date;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final List<String> clientIds;
  final List<String> productIds;

  /// Sparse map of clientId → invoiced-by metadata.
  final Map<String, Map<String, String>> invoicedBy;

  /// Sparse map of clientId → note text for client-level notes.
  final Map<String, String> clientNotes;

  const OrderDocumentModel({
    required this.date,
    required this.createdAt,
    required this.lastModifiedAt,
    required this.clientIds,
    required this.productIds,
    this.invoicedBy = const {},
    this.clientNotes = const {},
  });

  factory OrderDocumentModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    // Parse invoicedBy: {clientId: {userId, userName, color}}
    final rawInvoicedBy = data['invoicedBy'] as Map<String, dynamic>? ?? {};
    final invoicedBy = rawInvoicedBy.map(
      (key, value) => MapEntry(key, Map<String, String>.from(value as Map)),
    );

    final rawClientNotes = data['clientNotes'] as Map<String, dynamic>? ?? {};
    final clientNotes = rawClientNotes.map(
      (key, value) => MapEntry(key, value as String),
    );

    return OrderDocumentModel(
      date: id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastModifiedAt:
          (data['lastModifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientIds: List<String>.from(data['clientIds'] as List? ?? []),
      productIds: List<String>.from(data['productIds'] as List? ?? []),
      invoicedBy: invoicedBy,
      clientNotes: clientNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdAt': Timestamp.fromDate(createdAt),
      'lastModifiedAt': Timestamp.fromDate(lastModifiedAt),
      'clientIds': clientIds,
      'productIds': productIds,
    };
  }
}
