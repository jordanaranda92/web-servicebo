import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/auth/current_user_provider.dart';
import '../../../../../core/error/exceptions.dart';
import '../../models/order_action_entry_model.dart';
import '../../models/order_document_model.dart';
import '../../models/order_row_model.dart';
import 'order_firestore_data_source.dart';

class OrderFirestoreDataSourceImpl implements OrderFirestoreDataSource {
  OrderFirestoreDataSourceImpl(this._firestore, this._userProvider);

  final FirebaseFirestore _firestore;
  final CurrentUserProvider _userProvider;

  DocumentReference<Map<String, dynamic>> _orderDoc(String date) =>
      _firestore.collection('orders').doc(date);

  CollectionReference<Map<String, dynamic>> _rowsCol(String date) =>
      _orderDoc(date).collection('rows');

  CollectionReference<Map<String, dynamic>> _historyCol(String date) =>
      _orderDoc(date).collection('history');

  /// Appends a history entry to the batch. Best-effort: silently skipped
  /// if user info is unavailable.
  void _addHistoryToBatch({
    required WriteBatch batch,
    required String date,
    required String actionType,
    Map<String, String> details = const {},
  }) {
    try {
      final user = _userProvider.currentUser;
      if (user == null) return;
      batch.set(_historyCol(date).doc(), {
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'actionType': actionType,
        'details': details,
      });
    } on Exception {
      // Best-effort: do not break the main operation
    }
  }

  // ── exists ──────────────────────────────────────────────────────

  @override
  Future<bool> exists(String date) async {
    try {
      final snap = await _orderDoc(date).get();
      return snap.exists;
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error checking order existence: $e');
    }
  }

  // ── getOrderDocument ────────────────────────────────────────────

  @override
  Future<OrderDocumentModel?> getOrderDocument(String date) async {
    try {
      final snap = await _orderDoc(date).get();
      if (!snap.exists || snap.data() == null) return null;
      return OrderDocumentModel.fromFirestore(snap.id, snap.data()!);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading order document: $e');
    }
  }

  // ── getOrderRows ────────────────────────────────────────────────

