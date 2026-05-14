import '../../../shipping_methods/domain/entities/shipping_method.dart';

abstract class ShippingMethodFirestoreDataSource {
  Future<List<ShippingMethod>> getAll();
  Stream<List<ShippingMethod>> watchAll();
  Future<void> add({required String name, required String phone});
  Future<void> update({required String id, required String name});
  Future<void> updatePhone({required String id, required String phone});
  Future<void> delete({required String id});

  /// Removes all references to [shippingMethodId] from the
  /// `shippingMethodsByDay` map in every client document.
  Future<void> cleanupClientReferences({required String shippingMethodId});
}
