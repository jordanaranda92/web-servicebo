import '../../../clients/domain/entities/client_category.dart';

abstract class ClientCategoryFirestoreDataSource {
  Future<List<ClientCategory>> getAll();
  Stream<List<ClientCategory>> watchAll();
  Future<void> add({required String name, String? color});
  Future<void> update({
    required String id,
    required String name,
    String? color,
  });
  Future<void> delete({required String id});
}
