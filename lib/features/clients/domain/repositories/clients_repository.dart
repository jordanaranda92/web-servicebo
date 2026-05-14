import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/client.dart';
import '../entities/fd_new_contact.dart';

abstract class ClientsRepository {
  Future<Either<Failure, List<Client>>> getClients();

  Stream<Either<Failure, List<Client>>> watchClients();

  Future<Either<Failure, Unit>> saveClientsBatch({
    Map<String, String> nameChanges,
    Map<String, String?> categoryChanges,
    Map<String, Map<String, String?>> shippingMethodsByDayChanges,
  });

  /// Returns the set of FacturaDirecta UUIDs already registered as clients.
  Future<Either<Failure, Set<String>>> getExistingFdUuids();

  /// Batch-adds new clients from FacturaDirecta contacts.
  /// Returns the number of clients added.
  Future<Either<Failure, int>> batchAddFromFdContacts(
    List<FdNewContact> contacts,
  );
}
