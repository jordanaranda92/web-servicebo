import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/client.dart';
import '../repositories/clients_repository.dart';

class GetClients extends UseCase<List<Client>, NoParams> {
  final ClientsRepository _repository;

  GetClients(this._repository);

  @override
  Future<Either<Failure, List<Client>>> call(NoParams params) {
    return _repository.getClients();
  }
}
