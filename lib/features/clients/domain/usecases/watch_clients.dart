import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/client.dart';
import '../repositories/clients_repository.dart';

class WatchClients {
  final ClientsRepository _repository;

  WatchClients(this._repository);

  Stream<Either<Failure, List<Client>>> call() {
    return _repository.watchClients();
  }
}
