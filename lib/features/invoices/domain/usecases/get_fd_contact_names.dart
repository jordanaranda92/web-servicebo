import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/invoices_repository.dart';

/// Returns a map of FD contact UUID → display name from FacturaDirecta API.
class GetFdContactNames extends UseCase<Map<String, String>, NoParams> {
  final InvoicesRepository _repository;

  GetFdContactNames(this._repository);

  @override
  Future<Either<Failure, Map<String, String>>> call(NoParams params) {
    return _repository.getContactNames();
  }
}
