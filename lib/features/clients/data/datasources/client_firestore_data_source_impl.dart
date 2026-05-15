import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/log/firebase_operations_logger.dart';
import '../models/client_model.dart';
import 'client_firestore_data_source.dart';

class ClientFirestoreDataSourceImpl implements ClientFirestoreDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseOperationsLogger _fbLogger;

  ClientFirestoreDataSourceImpl(this._firestore, this._fbLogger);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('clients');

  @override
  Future<List<ClientModel>> getAll() async {
    try {
      final snapshot = await _collection.get();
      _fbLogger.logRead(
        'clients',
        snapshot.docs.length,
        snapshot.docs.map((d) => d.data()).toList(),
      );
      return snapshot.docs
          .map((doc) => ClientModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading clients: $e');
    }
  }

  @override
  Stream<List<ClientModel>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      _fbLogger.logStreamRead(
        'clients',
        snapshot.docs.length,
        snapshot.docs.map((d) => d.data()).toList(),
      );
      return snapshot.docs
          .map((doc) => ClientModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<void> updateFields({
    required String id,
    required Map<String, dynamic> fields,
  }) async {
    try {
      await _collection.doc(id).update(fields);
      _fbLogger.logWrite('clients', 1, fields);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating client: $e');
    }
  }

  @override
  Future<void> batchUpdate(Map<String, Map<String, dynamic>> updates) async {
    try {
      final batch = _firestore.batch();
      for (final entry in updates.entries) {
        batch.update(_collection.doc(entry.key), entry.value);
      }
      await batch.commit();
      _fbLogger.logBatchWrite('clients', updates.length);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error batch updating clients: $e');
    }
  }

  @override
  Future<ClientModel?> findByFdUuid(String facturaDirectaUuid) async {
    try {
      final snapshot = await _collection
          .where('facturaDirectaUuid', isEqualTo: facturaDirectaUuid)
          .limit(1)
          .get();
      _fbLogger.logRead(
        'clients',
        snapshot.docs.length,
        snapshot.docs.map((d) => d.data()).toList(),
      );
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return ClientModel.fromFirestore(doc.id, doc.data());
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error finding client by FD UUID: $e');
    }
  }

  @override
  Future<void> add(ClientModel client) async {
    try {
      await _collection
          .add(client.toMap())
          .timeout(const Duration(seconds: 10));
      _fbLogger.logWrite('clients', 1, client.toMap());
    } on TimeoutException {
      throw const ServerException(
        message: 'Timeout adding client. Check Firestore rules.',
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error adding client: $e');
    }
  }

  @override
  Future<void> batchAdd(List<ClientModel> clients) async {
    try {
      final batch = _firestore.batch();
      for (final client in clients) {
        batch.set(_collection.doc(), client.toMap());
      }
      await batch.commit();
      _fbLogger.logBatchWrite(
        'clients',
        clients.length,
        clients.map((c) => c.toMap()).toList(),
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error batch adding clients: $e');
    }
  }
}
