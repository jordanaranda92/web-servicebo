import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/log/firebase_operations_logger.dart';
import '../../../clients/domain/entities/client_category.dart';
import 'client_category_firestore_data_source.dart';

class ClientCategoryFirestoreDataSourceImpl
    implements ClientCategoryFirestoreDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseOperationsLogger _fbLogger;

  ClientCategoryFirestoreDataSourceImpl(this._firestore, this._fbLogger);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('client_categories');

  @override
  Future<List<ClientCategory>> getAll() async {
    try {
      final snapshot = await _collection.get();
      _fbLogger.logRead(
        'client_categories',
        snapshot.docs.length,
        snapshot.docs.map((d) => d.data()).toList(),
      );
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ClientCategory(
          id: doc.id,
          name: data['name'] as String? ?? '',
          color: data['color'] as String?,
        );
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading client categories: $e');
    }
  }

  @override
  Stream<List<ClientCategory>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      _fbLogger.logStreamRead(
        'client_categories',
        snapshot.docs.length,
        snapshot.docs.map((d) => d.data()).toList(),
      );
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ClientCategory(
          id: doc.id,
          name: data['name'] as String? ?? '',
          color: data['color'] as String?,
        );
      }).toList();
    });
  }

  @override
  Future<void> add({required String name, String? color}) async {
    try {
      final data = {'name': name, if (color != null) 'color': color};
      await _collection.add(data).timeout(const Duration(seconds: 10));
      _fbLogger.logWrite('client_categories', 1, data);
    } on TimeoutException {
      throw ServerException(
        message: 'Timeout adding client category. Check Firestore rules.',
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error adding client category: $e');
    }
  }

  @override
  Future<void> update({
    required String id,
    required String name,
    String? color,
  }) async {
    try {
      final data = {'name': name, 'color': color};
      await _collection.doc(id).update(data);
      _fbLogger.logWrite('client_categories', 1, data);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating client category: $e');
    }
  }

  @override
  Future<void> delete({required String id}) async {
    try {
      await _collection.doc(id).delete();
      _fbLogger.logDelete('client_categories', 1);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error deleting client category: $e');
    }
  }
}
