import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/auth/current_user_provider.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/log/firebase_operations_logger.dart';
import '../../models/order_action_entry_model.dart';
import '../../models/order_document_model.dart';
import '../../models/order_row_model.dart';
import 'order_firestore_data_source.dart';

class OrderFirestoreDataSourceImpl implements OrderFirestoreDataSource {
  OrderFirestoreDataSourceImpl(
    this._firestore,
    this._userProvider,
    this._fbLogger,
  );

  final FirebaseFirestore _firestore;
  final CurrentUserProvider _userProvider;
  final FirebaseOperationsLogger _fbLogger;

  DocumentReference<Map<String, dynamic>> _orderDoc(String date) =>
      _firestore.collection('orders').doc(date);

  CollectionReference<Map<String, dynamic>> _rowsCol(String date) =>
      _orderDoc(date).collection('rows');

  DocumentReference<Map<String, dynamic>> _historyDoc(String date) =>
      _orderDoc(date).collection('meta').doc('history');

  /// Maximum number of history entries stored per day.
  static const _maxHistoryEntries = 2000;

  /// Appends a history entry to the batch using a single document with
  /// an `entries` array. Reads the current array, prepends the new entry,
  /// and truncates to [_maxHistoryEntries] oldest-first.
  ///
  /// Best-effort: silently skipped if user info is unavailable.
  Future<void> _addHistoryToBatch({
    required WriteBatch batch,
    required String date,
    required String actionType,
    Map<String, String> details = const {},
  }) async {
    try {
      final user = _userProvider.currentUser;
      if (user == null) return;

      final docRef = _historyDoc(date);
      final snap = await docRef.get();
      final existing =
          (snap.data()?['entries'] as List<dynamic>?) ?? <dynamic>[];

      final newEntry = <String, dynamic>{
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'userId': user.uid,
        'userName': user.userName,
        'actionType': actionType,
        'details': details,
      };

      // Prepend (newest first) and truncate
      final updated = <dynamic>[newEntry, ...existing];
      if (updated.length > _maxHistoryEntries) {
        updated.removeRange(_maxHistoryEntries, updated.length);
      }

      batch.set(docRef, {'entries': updated});
    } on Exception {
      // Best-effort: do not break the main operation
    }
  }

