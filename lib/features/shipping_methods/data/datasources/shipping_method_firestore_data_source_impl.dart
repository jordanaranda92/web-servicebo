import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/shipping_method.dart';
import 'shipping_method_firestore_data_source.dart';

class ShippingMethodFirestoreDataSourceImpl
    implements ShippingMethodFirestoreDataSource {
  final FirebaseFirestore _firestore;

  ShippingMethodFirestoreDataSourceImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shipping_methods');

  CollectionReference<Map<String, dynamic>> get _clientsCollection =>
      _firestore.collection('clients');

  @override
  Future<List<ShippingMethod>> getAll() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ShippingMethod(
          id: doc.id,
          name: data['name'] as String? ?? '',
          phone: data['phone'] as String? ?? '',
        );
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading shipping methods: $e');
    }
  }

  @override
  Stream<List<ShippingMethod>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data();
        return ShippingMethod(
          id: doc.id,
          name: data['name'] as String? ?? '',
          phone: data['phone'] as String? ?? '',
        );
      }).toList(),
    );
  }

  @override
  Future<void> add({required String name, required String phone}) async {
    try {
      await _collection
          .add({'name': name, 'phone': phone})
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw ServerException(
        message: 'Timeout adding shipping method. Check Firestore rules.',
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error adding shipping method: $e');
    }
  }

  @override
  Future<void> update({required String id, required String name}) async {
    try {
      await _collection.doc(id).update({'name': name});
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error updating shipping method: $e');
    }
  }

  @override
  Future<void> updatePhone({required String id, required String phone}) async {
    try {
      await _collection.doc(id).update({'phone': phone});
    } on FirebaseException catch (e) {
      throw ServerException(
        message: 'Error updating shipping method phone: $e',
      );
    }
  }

  @override
  Future<void> delete({required String id}) async {
    try {
      await _collection.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error deleting shipping method: $e');
    }
  }

  @override
  Future<void> cleanupClientReferences({
    required String shippingMethodId,
  }) async {
    try {
      final snapshot = await _clientsCollection.get();
      final batch = _firestore.batch();
      var updatesCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final byDay = data['shippingMethodsByDay'] as Map<String, dynamic>?;
        if (byDay == null) continue;

        final cleanedMap = Map<String, dynamic>.from(byDay);
        var changed = false;
        for (final entry in byDay.entries) {
          if (entry.value == shippingMethodId) {
            cleanedMap.remove(entry.key);
            changed = true;
          }
        }

        if (changed) {
          batch.update(_clientsCollection.doc(doc.id), {
            'shippingMethodsByDay': cleanedMap,
          });
          updatesCount++;
        }
      }

      if (updatesCount > 0) {
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        message: 'Error cleaning up shipping method references: $e',
      );
    }
  }
}
