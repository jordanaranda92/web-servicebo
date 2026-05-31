import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/error/exceptions.dart';
import '../../../../../core/log/firebase_operations_logger.dart';
import '../../models/order_document_model.dart';
import '../../models/order_row_model.dart';
import 'order_firestore_data_source.dart';

class OrderFirestoreDataSourceImpl implements OrderFirestoreDataSource {
  OrderFirestoreDataSourceImpl(this._firestore, this._fbLogger);

  final FirebaseFirestore _firestore;
  final FirebaseOperationsLogger _fbLogger;

  DocumentReference<Map<String, dynamic>> _orderDoc(String date) =>
      _firestore.collection('orders').doc(date);

  CollectionReference<Map<String, dynamic>> _rowsCol(String date) =>
      _orderDoc(date).collection('rows');

  // ── exists ──────────────────────────────────────────────────────

  @override
  Future<bool> exists(String date) async {
    try {
      final snap = await _orderDoc(date).get();
      _fbLogger.logRead('orders', 1, snap.data());
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
      _fbLogger.logRead('orders', snap.exists ? 1 : 0, snap.data());
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
      _fbLogger.logRead(
        'orders/{date}/rows',
        snap.docs.length,
        snap.docs.map((d) => d.data()).toList(),
      );
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

      await batch.commit();
      _fbLogger.logBatchWrite(
        'orders + orders/{date}/rows',
        1 + productIds.length,
      );
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

      await batch.commit();
      _fbLogger.logBatchWrite('orders/{date}/rows + orders', 2);
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
      final batch = _firestore.batch();

      batch.update(_rowsCol(date).doc(productId), {'stock': value});
      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _fbLogger.logBatchWrite('orders/{date}/rows + orders', 2);
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
      final totalOps = 1 + productsToAdd.length + productsToRemove.length;
      _fbLogger.logBatchWrite('orders + orders/{date}/rows', totalOps);
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
        // Clean up client-level notes for removed clients
        for (final clientId in clientIds)
          'clientNotes.$clientId': FieldValue.delete(),
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

      await batch.commit();
      _fbLogger.logBatchWrite('orders + orders/{date}/rows', 1 + rows.length);
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

      await batch.commit();
      _fbLogger.logBatchWrite(
        'orders + orders/{date}/rows',
        1 + productIds.length,
      );
      _fbLogger.logDelete('orders/{date}/rows', productIds.length);
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
      _fbLogger.logWrite('orders', 1);
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

      await batch.commit();
      _fbLogger.logBatchWrite(
        'orders + orders/{date}/rows',
        1 + productIds.length,
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error adding products: $e');
    }
  }

  // ── watchOrderDocument ──────────────────────────────────────────

  @override
  Stream<OrderDocumentModel?> watchOrderDocument(String date) {
    return _orderDoc(date).snapshots().map((snap) {
      _fbLogger.logStreamRead('orders', snap.exists ? 1 : 0, snap.data());
      if (!snap.exists || snap.data() == null) return null;
      return OrderDocumentModel.fromFirestore(snap.id, snap.data()!);
    });
  }

  // ── watchOrderRows ──────────────────────────────────────────────

  @override
  Stream<List<OrderRowModel>> watchOrderRows(String date) {
    return _rowsCol(date).snapshots().map((snap) {
      _fbLogger.logStreamRead(
        'orders/{date}/rows',
        snap.docs.length,
        snap.docs.map((d) => d.data()).toList(),
      );
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

      await batch.commit();
      _fbLogger.logBatchWrite('orders/{date}/rows + orders', 2);
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

      await batch.commit();
      _fbLogger.logBatchWrite('orders/{date}/rows + orders', 2);
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
      _fbLogger.logBatchWrite('orders/{date}/rows + orders', 2);
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

      await batch.commit();
      _fbLogger.logBatchWrite('orders/{date}/rows + orders', 2);
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

      await batch.commit();
      _fbLogger.logBatchWrite('orders/{date}/rows + orders', rows.length + 1);
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
      _fbLogger.logWrite('orders', 1);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating invoicedBy: $e');
    }
  }

  // ── updateClientNote ────────────────────────────────────────────

  @override
  Future<void> updateClientNote({
    required String date,
    required String clientId,
    required String? note,
  }) async {
    try {
      if (note == null || note.isEmpty) {
        await _orderDoc(date).update({
          'clientNotes.$clientId': FieldValue.delete(),
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _orderDoc(date).update({
          'clientNotes.$clientId': note,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });
      }
      _fbLogger.logWrite('orders', 1);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating client note: $e');
    }
  }

  // ── replaceClient ───────────────────────────────────────────────

  @override
  Future<void> replaceClient({
    required String date,
    required String oldClientId,
    required String newClientId,
  }) async {
    try {
      final doc = await getOrderDocument(date);
      if (doc == null) {
        throw ServerException(message: 'Order document not found for $date');
      }

      // Validate newClientId is not already in clientIds
      if (doc.clientIds.contains(newClientId)) {
        throw ServerException(
          message: 'Client $newClientId already exists in order',
        );
      }

      // Replace oldClientId with newClientId in the same position
      final updatedClientIds = List<String>.from(doc.clientIds);
      final index = updatedClientIds.indexOf(oldClientId);
      if (index == -1) {
        throw ServerException(
          message: 'Client $oldClientId not found in order',
        );
      }
      updatedClientIds[index] = newClientId;

      final batch = _firestore.batch();

      // 1. Update root document: clientIds, clientNotes, invoicedBy
      final rootUpdates = <String, dynamic>{
        'clientIds': updatedClientIds,
        'lastModifiedAt': FieldValue.serverTimestamp(),
        // Remove invoicedBy for the old client
        'invoicedBy.$oldClientId': FieldValue.delete(),
      };

      // Transfer clientNote if it exists
      final oldNote = doc.clientNotes[oldClientId];
      if (oldNote != null && oldNote.isNotEmpty) {
        rootUpdates['clientNotes.$oldClientId'] = FieldValue.delete();
        rootUpdates['clientNotes.$newClientId'] = oldNote;
      } else {
        // Clean up in case there's an empty entry
        rootUpdates['clientNotes.$oldClientId'] = FieldValue.delete();
      }

      batch.update(_orderDoc(date), rootUpdates);

      // 2. Transfer data in all row subdocuments
      final rows = await getOrderRows(date);
      for (final row in rows) {
        final updates = <String, dynamic>{};

        if (row.quantities.containsKey(oldClientId)) {
          updates['quantities.$oldClientId'] = FieldValue.delete();
          updates['quantities.$newClientId'] = row.quantities[oldClientId];
        }
        if (row.flags.containsKey(oldClientId)) {
          updates['flags.$oldClientId'] = FieldValue.delete();
          updates['flags.$newClientId'] = row.flags[oldClientId];
        }
        if (row.notes.containsKey(oldClientId)) {
          updates['notes.$oldClientId'] = FieldValue.delete();
          updates['notes.$newClientId'] = row.notes[oldClientId];
        }
        if (row.refunds.containsKey(oldClientId)) {
          updates['refunds.$oldClientId'] = FieldValue.delete();
          updates['refunds.$newClientId'] = row.refunds[oldClientId];
        }

        if (updates.isNotEmpty) {
          batch.update(_rowsCol(date).doc(row.productId), updates);
        }
      }

      await batch.commit();
      _fbLogger.logBatchWrite('orders + orders/{date}/rows', 1 + rows.length);
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error replacing client: $e');
    }
  }
}