  /// Resolves client/product names from Firestore and merges them into
  /// the details map. Call this **before** `_addHistoryToBatch` to
  /// denormalize names.
  Future<Map<String, String>> _enrichDetails(
    Map<String, String> details,
  ) async {
    final enriched = Map<String, String>.from(details);
    try {
      // Single clientId
      final clientId = details['clientId'];
      if (clientId != null && clientId.isNotEmpty) {
        final doc = await _firestore.collection('clients').doc(clientId).get();
        _fbLogger.logRead('clients', doc.exists ? 1 : 0, doc.data());
        final name = doc.data()?['name'] as String?;
        if (name != null) enriched['clientName'] = name;
      }
      // Comma-separated clientIds
      final clientIds = details['clientIds'];
      if (clientIds != null && clientIds.isNotEmpty) {
        final ids = clientIds.split(',').map((e) => e.trim()).toList();
        final names = <String>[];
        for (final id in ids) {
          final doc = await _firestore.collection('clients').doc(id).get();
          _fbLogger.logRead('clients', doc.exists ? 1 : 0, doc.data());
          final name = doc.data()?['name'] as String?;
          names.add(name ?? id);
        }
        enriched['clientNames'] = names.join(',');
      }
      // Single productId
      final productId = details['productId'];
      if (productId != null && productId.isNotEmpty) {
        final doc = await _firestore
            .collection('products')
            .doc(productId)
            .get();
        _fbLogger.logRead('products', doc.exists ? 1 : 0, doc.data());
        final name = doc.data()?['name'] as String?;
        if (name != null) enriched['productName'] = name;
      }
      // Comma-separated productIds
      final productIds = details['productIds'];
      if (productIds != null && productIds.isNotEmpty) {
        final ids = productIds.split(',').map((e) => e.trim()).toList();
        final names = <String>[];
        for (final id in ids) {
          final doc = await _firestore.collection('products').doc(id).get();
          _fbLogger.logRead('products', doc.exists ? 1 : 0, doc.data());
          final name = doc.data()?['name'] as String?;
          names.add(name ?? id);
        }
        enriched['productNames'] = names.join(',');
      }
    } on Exception {
      // Best-effort: return whatever we have
    }
    return enriched;
  }

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

      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'orderSheetCreated',
        details: {
          'clientCount': clientIds.length.toString(),
          'productCount': productIds.length.toString(),
        },
      );

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
      // Read old value before writing
      final rowSnap = await _rowsCol(date).doc(productId).get();
      _fbLogger.logRead('orders/{date}/rows', 1, rowSnap.data());
      final quantities =
          rowSnap.data()?['quantities'] as Map<String, dynamic>? ?? {};
      final oldValue = (quantities[clientId] as num?) ?? 0;

      // No-op: skip if value hasn't changed
      if (oldValue == value) return;

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

      final quantityDetails = await _enrichDetails({
        'productId': productId,
        'clientId': clientId,
        'oldValue': oldValue.toString(),
        'newValue': value.toString(),
      });

      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'quantityChanged',
        details: quantityDetails,
      );

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
      // Read old value before writing
      final rowSnap = await _rowsCol(date).doc(productId).get();
      _fbLogger.logRead('orders/{date}/rows', 1, rowSnap.data());
      final oldValue = (rowSnap.data()?['stock'] as num?) ?? 0;

      // No-op: skip if value hasn't changed
      if (oldValue == value) return;

      final batch = _firestore.batch();

      batch.update(_rowsCol(date).doc(productId), {'stock': value});
      batch.update(_orderDoc(date), {
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      final stockDetails = await _enrichDetails({
        'productId': productId,
        'oldValue': oldValue.toString(),
        'newValue': value.toString(),
      });

      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'stockChanged',
        details: stockDetails,
      );

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

      final removeClientDetails = await _enrichDetails({
        'clientIds': clientIds.join(','),
      });

      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'clientsRemoved',
        details: removeClientDetails,
      );

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

      final removeProductDetails = await _enrichDetails({
        'productIds': productIds.join(','),
      });

      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'productsRemoved',
        details: removeProductDetails,
      );

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

      // History entry (standalone, not in batch)
      final addClientDetails = await _enrichDetails({
        'clientIds': clientIds.join(','),
      });
      await addHistoryEntry(
        date: date,
        actionType: 'clientsAdded',
        userId: _userProvider.currentUser?.uid ?? '',
        details: addClientDetails,
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

      final addProductDetails = await _enrichDetails({
        'productIds': productIds.join(','),
      });

      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'productsAdded',
        details: addProductDetails,
      );

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

      final String historyAction;
      if (flagType == null) {
        historyAction = 'compensationUnmarked'; // generic unmark
      } else if (flagType == 'compensation') {
        historyAction = 'compensationMarked';
      } else {
        historyAction = 'reservationMarked';
      }
      final flagDetails = await _enrichDetails({
        'productId': productId,
        'clientId': clientId,
        if (flagType != null) 'flagType': flagType,
      });
      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: historyAction,
        details: flagDetails,
      );

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

      final strictDetails = await _enrichDetails({'productId': productId});
      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: strictStock ? 'strictStockMarked' : 'strictStockUnmarked',
        details: strictDetails,
      );

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

      final String refundAction;
      if (quantity == null || quantity <= 0) {
        refundAction = 'refundRemoved';
      } else {
        refundAction = 'refundAdded';
      }
      final refundDetails = await _enrichDetails({
        'productId': productId,
        'clientId': clientId,
        if (quantity != null && quantity > 0) 'quantity': quantity.toString(),
      });
      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: refundAction,
        details: refundDetails,
      );

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

      final resetDetails = await _enrichDetails({
        'clientIds': clientIds.join(','),
      });

      await _addHistoryToBatch(
        batch: batch,
        date: date,
        actionType: 'ordersReset',
        details: resetDetails,
      );

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

      // History entry (standalone)
      final invoiceDetails = await _enrichDetails({'clientId': clientId});
      await addHistoryEntry(
        date: date,
        actionType: 'provisionalInvoiceGenerated',
        userId: userId,
        details: invoiceDetails,
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
      _fbLogger.logRead(
        'orders',
        snap.docs.length,
        snap.docs.map((d) => d.data()).toList(),
      );
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
      final userName = _userProvider.currentUser?.userName ?? '';

      final docRef = _historyDoc(date);
      final snap = await docRef.get();
      final existing =
          (snap.data()?['entries'] as List<dynamic>?) ?? <dynamic>[];

      final newEntry = <String, dynamic>{
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'userId': userId,
        'userName': userName,
        'actionType': actionType,
        'details': details,
      };

      final updated = <dynamic>[newEntry, ...existing];
      if (updated.length > _maxHistoryEntries) {
        updated.removeRange(_maxHistoryEntries, updated.length);
      }

      await docRef.set({'entries': updated});
    } on FirebaseException {
      // Best-effort: do not throw
    }
  }

  @override
  Future<List<OrderActionEntryModel>> getHistory(String date) async {
    try {
      final snap = await _historyDoc(date).get();
      _fbLogger.logRead('orders/{date}/meta', 1, snap.data());
      final entries =
          (snap.data()?['entries'] as List<dynamic>?) ?? <dynamic>[];
      return entries.asMap().entries.map((e) {
        final data = Map<String, dynamic>.from(e.value as Map);
        return OrderActionEntryModel.fromMap(e.key.toString(), data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading history: $e');
    }
  }
}
