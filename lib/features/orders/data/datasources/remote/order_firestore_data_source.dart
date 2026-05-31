import '../../models/order_document_model.dart';
import '../../models/order_row_model.dart';

/// Datasource for reading/writing today's orders in Firestore.
///
/// Collection structure:
/// ```
/// orders/{YYYY-MM-DD}              → OrderDocumentModel
/// orders/{YYYY-MM-DD}/rows/{id}    → OrderRowModel
/// ```
abstract class OrderFirestoreDataSource {
  /// Returns `true` if the order document for [date] exists.
  Future<bool> exists(String date);

  /// Reads the root order document for [date].
  /// Returns `null` if the document does not exist.
  Future<OrderDocumentModel?> getOrderDocument(String date);

  /// Reads all row subdocuments for the order at [date].
  Future<List<OrderRowModel>> getOrderRows(String date);

  /// Creates the root document and all row subdocuments atomically.
  Future<void> createOrder({
    required String date,
    required List<String> clientIds,
    required List<String> productIds,
  });

  /// Updates the quantity for a specific client–product pair.
  /// If [value] is 0, the entry is removed from the sparse map.
  /// Also updates `lastModifiedAt` on the root document.
  Future<void> updateQuantity({
    required String date,
    required String productId,
    required String clientId,
    required num value,
  });

  /// Updates the stock value for a product.
  /// Also updates `lastModifiedAt` on the root document.
  Future<void> updateStock({
    required String date,
    required String productId,
    required num value,
  });

  /// Synchronises the order document's `clientIds`/`productIds` and row
  /// subdocuments with the currently active clients and products.
  /// Returns `true` if any changes were applied.
  Future<bool> syncActiveEntities({
    required String date,
    required List<String> activeClientIds,
    required List<String> activeProductIds,
  });

  /// Removes the given [clientIds] from the order document and cleans up
  /// their quantities from all row subdocuments.
  Future<void> removeClients({
    required String date,
    required List<String> clientIds,
  });

  /// Removes the given [productIds] from the order document and deletes
  /// their row subdocuments.
  Future<void> removeProducts({
    required String date,
    required List<String> productIds,
  });

  /// Adds [clientIds] to the order document's client list.
  Future<void> addClients({
    required String date,
    required List<String> clientIds,
  });

  /// Adds [productIds] to the order document's product list and creates
  /// empty row subdocuments for each.
  Future<void> addProducts({
    required String date,
    required List<String> productIds,
  });

  /// Stream of real-time changes to the root order document for [date].
  Stream<OrderDocumentModel?> watchOrderDocument(String date);

  /// Stream of real-time changes to all row subdocuments for [date].
  Stream<List<OrderRowModel>> watchOrderRows(String date);

  /// Updates the flag for a specific client–product cell.
  /// If [flagType] is `null`, the flag is removed. Otherwise it is set to
  /// `"compensation"` or `"reservation"` (mutually exclusive — overwrites).
  Future<void> updateFlag({
    required String date,
    required String productId,
    required String clientId,
    required String? flagType,
  });

  /// Updates the strict-stock flag for a product row.
  Future<void> updateStrictStock({
    required String date,
    required String productId,
    required bool strictStock,
  });

  /// Updates a note for a specific client–product cell.
  /// If [note] is `null` or empty, the note is removed.
  Future<void> updateNote({
    required String date,
    required String productId,
    required String clientId,
    required String? note,
  });

  /// Updates a refund for a specific client–product cell.
  /// If [quantity] is `null` or <= 0, the refund is removed.
  Future<void> updateRefund({
    required String date,
    required String productId,
    required String clientId,
    required num? quantity,
  });

  /// Resets all quantities for the given [clientIds] to zero across all rows.
  Future<void> resetClientOrders({
    required String date,
    required List<String> clientIds,
  });

  /// Marks a client as invoiced by a user.
  Future<void> updateInvoicedBy({
    required String date,
    required String clientId,
    required String userId,
    required String userName,
    required String color,
  });

  /// Updates a client-level note on the root order document.
  /// If [note] is `null` or empty, the note is removed.
  Future<void> updateClientNote({
    required String date,
    required String clientId,
    required String? note,
  });

  /// Replaces [oldClientId] with [newClientId] in the order document and
  /// transfers all associated data (quantities, flags, notes, refunds,
  /// clientNotes) atomically. Removes any `invoicedBy` entry for the old
  /// client.
  Future<void> replaceClient({
    required String date,
    required String oldClientId,
    required String newClientId,
  });
}