  @override
  Future<List<OrderRowModel>> getOrderRows(String date) async {
    try {
      final snap = await _rowsCol(date).get();
      return snap.docs
          .map((doc) => OrderRowModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading order rows: $e');
    }
  }

  // ── createOrder ─────────────────────────────────────────────────

  @override
  Future<void> createOrder({
    required String date,
    required List<String> clientIds,
    required List<String> productIds,
  }) async {
    try {
      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      // Root document
      batch.set(_orderDoc(date), {
        'createdAt': now,
        'lastModifiedAt': now,
        'clientIds': clientIds,
        'productIds': productIds,
      }, SetOptions(merge: true));

      // Row subdocuments — one per product
      for (final productId in productIds) {
        batch.set(_rowsCol(date).doc(productId), {
          'quantities': <String, dynamic>{},
          'stock': 0,
        }, SetOptions(merge: true));
      }

      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'orderSheetCreated',
        details: {
          'clientCount': clientIds.length.toString(),
          'productCount': productIds.length.toString(),
        },
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error creating order: $e');
    }
  }

  // ── updateQuantity ──────────────────────────────────────────────

  @override
  Future<void> updateQuantity({
    required String date,
    required String productId,
    required String clientId,
    required num value,
  }) async {
    try {
      // Read old value before writing
      final rowSnap = await _rowsCol(date).doc(productId).get();
      final quantities =
          rowSnap.data()?['quantities'] as Map<String, dynamic>? ?? {};
      final oldValue = (quantities[clientId] as num?) ?? 0;

      final batch = _firestore.batch();

      // Update the specific quantity field (sparse: delete if 0)
      if (value == 0) {
        batch.update(_rowsCol(date).doc(productId), {
          'quantities.$clientId': FieldValue.delete(),
        });
      } else {
        batch.update(_rowsCol(date).doc(productId), {
          'quantities.$clientId': value,
        });
      }

      // Update lastModifiedAt on root
      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'quantityChanged',
        details: {
          'productId': productId,
          'clientId': clientId,
          'oldValue': oldValue.toString(),
          'newValue': value.toString(),
        },
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating quantity: $e');
    }
  }

  // ── updateStock ─────────────────────────────────────────────────

  @override
  Future<void> updateStock({
    required String date,
    required String productId,
    required num value,
  }) async {
    try {
      // Read old value before writing
      final rowSnap = await _rowsCol(date).doc(productId).get();
      final oldValue = (rowSnap.data()?['stock'] as num?) ?? 0;

      final batch = _firestore.batch();

      batch.update(_rowsCol(date).doc(productId), {'stock': value});
      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'stockChanged',
        details: {
          'productId': productId,
          'oldValue': oldValue.toString(),
          'newValue': value.toString(),
        },
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating stock: $e');
    }
  }

  // ── syncActiveEntities ──────────────────────────────────────────

  @override
  Future<bool> syncActiveEntities({
    required String date,
    required List<String> activeClientIds,
    required List<String> activeProductIds,
  }) async {
    try {
      final doc = await getOrderDocument(date);
      if (doc == null) return false;

      final currentClientIds = Set<String>.from(doc.clientIds);
      final currentProductIds = Set<String>.from(doc.productIds);
      final activeClients = Set<String>.from(activeClientIds);
      final activeProducts = Set<String>.from(activeProductIds);

      // Detect changes
      final clientsToAdd = activeClients.difference(currentClientIds);
      final clientsToRemove = currentClientIds.difference(activeClients);
      final productsToAdd = activeProducts.difference(currentProductIds);
      final productsToRemove = currentProductIds.difference(activeProducts);

      if (clientsToAdd.isEmpty &&
          clientsToRemove.isEmpty &&
          productsToAdd.isEmpty &&
          productsToRemove.isEmpty) {
        return false;
      }

      final batch = _firestore.batch();

      // Update root document with new lists (preserving order from active lists)
      batch.update(_orderDoc(date), {
        'clientIds': activeClientIds,
        'productIds': activeProductIds,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // Remove quantities for removed clients from all existing rows
      if (clientsToRemove.isNotEmpty) {
        final existingRows = await getOrderRows(date);
        for (final row in existingRows) {
          final updates = <String, dynamic>{};
          for (final clientId in clientsToRemove) {
            if (row.quantities.containsKey(clientId)) {
              updates['quantities.$clientId'] = FieldValue.delete();
            }
          }
          if (updates.isNotEmpty) {
            batch.update(_rowsCol(date).doc(row.productId), updates);
          }
        }
      }

      // Create row subdocuments for new products
      for (final productId in productsToAdd) {
        batch.set(_rowsCol(date).doc(productId), {
          'quantities': <String, dynamic>{},
          'stock': 0,
        });
      }

      // Delete row subdocuments for removed products
      for (final productId in productsToRemove) {
        batch.delete(_rowsCol(date).doc(productId));
      }

      await batch.commit();
      return true;
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error syncing active entities: $e');
    }
  }

  // ── removeClients ───────────────────────────────────────────────

  @override
  Future<void> removeClients({
    required String date,
    required List<String> clientIds,
  }) async {
    try {
      final doc = await getOrderDocument(date);
      if (doc == null) return;

      final updatedClientIds = doc.clientIds
          .where((id) => !clientIds.contains(id))
          .toList();

      final batch = _firestore.batch();

      // Update root document
      batch.update(_orderDoc(date), {
        'clientIds': updatedClientIds,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // Remove quantities, flags, notes and refunds for these clients from all rows
      final rows = await getOrderRows(date);
      for (final row in rows) {
        final updates = <String, dynamic>{};
        for (final clientId in clientIds) {
          if (row.quantities.containsKey(clientId)) {
            updates['quantities.$clientId'] = FieldValue.delete();
          }
          if (row.flags.containsKey(clientId)) {
            updates['flags.$clientId'] = FieldValue.delete();
          }
          if (row.notes.containsKey(clientId)) {
            updates['notes.$clientId'] = FieldValue.delete();
          }
          if (row.refunds.containsKey(clientId)) {
            updates['refunds.$clientId'] = FieldValue.delete();
          }
        }
        if (updates.isNotEmpty) {
          batch.update(_rowsCol(date).doc(row.productId), updates);
        }
      }

      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'clientsRemoved',
        details: {'clientIds': clientIds.join(',')},
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error removing clients: $e');
    }
  }

  // ── removeProducts ──────────────────────────────────────────────

  @override
  Future<void> removeProducts({
    required String date,
    required List<String> productIds,
  }) async {
    try {
      final doc = await getOrderDocument(date);
      if (doc == null) return;

      final updatedProductIds = doc.productIds
          .where((id) => !productIds.contains(id))
          .toList();

      final batch = _firestore.batch();

      // Update root document
      batch.update(_orderDoc(date), {
        'productIds': updatedProductIds,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // Delete row subdocuments
      for (final productId in productIds) {
        batch.delete(_rowsCol(date).doc(productId));
      }

      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'productsRemoved',
        details: {'productIds': productIds.join(',')},
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error removing products: $e');
    }
  }

  // ── addClients ──────────────────────────────────────────────────

  @override
  Future<void> addClients({
    required String date,
    required List<String> clientIds,
  }) async {
    try {
      final doc = await getOrderDocument(date);
      if (doc == null) return;

      final updatedClientIds = [...doc.clientIds, ...clientIds];

      await _orderDoc(date).update({
        'clientIds': updatedClientIds,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // History entry (standalone, not in batch)
      await addHistoryEntry(
        date: date,
        actionType: 'clientsAdded',
        userId: _userProvider.currentUser?.uid ?? '',
        details: {'clientIds': clientIds.join(',')},
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error adding clients: $e');
    }
  }

  // ── addProducts ─────────────────────────────────────────────────

  @override
  Future<void> addProducts({
    required String date,
    required List<String> productIds,
  }) async {
    try {
      final doc = await getOrderDocument(date);
      if (doc == null) return;

      final updatedProductIds = [...doc.productIds, ...productIds];

      final batch = _firestore.batch();

      batch.update(_orderDoc(date), {
        'productIds': updatedProductIds,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // Create empty row subdocuments for new products
      for (final productId in productIds) {
        batch.set(_rowsCol(date).doc(productId), {
          'quantities': <String, dynamic>{},
          'stock': 0,
        });
      }

      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'productsAdded',
        details: {'productIds': productIds.join(',')},
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error adding products: $e');
    }
  }

  // ── watchOrderDocument ──────────────────────────────────────────

  @override
  Stream<OrderDocumentModel?> watchOrderDocument(String date) {
    return _orderDoc(date).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return OrderDocumentModel.fromFirestore(snap.id, snap.data()!);
    });
  }

  // ── watchOrderRows ──────────────────────────────────────────────

  @override
  Stream<List<OrderRowModel>> watchOrderRows(String date) {
    return _rowsCol(date).snapshots().map((snap) {
      return snap.docs
          .map((doc) => OrderRowModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  // ── updateFlag ──────────────────────────────────────────────────

  @override
  Future<void> updateFlag({
    required String date,
    required String productId,
    required String clientId,
    required String? flagType,
  }) async {
    try {
      final batch = _firestore.batch();

      if (flagType == null) {
        batch.update(_rowsCol(date).doc(productId), {
          'flags.$clientId': FieldValue.delete(),
        });
      } else {
        batch.update(_rowsCol(date).doc(productId), {
          'flags.$clientId': flagType,
        });
      }

      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      final String historyAction;
      if (flagType == null) {
        historyAction = 'compensationUnmarked'; // generic unmark
      } else if (flagType == 'compensation') {
        historyAction = 'compensationMarked';
      } else {
        historyAction = 'reservationMarked';
      }
      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: historyAction,
        details: {
          'productId': productId,
          'clientId': clientId,
          if (flagType != null) 'flagType': flagType,
        },
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating flag: $e');
    }
  }

  // ── updateStrictStock ───────────────────────────────────────────

  @override
  Future<void> updateStrictStock({
    required String date,
    required String productId,
    required bool strictStock,
  }) async {
    try {
      final batch = _firestore.batch();

      batch.update(_rowsCol(date).doc(productId), {'strictStock': strictStock});

      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: strictStock ? 'strictStockMarked' : 'strictStockUnmarked',
        details: {'productId': productId},
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating strict stock: $e');
    }
  }

  // ── updateNote ──────────────────────────────────────────────────

  @override
  Future<void> updateNote({
    required String date,
    required String productId,
    required String clientId,
    required String? note,
  }) async {
    try {
      final batch = _firestore.batch();

      if (note == null || note.isEmpty) {
        batch.update(_rowsCol(date).doc(productId), {
          'notes.$clientId': FieldValue.delete(),
        });
      } else {
        batch.update(_rowsCol(date).doc(productId), {'notes.$clientId': note});
      }

      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating note: $e');
    }
  }

  // ── updateRefund ────────────────────────────────────────────────

  @override
  Future<void> updateRefund({
    required String date,
    required String productId,
    required String clientId,
    required num? quantity,
  }) async {
    try {
      final batch = _firestore.batch();

      if (quantity == null || quantity <= 0) {
        batch.update(_rowsCol(date).doc(productId), {
          'refunds.$clientId': FieldValue.delete(),
        });
      } else {
        batch.update(_rowsCol(date).doc(productId), {
          'refunds.$clientId': quantity,
        });
      }

      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      final String refundAction;
      if (quantity == null || quantity <= 0) {
        refundAction = 'refundRemoved';
      } else {
        refundAction = 'refundAdded';
      }
      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: refundAction,
        details: {
          'productId': productId,
          'clientId': clientId,
          if (quantity != null && quantity > 0) 'quantity': quantity.toString(),
        },
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating refund: $e');
    }
  }

  // ── resetClientOrders ───────────────────────────────────────────

  @override
  Future<void> resetClientOrders({
    required String date,
    required List<String> clientIds,
  }) async {
    try {
      final rows = await getOrderRows(date);
      final batch = _firestore.batch();

      for (final row in rows) {
        final updates = <String, dynamic>{};
        for (final clientId in clientIds) {
          if (row.quantities.containsKey(clientId)) {
            updates['quantities.$clientId'] = 0;
          }
          if (row.flags.containsKey(clientId)) {
            updates['flags.$clientId'] = FieldValue.delete();
          }
          if (row.notes.containsKey(clientId)) {
            updates['notes.$clientId'] = FieldValue.delete();
          }
          if (row.refunds.containsKey(clientId)) {
            updates['refunds.$clientId'] = FieldValue.delete();
          }
        }
        if (updates.isNotEmpty) {
          batch.update(_rowsCol(date).doc(row.productId), updates);
        }
      }

      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'ordersReset',
        details: {'clientIds': clientIds.join(',')},
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error resetting client orders: $e');
    }
  }

  // ── updateInvoicedBy ────────────────────────────────────────────

  @override
  Future<void> updateInvoicedBy({
    required String date,
    required String clientId,
    required String userId,
    required String userName,
    required String color,
  }) async {
    try {
      await _orderDoc(date).update({
        'invoicedBy.$clientId': {
          'userId': userId,
          'userName': userName,
          'color': color,
        },
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      // History entry (standalone)
      await addHistoryEntry(
        date: date,
        actionType: 'provisionalInvoiceGenerated',
        userId: userId,
        details: {'clientId': clientId},
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating invoicedBy: $e');
    }
  }

  // ── getAllOrderDocuments ─────────────────────────────────────────

  @override
  Future<List<OrderDocumentModel>> getAllOrderDocuments() async {
    try {
      final snap = await _firestore.collection('orders').get();
      return snap.docs
          .map((doc) => OrderDocumentModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error listing order documents: $e');
    }
  }

  // ── Action History ────────────────────────────────────────────────

  @override
  Future<void> addHistoryEntry({
    required String date,
    required String actionType,
    required String userId,
    required Map<String, String> details,
  }) async {
    try {
      if (userId.isEmpty) return;
      await _historyCol(date).doc().set({
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'actionType': actionType,
        'details': details,
      });
    } on FirebaseException {
      // Best-effort: do not throw
    }
  }

  @override
  Future<List<OrderActionEntryModel>> getHistory(String date) async {
    try {
      final snap = await _historyCol(
        date,
      ).orderBy('timestamp', descending: true).get();
      return snap.docs
          .map((doc) => OrderActionEntryModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading history: $e');
    }
  }
}
