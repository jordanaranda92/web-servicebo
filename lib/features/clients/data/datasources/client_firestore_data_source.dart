import '../models/client_model.dart';

abstract class ClientFirestoreDataSource {
  Future<List<ClientModel>> getAll();
  Stream<List<ClientModel>> watchAll();
  Future<void> updateFields({
    required String id,
    required Map<String, dynamic> fields,
  });
  Future<void> batchUpdate(Map<String, Map<String, dynamic>> updates);
  Future<ClientModel?> findByFdUuid(String facturaDirectaUuid);
  Future<void> add(ClientModel client);
  Future<void> batchAdd(List<ClientModel> clients);
}
