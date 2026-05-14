import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/invoice.dart';
import '../repositories/invoices_repository.dart';

class GetInvoices extends UseCase<List<Invoice>, NoParams> {
  final InvoicesRepository _repository;

  GetInvoices(this._repository);

  @override
  Future<Either<Failure, List<Invoice>>> call(NoParams params) {
    return _repository.getInvoices();
  }
}
