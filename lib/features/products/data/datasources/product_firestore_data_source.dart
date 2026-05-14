import '../models/product_model.dart';

abstract class ProductFirestoreDataSource {
  Future<List<ProductModel>> getAll();
  Stream<List<ProductModel>> watchAll();
  Future<void> updateFields({
    required String id,
    required Map<String, dynamic> fields,
  });
  Future<void> batchUpdate(Map<String, Map<String, dynamic>> updates);
  Future<void> add(Map<String, dynamic> data);
  Future<void> delete(String id);
}
