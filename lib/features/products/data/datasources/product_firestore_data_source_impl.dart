import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/exceptions.dart';
import '../models/product_model.dart';
import 'product_firestore_data_source.dart';

class ProductFirestoreDataSourceImpl implements ProductFirestoreDataSource {
  final FirebaseFirestore _firestore;

  ProductFirestoreDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('products');

  @override
  Future<List<ProductModel>> getAll() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading products: $e');
    }
  }

  @override
  Stream<List<ProductModel>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  @override
  Future<void> updateFields({
    required String id,
    required Map<String, dynamic> fields,
  }) async {
    try {
      await _collection.doc(id).update(fields);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating product: $e');
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
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error batch updating products: $e');
    }
  }

  @override
  Future<void> add(Map<String, dynamic> data) async {
    try {
      await _collection.add(data);
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error adding product: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error deleting product: $e');
    }
  }
}
